-- main.lua
local Concord = require("lib.concord")
local world = Concord.world()

--------------------
-- 组件
--------------------
Concord.component("position", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component("movement", function(c, speed)
    c.speed = speed or 100
end)

Concord.component("target", function(c)
    c.x = nil
    c.y = nil
end)

Concord.component("selectable", function(c)
    c.selected = false
end)

--------------------
-- 系统
--------------------
local MoveSystem = Concord.system({ pool = {"position", "movement", "target"} })

function MoveSystem:update(dt)
    for _, entity in ipairs(self.pool) do
        local pos = entity.position
        local move = entity.movement
        local tgt = entity.target

        if tgt.x and tgt.y then
            local dx = tgt.x - pos.x
            local dy = tgt.y - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local moveDist = move.speed * dt

            if dist <= moveDist then
                pos.x = tgt.x
                pos.y = tgt.y
                entity.target = {} -- 清空目标
            else
                pos.x = pos.x + dx/dist * moveDist
                pos.y = pos.y + dy/dist * moveDist
            end
        end
    end
end

-- 添加系统（注意不要加括号）
world:addSystem(MoveSystem)

--------------------
-- 创建单位
--------------------
local units = {}

local function createUnit(x, y, speed)
    local unit = Concord.entity(world)
        :give("position", x, y)
        :give("movement", speed)
        :give("target")
        :give("selectable")
    table.insert(units, unit)
    return unit
end

-- 创建多个方块
for i = 1, 10 do
    createUnit(50 * i, 50, 100)
end

--------------------
-- 选择逻辑
--------------------
local selectionStart = nil

function love.mousepressed(x, y, button)
    if button == 1 then
        selectionStart = {x = x, y = y}
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and selectionStart then
        local x1, y1 = selectionStart.x, selectionStart.y
        local x2, y2 = x, y
        local minX, maxX = math.min(x1, x2), math.max(x1, x2)
        local minY, maxY = math.min(y1, y2), math.max(y1, y2)

        for _, entity in ipairs(units) do
            local pos = entity.position
            if pos.x >= minX and pos.x <= maxX and pos.y >= minY and pos.y <= maxY then
                if love.keyboard.isDown("lshift") then
                    entity.selectable.selected = true
                else
                    entity.selectable.selected = true
                end
            elseif not love.keyboard.isDown("lshift") then
                entity.selectable.selected = false
            end
        end

        selectionStart = nil
    end
end

-- 点击空地移动选中单位
function love.mousepressed(x, y, button)
    if button == 1 then
        local clickedUnit = nil
        for _, entity in ipairs(units) do
            local pos = entity.position
            if x >= pos.x - 10 and x <= pos.x + 10 and y >= pos.y - 10 and y <= pos.y + 10 then
                clickedUnit = entity
                break
            end
        end

        if clickedUnit then
            if love.keyboard.isDown("lshift") then
                clickedUnit.selectable.selected = true
            else
                for _, entity in ipairs(units) do
                    entity.selectable.selected = false
                end
                clickedUnit.selectable.selected = true
            end
        else
            for _, entity in ipairs(units) do
                if entity.selectable.selected then
                    entity.target = {x = x, y = y}
                end
            end
        end
    end
end

--------------------
-- Love2D 回调
--------------------
function love.update(dt)
    world:emit("update", dt)
end

function love.draw()
    -- 绘制单位
    for _, entity in ipairs(units) do
        local pos = entity.position
        if entity.selectable.selected then
            love.graphics.setColor(0, 1, 0)
        else
            love.graphics.setColor(1, 0, 0)
        end
        love.graphics.rectangle("fill", pos.x - 10, pos.y - 10, 20, 20)
    end

    -- 可视化框选
    if selectionStart then
        local x, y = love.mouse.getPosition()
        love.graphics.setColor(0, 1, 1, 0.3)
        love.graphics.rectangle("line", selectionStart.x, selectionStart.y, x - selectionStart.x, y - selectionStart.y)
    end
end

-- ESC 清空选中状态
function love.keypressed(key)
    if key == "escape" then
        for _, entity in ipairs(units) do
            entity.selectable.selected = false
        end
    end
end
