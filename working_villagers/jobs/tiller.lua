
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

-- limited support to two replant definitions
local tillable_nodes = {
	names = {
		["default:dirt"]=1,
		["default:dirt_with_grass"]=1,
		["default:dirt_with_rainforest_litter"]=1,
		["default:dry_dirt"]=1,
		["default:dirt_with_snow"]=1,
		["default:dirt_with_dry_grass"]=1,
		["default:dry_dirt_with_dry_grass"]=1,
		["default:dirt_with_coniferous_litter"]=1,
	},
}

local tilling_demands = {
	["farming:hoe_steel"] = 99,
	["farming:hoe_stone"] = 99,
	["farming:hoe_wood"] = 99,
}

function tillable_nodes.get_tillable(item_name)
	return func.get_item_from_list(tillable_nodes, item_name)
end

function tillable_nodes.is_tillable(item_name)
	return func.is_item_from_list(tillable_nodes, item_name)
end

local function find_tillable_node(self)
	return function(pos)
		if minetest.is_protected(pos, self:get_player_name()) then return false end
		if working_villages.failed_pos_test(pos) then return false end

		local node = minetest.get_node(pos);
		local data = tillable_nodes.get_tillable(node.name);
		if (not data) then
			return false;
		end

		for dy = 1, 2 do
			local above = vector.add(pos, {x=0, y=dy, z=0})
			local node_above = minetest.get_node(above)
			if (node_above.name ~= "air") then
				return false;
			end
		end

		local water_rad = 3;
		local water_names = {
			"default:water_source",
			"default:river_water_source",
		};
		local water_pos = minetest.find_node_near(pos, water_rad, water_names);
		return (water_pos ~= nil);
	end
end

local searching_range = {x = 10, y = 3, z = 10}

local function put_func(_,stack)
	if tilling_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if tilling_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(tilling_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function tilling_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	local wield_stack = self:get_wield_item_stack()
	if (wield_stack == nil)
	or (wield_stack:is_empty())
	or (tilling_demands[wield_stack:get_name()] == nil) then
		self:move_main_to_wield(function(name)
			return (tilling_demands[name] ~= nil)
		end)
		wield_stack = self:get_wield_item_stack()
	end
	self:handle_job_pos()

	self:count_timer("tiller:search")
	self:count_timer("tiller:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("tiller:search",20) then
		--self:collect_nearest_item_by_condition(tillable_nodes.is_tillable, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_tillable_node(self), searching_range)
		if target == nil then
			log.error("Villager %s does not find target", self.inventory_name)
			return false
		end

		local destination = func.find_adjacent_clear(target)
		if destination then
			destination = func.find_ground_below(destination)
		end
		if destination==false then
			log.error("Villager %s no adjacent walkable found", self.inventory_name)
			destination = target
		end
		local success, result = self:go_to(destination)
		if not success then
			working_villages.failed_pos_record(target)
			self:set_displayed_action("looking at the unreachable dirt")
			self:delay(100)
			return false
		end
		succsss = self:use_wield_item(target)
		if not success then
			log.error('wield failed')
			self:set_displayed_action("wield failure")
			return false
		end
		return true
	end
	if self:timer_exceeded("tiller:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_tiller", {
	description			= "tiller (working_villages)",
	long_description = "I look for dirt nodes near water and till them to soil.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = tilling_job,
})

working_villages.tillable_nodes = tillable_nodes
working_villages.tilling_job = tilling_job
