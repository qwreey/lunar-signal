local wrap = coroutine.wrap
local running = coroutine.running
local resume = coroutine.resume
local yield = coroutine.yield
local insert = table.insert
local remove = table.remove

local function _spawn(func,...)
	return wrap(func)(...)
end

local metaFake do
	local index = function(self,key)
		error(("attempt to index a %s value with %s"):format(tostring(self),tostring(key)))
	end
	local arithmetic = function(self)
		error(("attempt to perform arithmetic on a %s value"):format(tostring(self)))
	end
	local epairs = function(self)
		error(("bad argument #1 to '?' (table expected, got %s)"):format(tostring(self)))
	end
	local comp = function(self,value)
		error(("attempt to compare %s with %s"):format(tostring(self),type(value)))
	end
	metaFake = {
		__index = index,__newindex = index,
		__metatable = function()
			return nil
		end,
		__len = function(self)
			error(("attempt to get length of a %s value"):format(tostring(self)))
		end,
		__call = function(self)
			error(("attempt to call a %s value"):format(tostring(self)))
		end,
		__concat = function(self)
			error(("attempt to concatenate a %s value"):format(tostring(self)))
		end,
		__pairs=epairs,__ipairs=epairs,
		__unm=arithmetic,__add=arithmetic,__sub=arithmetic,__mul=arithmetic,__div=arithmetic,__mod=arithmetic,__pow=arithmetic,
		__lt=comp,__le=comp,
		new = function(name,obj)
			local meta = {}
			for i,v in pairs(metaFake) do meta[i]=v end
			meta.__tostring = name
			meta.__name = name
			setmetatable(obj,meta)
			return obj
		end
	}
end
local timeouted = metaFake.new("Signal.Timeout",{__type = "timeout"})
local released = metaFake.new("Signal.Released",{__type = "released"})

local function Init()
	local new = {}
	local timerOK,timer = pcall(require,"timer")
	new.warn = warn
	new.spawn = (task and task.spawn) or _spawn
	new.delay = (task and task.delay) or (timerOK and function (t,...) return timer.setTimeout(t*1000,...) end)
	new.cancel = (task and task.cancel) or (timerOK and timer.clearTimeout)
	new.Timeouted = timeouted
	new.Released = released

	-- roblox connections disconnecter
	local disconnecters = {}
	new.DisconnecterList = disconnecters
	local disconnecterClass = {__type = "disconnecter"}
	disconnecterClass.__index = disconnecterClass
	function disconnecterClass:Add(connection)
		insert(self,connection)
	end
	function disconnecterClass:Disconnect()
		for i,v in ipairs(self) do
			pcall(v.Disconnect,v)
			self[i] = nil
		end
	end
	function disconnecterClass:Destroy()
		local id = self.id
		if id then
			disconnecters[id] = nil
		end
		for i,v in ipairs(self) do
			pcall(v.Disconnect,v)
			self[i] = nil
		end
		setmetatable(self,nil)
	end
	function disconnecterClass.New(id)
		if id then
			local old = disconnecters[id];
			if old then
				return old;
			end
		end
		local this = setmetatable({id = id},disconnecterClass);
		if id then
			disconnecters[id] = this;
		end
		return this;
	end
	new.Disconnecter = disconnecterClass

	local connection = {__type = "connection"}
	connection.__index = connection
	function connection.New(signal,func)
		return setmetatable({signal = signal,func = func},connection)
	end
	function connection:Disconnect(slient)
		local signal = self.signal
		local onceConnection = signal.onceConnection
		local connections = signal.connection

		if connections then
			for i,v in ipairs(connections) do
				if v.connection == self then
					remove(connections,i)
					return true
				end
			end
		end
		if onceConnection then
			for i,v in ipairs(onceConnection) do
				if v.connection == self then
					remove(onceConnection,i)
					return true
				end
			end
		end

		if not slient then
			new.warn(("Connection %s is not found from signal %s, but tried :Disconnect(). Maybe disconnected aleady?"):format(tostring(self),tostring(signal)))
		end
		return false
	end
	function connection:Destroy()
		self:Disconnect(true)
	end
	new.Connection = connection

	local bindables = {}
	new.BindableList = bindables
	local bindable = {__type = "bindable"}
	bindable.__index = bindable
	function bindable:Fire(...)
		local waitting = self.waitting
		local onceConnection = self.onceConnection
		local selfWaittingTimeout = self.waittingTimeout
		self.waittingTimeout = nil
		self.waitting = nil
		self.onceConnection = nil

		if selfWaittingTimeout then
			for _,v in pairs(selfWaittingTimeout) do
				new.cancel(v)
			end
		end

		if waitting then
			for _,v in ipairs(waitting) do
				new.spawn(resume,v,...)
			end
		end

		if connection then
			for _,v in ipairs(self.connection) do
				new.spawn(v.func,...)
			end
		end

		if onceConnection then
			for _,v in ipairs(onceConnection) do
				new.spawn(v.func,...)
			end
		end
	end
	function bindable:FireSync(...)
		local selfWaitting = self.waitting
		local selfOnceConnection = self.onceConnection
		local selfWaittingTimeout = self.waittingTimeout
		self.waittingTimeout = nil
		self.waitting = nil
		self.onceConnection = nil

		if selfWaittingTimeout then
			for _,v in pairs(selfWaittingTimeout) do
				new.cancel(v)
			end
		end

		if selfWaitting then
			for _,v in ipairs(selfWaitting) do
				resume(v,...)
			end
		end

		if connection then
			for _,v in ipairs(self.connection) do
				v.func(...)
			end
		end

		if selfOnceConnection then
			for _,v in ipairs(selfOnceConnection) do
				v.func(...)
			end
		end
	end
	function bindable:ReleaseWaittings()
		local waitting = self.waitting
		local selfWaittingTimeout = self.waittingTimeout
		self.waittingTimeout = nil
		self.waitting = nil

		if selfWaittingTimeout then
			for _,v in pairs(selfWaittingTimeout) do
				new.cancel(v)
			end
		end

		if waitting then
			for _,v in ipairs(waitting) do
				new.spawn(resume,v,new.Released)
			end
		end
	end
	function bindable:DisconnectAll(releaseWaittings)
		self.onceConnection,self.connection = nil,nil
		if releaseWaittings then
			self:ReleaseWaittings()
		end
	end
	function bindable:CheckConnected(func)
		local selfOnceConnection = self.onceConnection
		local selfConnection = self.connection
		if selfConnection then
			for _,v in ipairs(selfConnection) do
				if v.func == func then
					return true
				end
			end
		end
		if selfOnceConnection then
			for _,v in ipairs(selfOnceConnection) do
				if v.func == func then
					return true
				end
			end
			return false
		end
	end
	function bindable:Connect(func)
		if self:CheckConnected(func) then
			new.warn(("Function %s Connected already on signal %s"):format(tostring(func),tostring(self)))
		end

		-- create connection list on self
		local selfConnection = self.connection
		if not selfConnection then
			selfConnection = {}
			self.connection = selfConnection
		end

		-- create connection and return it
		local this = connection.New(self,func)
		insert(selfConnection,{func=func,connection=this})
		return this
	end
	function bindable:Once(func)
		if self:CheckConnected(func) then
			new.warn(("Function %s Connected already on signal %s"):format(tostring(func),tostring(self)))
		end

		-- create once connection list on self
		local selfOnceConnection = self.onceConnection
		if not selfOnceConnection then
			selfOnceConnection = {}
			self.onceConnection = selfOnceConnection
		end

		-- create connection and return it
		local this = connection.New(self,func)
		insert(selfOnceConnection,{func=func,connection=this})
		return this
	end
	local function waitTimeout(self,this)
		local selfWaittingTimeout = self.waittingTimeout
		if selfWaittingTimeout then
			selfWaittingTimeout[this] = nil
		end
		local selfWaitting = self.waitting
		if selfWaitting then
			for i,v in pairs(selfWaitting) do
				if v == this then
					remove(selfWaitting,i)
					break
				end
			end
		end

		resume(this,new.Timeouted)
	end
	function bindable:Wait(timeout)
		-- wait list on self
		local selfWaitting = self.waitting
		if not selfWaitting then
			selfWaitting = {}
			self.waitting = selfWaitting
		end

		-- wait for event
		local this = running()
		insert(selfWaitting,this)
		if timeout then
			if not new.delay then
				new.warn("new.delay is not defined. (Has no timeout frontend)")
			end

			-- wait timeout list on self
			local selfWaittingTimeout = self.waittingTimeout
			if not selfWaittingTimeout then
				selfWaittingTimeout = {}
				self.waittingTimeout = selfWaittingTimeout
			end
			selfWaittingTimeout[this] = new.delay(timeout,waitTimeout,self,this)
		end
		return yield()
	end
	function bindable:Destroy()
		local id = self.ID
		if id then
			bindables[id] = nil
		end
		self:DisconnectAll()
		setmetatable(self,nil)
	end
	function bindable.New(id)
		if id and bindables[id] then
			return bindables[id]
		end
		local this = {ID=id,waitting={},onceConnection={},connection={}}
		setmetatable(this,bindable)
		if id then
			bindables[id] = this
		end
		return this
	end
	new.Bindable = bindable

	return new
end

do
	local this = Init()
	this.Init = Init

	return this
end
