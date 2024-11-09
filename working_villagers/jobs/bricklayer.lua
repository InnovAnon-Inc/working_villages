
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

-- limited support to two replant definitions
local irrigation_nodes = {
	names = {
		["default:water_source"]=1,
		["default:river_water_source"]=1,
	},
}

local bricklaying_demands = {
	["default:stonebrick"] = 99,
}

function irrigation_nodes.get_foundation(item_name)
	return func.get_item_from_list(irrigation_nodes, item_name)
end

function irrigation_nodes.is_foundation(item_name)
	return func.is_item_from_list(irrigation_nodes, item_name)
end

local function find_irrigated_node(self)
	return function(pos)
		if minetest.is_protected(pos, self:get_player_name()) then return false end
		if working_villages.failed_pos_test(pos) then return false end

		local node = minetest.get_node(pos);
		local data = irrigation_nodes.get_foundation(node.name);
		if (not data) then
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
	if bricklaying_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if bricklaying_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(bricklaying_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function bricklaying_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	local wield_stack = self:get_wield_item_stack()
	if (wield_stack == nil)
	or (wield_stack:is_empty())
	or (bricklaying_demands[wield_stack:get_name()] == nil) then
		self:move_main_to_wield(function(name)
			return (bricklaying_demands[name] ~= nil)
		end)
		wield_stack = self:get_wield_item_stack()
	end
	self:handle_job_pos()

	self:count_timer("bricklayer:search")
	self:count_timer("bricklayer:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("bricklayer:search",20) then
		--self:collect_nearest_item_by_condition(irrigation_nodes.is_foundation, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_irrigated_node(self), searching_range)
		if target == nil then
			--log.error("Villager %s does not find target", self.inventory_name)
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
		local above = vector.add(target, {x=0, y=2, z=0})
		self:place("default:stonebrick", above)
		return true
	end
	if self:timer_exceeded("bricklayer:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_bricklayer", {
	description			= "bricklayer (working_villages)",
	long_description = "I look for water sources and place stonebrick atop them.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = bricklaying_job,
})

working_villages.irrigation_nodes = irrigation_nodes
working_villages.bricklaying_job = bricklaying_job
