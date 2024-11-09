
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

-- limited support to two replant definitions
local foundation_nodes = {
	names = {
		["default:stonebrick"]=1,
	},
}

local dirtlaying_demands = {
	["default:dirt"] = 99,
}

function foundation_nodes.get_foundation(item_name)
	return func.get_item_from_list(foundation_nodes, item_name)
end

function foundation_nodes.is_foundation(item_name)
	return func.is_item_from_list(foundation_nodes, item_name)
end

local function find_irrigated_node(self)
	return function(pos)
		if minetest.is_protected(pos, self:get_player_name()) then return false end
		if working_villages.failed_pos_test(pos) then return false end

		local node = minetest.get_node(pos);
		local data = foundation_nodes.get_foundation(node.name);
		if (not data) then
			return false;
		end

		local below = vector.add(pos, {x=0, y=-1, z=0})
		local node_below = minetest.get_node(below)
		if  (node_below.name ~= "default:water_source")
		and (node_below.name ~= "default:river_water_source") then
			return false;
		end

		if (not func.has_headroom(pos)) then
			return false;
		end

		return true;
	end
end

local searching_range = {x = 10, y = 3, z = 10}

local function put_func(_,stack)
	if dirtlaying_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if dirtlaying_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(dirtlaying_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function dirtlaying_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	local wield_stack = self:get_wield_item_stack()
	if (wield_stack == nil)
	or (wield_stack:is_empty())
	or (dirtlaying_demands[wield_stack:get_name()] == nil) then
		self:move_main_to_wield(function(name)
			return (dirtlaying_demands[name] ~= nil)
		end)
		wield_stack = self:get_wield_item_stack()
	end
	self:handle_job_pos()

	self:count_timer("dirtlayer:search")
	self:count_timer("dirtlayer:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("dirtlayer:search",20) then
		--self:collect_nearest_item_by_condition(foundation_nodes.is_foundation, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_irrigated_node(self), searching_range)
		if target == nil then
			log.error("Villager %s does not find target", self.inventory_name)
			return false
		end

		local destination = func.find_adjacent_clear(target)
		--if destination then
		--	destination = func.find_ground_below(destination)
		--end
		if destination==false then
			log.error("Villager %s no adjacent walkable found", self.inventory_name)
			destination = target
		end
		local success, result = self:go_to(destination)
		if not success then
			working_villages.failed_pos_record(target)
			self:set_displayed_action("looking at the unreachable foundation")
			self:delay(100)
			return false
		end
		local above = vector.add(target, {x=0, y=1, z=0})
		self:place("default:dirt", above)
		return true
	end
	if self:timer_exceeded("dirtlayer:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_dirtlayer", {
	description			= "dirtlayer (working_villages)",
	long_description = "I look for stone nodes near water and place dirt atop them.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = dirtlaying_job,
})

working_villages.foundation_nodes = foundation_nodes
working_villages.dirtlaying_job = dirtlaying_job
