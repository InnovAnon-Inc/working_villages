
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

local planting_nodes = {
	names = {
		["farming:soil_wet"]=1,
		["farming:soil"]=1,
	},
}

local planting_demands = {
	["farming:beanpole"] = 99,
	["farming:trellis"] = 99,

	["farming:artichoke"]=99,
	["farming:seed_barley"]=99,
	["farming:beans"]=99,
	["farming:beetroot"]=99,
	["farming:blackberry"]=99,
	["farming:blueberries"]=99,
	["farming:cabbage"]=99,
	["farming:carrot"]=99,
	["farming:chili_pepper"]=99,
	["farming:cocoa_beans"]=99,
	["farming:coffe_beans"]=99,
	["farming:corn"]=99,
	["farming:seed_cotton"]=99,
	["farming:cucumber"]=99,
	["farming:garlic_clove"]=99,
	["farming:grapes"]=99,
	["farming:seed_hemp"]=99,
	["farming:lettuce"]=99,
	["farming:melon_slice"]=99,
	["farming:seed_mint"]=99,
	["farming:seed_oat"]=99,
	["farming:onion"]=99,
	["farming:parsley"]=99,
	["farming:pea_pod"]=99,
	["farming:peppercorn"]=99,
	["farming:pineaple_top"]=99, -- TODO spelling?
	["farming:potato"]=99,
	["farming:pumpkin_slice"]=99,
	["farming:raspberries"]=99,
	["farming:rhubarb"]=99,
	["farming:seed_rice"]=99,
	["farming:seed_rye"]=99,
	["farming:soy_pod"]=99,
	["farming:seed_sunflower"]=99,
	["farming:tomato"]=99,
	["farming:vanilla"]=99,
	["farming:seed_wheat"]=99,
}

function planting_nodes.get_soil(item_name)
	return func.get_item_from_list(planting_nodes, item_name)
end

function planting_nodes.is_soil(item_name)
	return func.is_item_from_list(planting_nodes, item_name)
end

local function find_soil_node(pos)
	local node = minetest.get_node(pos);
	local data = planting_nodes.get_soil(node.name);
	if (not data) then
		return false;
	end

	if (not func.has_headroom(pos)) then
		return false;
	end

	return true;
end

local searching_range = {x = 10, y = 3, z = 10}

local function put_func(_,stack)
	if planting_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if planting_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(planting_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function planting_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	self:handle_job_pos()

	self:count_timer("planter:search")
	self:count_timer("planter:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("planter:search",20) then
		--self:collect_nearest_item_by_condition(planting_nodes.is_soil, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_soil_node, searching_range)
		if target == nil then
			return false
		end

		local destination = func.find_adjacent_clear(target)
		if destination then
			destination = func.find_ground_below(destination)
		end
		if destination==false then
			--print("failure: no adjacent walkable found")
			log.error("Villager %s no adjacent walkable found", self.inventory_name)
			destination = target
		end

		local success, result = self:go_to(destination)
		if not success then
			working_villages.failed_pos_record(target)
			self:set_displayed_action("looking at the unreachable soil")
			self:delay(100)
			return false
		end

		for plant_name, plant_data in pairs(working_villages.farming_plants.names) do
			-- TODO check whether item in inventory or whether placement is successful
			for index, value in ipairs(plant_data.replant) do
				self:place(value, vector.add(target, vector.new(0,index-0,0)))
			end
		end
		
		return true
	end
	if self:timer_exceeded("planter:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_planter", {
	description			= "planter (working_villages)",
	long_description = "I look for soil nodes and plant farming plants atop them.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = planting_job,
})

working_villages.planting_job = planting_job
