
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

-- limited support to two replant definitions
local farming_plants = {
	names = {
		["farming:artichoke_5"]={replant={"farming:artichoke"}},
		["farming:barley_7"]={replant={"farming:seed_barley"}},
		["farming:beanpole_5"]={replant={"farming:beanpole","farming:beans"}},
		["farming:beetroot_5"]={replant={"farming:beetroot"}},
		["farming:blackberry_4"]={replant={"farming:blackberry"}},
		["farming:blueberry_4"]={replant={"farming:blueberries"}},
		["farming:cabbage_6"]={replant={"farming:cabbage"}},
		["farming:carrot_8"]={replant={"farming:carrot"}},
		["farming:chili_8"]={replant={"farming:chili_pepper"}},
		["farming:cocoa_4"]={replant={"farming:cocoa_beans"}},
		["farming:coffe_5"]={replant={"farming:coffe_beans"}},
		["farming:corn_8"]={replant={"farming:corn"}},
		["farming:cotton_8"]={replant={"farming:seed_cotton"}},
		["farming:cucumber_4"]={replant={"farming:cucumber"}},
		["farming:garlic_5"]={replant={"farming:garlic_clove"}},
		["farming:grapes_8"]={replant={"farming:trellis","farming:grapes"}},
		["farming:hemp_8"]={replant={"farming:seed_hemp"}},
		["farming:lettuce_5"]={replant={"farming:lettuce"}},
		["farming:melon_8"]={replant={"farming:melon_slice"}},
		["farming:mint_4"]={replant={"farming:seed_mint"}},
		["farming:oat_8"]={replant={"farming:seed_oat"}},
		["farming:onion_5"]={replant={"farming:onion"}},
		["farming:parsley_3"]={replant={"farming:parsley"}},
		["farming:pea_5"]={replant={"farming:pea_pod"}},
		["farming:pepper_7"]={replant={"farming:peppercorn"}},
		["farming:pineaple_8"]={replant={"farming:pineapple_top"}}, -- TODO spelling?
		["farming:potato_4"]={replant={"farming:potato"}},
		["farming:pumpkin_8"]={replant={"farming:pumpkin_slice"}},
		["farming:raspberry_4"]={replant={"farming:raspberries"}},
		["farming:rhubarb_3"]={replant={"farming:rhubarb"}},
		["farming:rice_8"]={replant={"farming:seed_rice"}},
		["farming:rye_8"]={replant={"farming:seed_rye"}},
		["farming:soy_7"]={replant={"farming:soy_pod"}},
		["farming:sunflower_8"]={replant={"farming:seed_sunflower"}},
		["farming:tomato_8"]={replant={"farming:tomato"}},
		["farming:vanilla_8"]={replant={"farming:vanilla"}},
		["farming:wheat_8"]={replant={"farming:seed_wheat"}},
	},
}

local farming_demands = {
	["farming:beanpole"] = 99,
	["farming:trellis"] = 99,
}

function farming_plants.get_plant(item_name)
	return func.get_item_from_list(farming_plants, item_name)
end

function farming_plants.is_plant(item_name)
	return func.is_item_from_list(farming_plants, item_name)
end

local function find_plant_node(pos)
	local node = minetest.get_node(pos);
	local data = farming_plants.get_plant(node.name);
	if (not data) then
		return false;
	end
	return true;
end

local searching_range = {x = 10, y = 3, z = 10}

local function put_func(_,stack)
	if farming_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if farming_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(farming_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function farming_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	self:handle_job_pos()

	self:count_timer("farmer:search")
	self:count_timer("farmer:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("farmer:search",20) then
		self:collect_nearest_item_by_condition(farming_plants.is_plant, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_plant_node, searching_range)
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

		self:go_to(destination)

		local plant_data = farming_plants.get_plant(minetest.get_node(target).name);
		self:dig(target,true)
		if plant_data and plant_data.replant then
			for index, value in ipairs(plant_data.replant) do
				self:place(value, vector.add(target, vector.new(0,index-1,0)))
			end
		end

		return true
	end
	if self:timer_exceeded("farmer:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_farmer", {
	description			= "farmer (working_villages)",
	long_description = "I look for farming plants to collect and replant them.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = farming_job,
})

working_villages.farming_plants = farming_plants
working_villages.farming_job = farming_job
