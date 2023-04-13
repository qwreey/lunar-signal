
local wrap = coroutine.wrap
local running = coroutine.running
local resume = coroutine.resume
local yield = coroutine.yield
local insert = table.insert
local remove = table.remove

local function _spawn(func,...)
    return wrap(func,...)()
end

local function Init()
    local new = {}
    new.warn = warn
    new.spawn = (task and task.spawn) or _spawn

    -- roblox connections disconnecter
    local disconnecters = {}
    new.DisconnecterList = disconnecters
    local disconnecterClass = {__type = "disconnecter"}
    disconnecterClass.__index = disconnecterClass
    function disconnecterClass:Add(connection)
        insert(self,connection)
    end
    function disconnecterClass:Disconnect()
        for i,v in pairs(self) do
            pcall(v.Disconnect,v)
            self[i] = nil
        end
    end
    function disconnecterClass:Destroy()
        local id = self.id
        if id then
            disconnecters[id] = nil
        end
        for i,v in pairs(self) do
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

        for i,v in pairs(connections) do
            if v.connection == self then
                remove(connections,i)
                return
            end
        end
        for i,v in pairs(onceConnection) do
            if v.connection == self then
                remove(onceConnection,i)
                return
            end
        end

        if not slient then
            new.warn(("Connection %s is not found from signal %s, but tried :Disconnect(). Maybe disconnected aleady?"):format(tostring(self),tostring(signal)))
        end
    end
    function connection:Destroy()
        return self:Disconnect(true)
    end
    new.Connection = connection

    local bindables = {}
    new.BindableList = bindables
    local bindable = {__type = "bindable"}
    bindable.__index = bindable
    function bindable:Fire(...)
        local waitting = self.waitting
        local onceConnection = self.onceConnection
        self.waitting = {}
        self.onceConnection = {}

        for _,v in pairs(waitting) do
            new.spawn(resume,v,...)
        end

        for _,v in pairs(self.connection) do
            new.spawn(v.func,...)
        end

        for _,v in pairs(onceConnection) do
            new.spawn(v.func,...)
        end
    end
    function bindable:DisconnectAll()
        local waitting = self.waitting
        self.waitting = {}
        self.onceConnection = {}
        self.connection = {}
        for _,v in pairs(waitting) do
            new.spawn(resume,v,nil)
        end
    end
    function bindable:Wait()
        insert(self.waitting,running())
        return yield()
    end
    function bindable:CheckConnected(func)
        local onceConnection = self.onceConnection
        local connections = self.connection
        for _,v in pairs(connections) do
            if v.func == func then
                return true
            end
        end
        for _,v in pairs(onceConnection) do
            if v.func == func then
                return true
            end
        end
        return false
    end
    function bindable:Connect(func)
        if self:CheckConnected(func) then
            new.warn(("[Quad] Function %s Connected already on signal %s"):format(tostring(func),tostring(self)))
        end
        local thisConnection = connection.New(self,func)
        insert(self.connection,{func=func,connection=thisConnection})
        return thisConnection
    end
    function bindable:Once(func)
        if self:CheckConnected(func) then
            new.warn(("[Quad] Function %s Connected already on signal %s"):format(tostring(func),tostring(self)))
        end
        local thisConnection = connection.New(self,func)
        insert(self.onceConnection,{func=func,connection=thisConnection})
        return thisConnection
    end
    function bindable:Destroy()
        local id = self.id
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
        local this = {id=id,waitting={},onceConnection={},connection={}}
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
