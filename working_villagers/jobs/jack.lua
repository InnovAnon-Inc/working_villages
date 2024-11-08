
local func = working_villages.require("jobs/util")
local log = working_villages.require("log")

local foundationer = working_villages.foundationing_job
local landscaper = working_villages.landscaping_job
local tiller = working_villages.tilling_job
local planter = working_villages.planting_job
local farmer = working_villages.farming_job

local function alternate(self, guard_mode)
	if   (guard_mode == "foundationer") then
		guard_mode = "landscaper"

	elseif   (guard_mode == "landscaper") then
		guard_mode = "tiller"

	elseif (guard_mode == "tiller") then
		guard_mode = "planter"

	elseif (guard_mode == "planter") then
		guard_mode = "farmer"

	elseif (guard_mode == "farmer") then
		guard_mode = "foundationer"

	else error("invalid mode "..guard_mode) end

	self:set_job_data("mode", guard_mode)
	self:set_displayed_action(guard_mode)
	log.action(guard_mode)
end

working_villages.register_job("working_villages:job_jack", {
	description			= "jack (working_villages)",
	long_description = "I'm a jack of all trades.",
	inventory_image	= "default_paper.png^working_villages_farmer.png",
	jobfunc = function(self)
		local guard_mode = self:get_job_data("mode") or "foundationer"
		self:set_displayed_action(guard_mode)

		self:count_timer("jack:switch")
		if self:timer_exceeded("jack:switch", 200) then
			guard_mode = alternate(self, guard_mode)
			return true
		end

		if     (guard_mode == "foundationer") then
			result = foundationer(self)

		elseif (guard_mode == "landscaper") then
			result = landscaper(self)

		elseif (guard_mode == "tiller") then
			result = tiller(self)

		elseif (guard_mode == "planter") then
			result = planter(self)

		elseif (guard_mode == "farmer") then
			result = farmer(self)
		else error("invalid mode "..guard_mode) end

		if (not result) then
			guard_mode = alternate(self, guard_mode)
			return true
		end
		return true
	end,
})
