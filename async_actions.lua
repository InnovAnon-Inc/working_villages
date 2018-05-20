function working_villages.villager:go_to(pos)
	self.destination=vector.round(pos)
	if working_villages.func.walkable_pos(self.destination) then
		self.destination=working_villages.pathfinder.get_ground_level(vector.round(self.destination))
	end
	local val_pos = working_villages.func.validate_pos(self.object:getpos())
	self.path = working_villages.pathfinder.get_reachable(val_pos,self.destination,self)
	self:set_timer("goto_dest:find_path",0) -- find path interval
	self:set_timer("goto_dest:change_dir",0)
	self:set_timer("goto_dest:give_up",0)
	if self.path == nil then
		self.path = {self.destination}
	end
	--print("the first waypiont on his path:" .. minetest.pos_to_string(self.path[1]))
	self:change_direction(self.path[1])
	self:set_animation(working_villages.animation_frames.WALK)
	
	while #self.path ~= 0 do
		self:count_timer("goto_dest:find_path")
		self:count_timer("goto_dest:change_dir")
		if self:timer_exceeded("goto_dest:find_path",100) then
			val_pos = working_villages.func.validate_pos(self.object:getpos())
			local path = working_villages.pathfinder.get_reachable(val_pos,self.destination,self)
			if path == nil then
				self:count_timer("goto_dest:give_up")
				if self:timer_exceeded("goto_dest:give_up",3) then
					self.destination=vector.round(self.destination)
					if working_villages.func.walkable_pos(self.destination) then
						self.destination=working_villages.pathfinder.get_ground_level(vector.round(self.destination))
					end
					print("villager can't find path")
					--FIXME: we ought to give up at this point
				end
			else
				self.path = path
			end
		end

		if self:timer_exceeded("goto_dest:change_dir",30) then
			self:change_direction(self.path[1])
		end

		-- follow path
		if self:is_near({x=self.path[1].x,y=self.object:getpos().y,z=self.path[1].z}, 1) then
			table.remove(self.path, 1)

			if #self.path == 0 then -- end of path
				break
			else -- else next step, follow next path.
				self:set_timer("goto_dest:find_path",0)
				self:change_direction(self.path[1])
			end
		end
		-- if vilager is stopped by obstacles, the villager must jump.
		self:handle_obstacles()
		-- end step
		coroutine.yield()
	end
	self.object:setvelocity{x = 0, y = 0, z = 0}
	self.path = nil
	self:set_animation(working_villages.animation_frames.STAND)
end

function working_villages.villager:dig(pos)
	self.target = pos
	self:set_state("dig_target")
	coroutine.yield()
end

function working_villages.villager:place(itemname,pos)
	local wield_stack = self:get_wield_item_stack()
	if (wield_stack:get_name() == itemname or self:move_main_to_wield(function (name) return name == itemname end)) then
		self.target = pos
		self:set_state("place_wield")
		coroutine.yield()
	else
		minetest.chat_send_player(self.owner_name,"villager couldn't place ".. itemname)
	end
end

function working_villages.villager:wait_until_dawn()
	while (minetest.get_timeofday() < 0.2 or minetest.get_timeofday() > 0.76) do
		coroutine.yield()
	end
end

function working_villages.villager:sleep()
	minetest.log("action","a villager is laying down")
	self.object:setvelocity{x = 0, y = 0, z = 0}
	local bed_pos=self:get_home():get_bed()
	local bed_top = working_villages.func.find_adjacent_pos(bed_pos,
		function(p) return string.find(minetest.get_node(p).name,"_top") end)
	local bed_bottom = working_villages.func.find_adjacent_pos(bed_pos,
		function(p) return string.find(minetest.get_node(p).name,"_bottom") end)
	if bed_top and bed_bottom then
		self:set_yaw_by_direction(vector.subtract(bed_bottom, bed_top))
	else
		minetest.log("info","no bed found")
	end
	self:set_animation(working_villages.animation_frames.LAY)
	self.object:setpos(vector.add(bed_pos,{x=0,y=1.5,z=0}))
	self.pause="sleeping"
	self:update_infotext()

	self:wait_until_dawn()

	local pos=self.object:getpos()
	self.object:setpos({x=pos.x,y=pos.y+0.5,z=pos.z})
	minetest.log("action","a villager gets up")
	self:set_animation(working_villages.animation_frames.STAND)
	self.pause="active"
	self:update_infotext()
end

function working_villages.villager:goto_bed()
	if working_villages.debug_logging then
		minetest.log("action","a villager is going home")
	end
	if not self:has_home() then
		self:set_animation(working_villages.animation_frames.SIT)
		self:wait_until_dawn()
	else
		local bed_pos = self:get_home():get_bed()
		if not bed_pos then
			minetest.log("warning","villager couldn't find his bed")
			--perhaps go home
			self:set_animation(working_villages.animation_frames.SIT)
			self:wait_until_dawn()
		else
			if working_villages.debug_logging then
				minetest.log("info","his bed is at:" .. self.destination.x .. ",".. self.destination.y .. ",".. self.destination.z)
			end
			self:go_to(bed_pos)
			self:sleep()
		end
	end
end