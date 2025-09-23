-- main.lua (核心片段)
local unit = {x=100, y=100, speed=500, target=nil, selected=false}

function love.draw()
  love.graphics.setColor(1,0,0)
  love.graphics.rectangle("fill", unit.x-6, unit.y-6, 12,12)
  if unit.selected then
    love.graphics.setColor(0,1,0)
    love.graphics.rectangle("line", unit.x-10, unit.y-10, 20,20)
  end
end

function love.update(dt)
  if unit.target then
    local dx = unit.target.x - unit.x
    local dy = unit.target.y - unit.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 1 then
      unit.x = unit.x + dx/dist * unit.speed * dt
      unit.y = unit.y + dy/dist * unit.speed * dt
    else
      unit.target = nil
    end
  end
end

function love.mousepressed(x,y,button)
  if button == 1 then -- left select
    if (x-unit.x)^2 + (y-unit.y)^2 < 10*10 then unit.selected = true else unit.selected=false end
  elseif button == 2 and unit.selected then -- right move
    unit.target = {x=x,y=y}
  end
end
