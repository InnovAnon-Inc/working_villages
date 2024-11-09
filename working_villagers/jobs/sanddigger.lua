
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

-- limited support to two replant definitions
local sand_nodes = {
	names = {
		["default:sand"] = 99,
		["default:desert_sand"] = 99,
		["default:silver_sand"] = 99,
	},
}

local dirtdigging_demands = {
	["default:shovel_mese"]=99,
	["default:shovel_diamond"]=99,
	["default:shovel_steel"]=99,
	["default:shovel_bronze"]=99,
	["default:shovel_stone"]=99,
	["default:shovel_wood"]=99,
}

function sand_nodes.get_sand(item_name)
	return func.get_item_from_list(sand_nodes, item_name)
end

function sand_nodes.is_sand(item_name)
	return func.is_item_from_list(sand_nodes, item_name)
end

local function find_sand_node(self)
	return function(pos)
		if minetest.is_protected(pos, self:get_player_name()) then return false end
		if working_villages.failed_pos_test(pos) then return false end

		local node = minetest.get_node(pos);
		local data = sand_nodes.get_sand(node.name);
		if (not data) then
			return false;
		end

		if (not func.has_headroom(pos)) then
			return false;
		end

		--local water_rad = 3;
		--local water_names = {
		--	"default:water_source",
		--	"default:river_water_source",
		--};
		--local water_pos = minetest.find_node_near(pos, water_rad, water_names);
		--return (water_pos == nil);
		return true;
	end
end

local searching_range = {x = 10, y = 3, z = 10}

local function put_func(_,stack)
	if dirtdigging_demands[stack:get_name()] then
		return false
	end
	return true;
end
local function take_func(villager,stack)
	local item_name = stack:get_name()
	if dirtdigging_demands[item_name] then
		local inv = villager:get_inventory()
		local itemstack = ItemStack(item_name)
		itemstack:set_count(dirtdigging_demands[item_name])
		if (not inv:contains_item("main", itemstack)) then
			return true
		end
	end
	return false
end

local function sanddigging_job(self)
	self:handle_night()
	self:handle_chest(take_func, put_func)
	local wield_stack = self:get_wield_item_stack()
	if (wield_stack == nil)
	or (wield_stack:is_empty())
	or (dirtdigging_demands[wield_stack:get_name()] == nil) then
		self:move_main_to_wield(function(name)
			return (dirtdigging_demands[name] ~= nil)
		end)
		wield_stack = self:get_wield_item_stack()
	end
	self:handle_job_pos()

	self:count_timer("sanddigger:search")
	self:count_timer("sanddigger:change_dir")
	self:handle_obstacles()
	if self:timer_exceeded("sanddigger:search",20) then
		--self:collect_nearest_item_by_condition(sand_nodes.is_sand, searching_range)
		local target = func.search_surrounding(self.object:get_pos(), find_sand_node(self), searching_range, true)
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
			self:set_displayed_action("looking at the unreachable sand")
			self:delay(100)
			return false
		end
		
		local success, ret = self:dig(target,true)
		if not success then
			working_villages.failed_pos_record(target)
			self:set_displayed_action("confused as to why digging failed")
			self:delay(100)
			return false;
		end

		-- TODO proper tool use
		--success = self:use_wield_item(target)
		--if not success then
		--	log.error('wield failed')
		--	self:set_displayed_action("wield failure")
		--	return false
		--end

		return true
	end
	if self:timer_exceeded("sanddigger:change_dir",50) then
		self:change_direction_randomly()
		return true
	end
	return true
end

working_villages.register_job("working_villages:job_sanddigger", {
	description			= "sanddigger (working_villages)",
	long_description = "I collect sand.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = sanddigging_job,
})

working_villages.sand_nodes = sand_nodes
working_villages.sanddigging_job = sanddigging_job
