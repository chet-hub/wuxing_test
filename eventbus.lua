-- 事件总线系统 (EventBus System)
-- 为微内核提供解耦的消息传递机制

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    local self = setmetatable({}, EventBus)
    
    -- 事件监听器存储
    self.listeners = {}  -- {eventName: {callback1, callback2, ...}}
    self.onceListeners = {}  -- 只触发一次的监听器
    
    -- 事件队列（用于延迟处理）
    self.eventQueue = {}
    self.isProcessing = false
    
    -- 调试统计
    self.stats = {
        eventsEmitted = 0,
        eventsProcessed = 0,
        listenersCount = 0
    }
    
    return self
end

-- 注册事件（可选，用于预定义事件类型）
function EventBus:registerEvent(eventName)
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
        self.onceListeners[eventName] = {}
    end
end

-- 添加事件监听器
function EventBus:on(eventName, callback, context)
    if type(callback) ~= "function" then
        error("事件回调必须是函数类型")
    end
    
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end
    
    local listener = {
        callback = callback,
        context = context
    }
    
    table.insert(self.listeners[eventName], listener)
    self.stats.listenersCount = self.stats.listenersCount + 1
    
    return listener  -- 返回监听器引用用于移除
end

-- 添加一次性事件监听器
function EventBus:once(eventName, callback, context)
    if type(callback) ~= "function" then
        error("事件回调必须是函数类型")
    end
    
    if not self.onceListeners[eventName] then
        self.onceListeners[eventName] = {}
    end
    
    local listener = {
        callback = callback,
        context = context
    }
    
    table.insert(self.onceListeners[eventName], listener)
    
    return listener
end

-- 移除事件监听器
function EventBus:off(eventName, callback)
    if not eventName then
        -- 清空所有监听器
        self.listeners = {}
        self.onceListeners = {}
        self.stats.listenersCount = 0
        return
    end
    
    if not callback then
        -- 清空特定事件的所有监听器
        if self.listeners[eventName] then
            self.stats.listenersCount = self.stats.listenersCount - #self.listeners[eventName]
            self.listeners[eventName] = {}
        end
        if self.onceListeners[eventName] then
            self.onceListeners[eventName] = {}
        end
        return
    end
    
    -- 移除特定的监听器
    local removed = false
    
    if self.listeners[eventName] then
        for i = #self.listeners[eventName], 1, -1 do
            local listener = self.listeners[eventName][i]
            if listener.callback == callback then
                table.remove(self.listeners[eventName], i)
                self.stats.listenersCount = self.stats.listenersCount - 1
                removed = true
            end
        end
    end
    
    if self.onceListeners[eventName] then
        for i = #self.onceListeners[eventName], 1, -1 do
            local listener = self.onceListeners[eventName][i]
            if listener.callback == callback then
                table.remove(self.onceListeners[eventName], i)
                removed = true
            end
        end
    end
    
    return removed
end

-- 触发事件
function EventBus:emit(eventName, ...)
    self.stats.eventsEmitted = self.stats.eventsEmitted + 1
    
    -- 立即处理常规监听器
    if self.listeners[eventName] then
        for _, listener in ipairs(self.listeners[eventName]) do
            self:_callListener(listener, eventName, ...)
        end
    end
    
    -- 处理一次性监听器
    if self.onceListeners[eventName] then
        local onceListeners = self.onceListeners[eventName]
        self.onceListeners[eventName] = {}  -- 清空一次性监听器
        
        for _, listener in ipairs(onceListeners) do
            self:_callListener(listener, eventName, ...)
        end
    end
    
    self.stats.eventsProcessed = self.stats.eventsProcessed + 1
end

-- 延迟触发事件（加入队列）
function EventBus:emitAsync(eventName, ...)
    local args = {...}
    table.insert(self.eventQueue, {
        eventName = eventName,
        args = args
    })
end

-- 处理事件队列
function EventBus:processQueue()
    if self.isProcessing or #self.eventQueue == 0 then
        return
    end
    
    self.isProcessing = true
    
    while #self.eventQueue > 0 do
        local event = table.remove(self.eventQueue, 1)
        self:emit(event.eventName, unpack(event.args))
    end
    
    self.isProcessing = false
end

-- 内部方法：调用监听器
function EventBus:_callListener(listener, eventName, ...)
    local args = {...}
    local success, error = pcall(function()
        if listener.context then
            listener.callback(listener.context, unpack(args))
        else
            listener.callback(unpack(args))
        end
    end)
    
    if not success then
        print(string.format("事件监听器错误 [%s]: %s", eventName, error))
    end
end

-- 获取事件监听器数量
function EventBus:getListenerCount(eventName)
    if eventName then
        local count = 0
        if self.listeners[eventName] then
            count = count + #self.listeners[eventName]
        end
        if self.onceListeners[eventName] then
            count = count + #self.onceListeners[eventName]
        end
        return count
    else
        return self.stats.listenersCount
    end
end

-- 检查是否有监听器
function EventBus:hasListeners(eventName)
    return (self.listeners[eventName] and #self.listeners[eventName] > 0) or
           (self.onceListeners[eventName] and #self.onceListeners[eventName] > 0)
end

-- 获取所有注册的事件名称
function EventBus:getEventNames()
    local events = {}
    
    for eventName, _ in pairs(self.listeners) do
        table.insert(events, eventName)
    end
    
    for eventName, _ in pairs(self.onceListeners) do
        if not self.listeners[eventName] then
            table.insert(events, eventName)
        end
    end
    
    return events
end

-- 清空事件队列
function EventBus:clearQueue()
    self.eventQueue = {}
end

-- 获取统计信息
function EventBus:getStats()
    return {
        eventsEmitted = self.stats.eventsEmitted,
        eventsProcessed = self.stats.eventsProcessed,
        listenersCount = self.stats.listenersCount,
        queueLength = #self.eventQueue,
        isProcessing = self.isProcessing,
        eventTypes = #self:getEventNames()
    }
end

-- 调试方法：打印所有监听器
function EventBus:debug()
    print("=== EventBus Debug Info ===")
    print("Stats:", self:getStats())
    print("Events:")
    
    for eventName, listeners in pairs(self.listeners) do
        print(string.format("  %s: %d listeners", eventName, #listeners))
    end
    
    for eventName, listeners in pairs(self.onceListeners) do
        if #listeners > 0 then
            print(string.format("  %s: %d once listeners", eventName, #listeners))
        end
    end
    
    if #self.eventQueue > 0 then
        print("Queued events:", #self.eventQueue)
    end
end

return EventBus