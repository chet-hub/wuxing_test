-- 五行元胞自动机：修复版，自动更新+暂停+符号显示
-- 状态：1=木(1绿), 2=火(2红), 3=土(3黄), 4=金(4白), 5=水(5蓝)
-- 操作：空格暂停/继续，R重置，D调试E值

local grid_size = 80
local cell_size = 12  -- 加大防偏移
local transform_threshold = 2
local generate_random_threshold = 0.001
local update_frequency = 0.1


local grid = {}
local next_grid = {}
local symbols = {"^", "*", "#", "o", "v"} 
local colors = {{0,1,0}, {1,0,0}, {1,1,0}, {1,1,1}, {0,0,1}}  -- 木绿火红土黄金白水平蓝
local sheng = {[1]=2, [2]=3, [3]=4, [4]=5, [5]=1}  -- 相生
local ke = {[1]=3, [2]=4, [3]=5, [4]=1, [5]=2}  -- 相克
local timer = 0
local is_paused = false  -- 暂停标志

function love.load()
    love.window.setMode(grid_size * cell_size, grid_size * cell_size)
    love.window.setTitle("五行元胞自动机 - 自动更新")
    math.randomseed(os.time())  -- 随机种子
    -- 初始化网格
    for i = 1, grid_size do
        grid[i] = {}
        next_grid[i] = {}
        for j = 1, grid_size do
            grid[i][j] = math.random(1, 5)
        end
    end
    -- 打印初始网格（前3x3）
    local s = "初始网格(前3x3):\n"
    for i = 1, 3 do
        for j = 1, 3 do
            s = s .. grid[i][j] .. " "
        end
        s = s .. "\n"
    end
    print(s .. "按空格暂停/继续，R重置，D调试")
end

function get_neighbors(i, j)
    local neighbors = {}
    local dirs = {{-1,-1}, {-1,0}, {-1,1}, {0,-1}, {0,1}, {1,-1}, {1,0}, {1,1}}
    for _, d in ipairs(dirs) do
        local ni = (i + d[1] - 1) % grid_size + 1
        local nj = (j + d[2] - 1) % grid_size + 1
        table.insert(neighbors, grid[ni][nj])
    end
    return neighbors
end

function calculate_E(current, neighbors)
    local E = 0
    for _, n in ipairs(neighbors) do
        if current == 1 then  -- 木
            if n == 2 or n == 5 then E = E + 1 end
            if n == 3 then E = E - 1 end
        elseif current == 2 then  -- 火
            if n == 1 or n == 3 then E = E + 1 end
            if n == 4 then E = E - 1 end
        elseif current == 3 then  -- 土
            if n == 2 or n == 4 then E = E + 1 end
            if n == 1 or n == 5 then E = E - 1 end
        elseif current == 4 then  -- 金
            if n == 3 or n == 5 then E = E + 1 end
            if n == 2 then E = E - 1 end
        elseif current == 5 then  -- 水
            if n == 1 or n == 4 then E = E + 1 end
            if n == 3 then E = E - 1 end
        end
    end
    return E
end

function update_grid()
    for i = 1, grid_size do
        for j = 1, grid_size do
            local current = grid[i][j]
            local neigh = get_neighbors(i, j)
            local E = calculate_E(current, neigh)
            if math.random() < generate_random_threshold then
                next_grid[i][j] = math.random(1, 5)
            elseif E >= transform_threshold then
                next_grid[i][j] = sheng[current]
            elseif E <= -transform_threshold then
                next_grid[i][j] = ke[current]
            else
                next_grid[i][j] = current
            end
        end
    end
    for i = 1, grid_size do
        for j = 1, grid_size do
            grid[i][j] = next_grid[i][j]
        end
    end
end

function love.update(dt)
    if not is_paused then
        timer = timer + dt
        if timer > update_frequency then
            update_grid()
            timer = 0
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        is_paused = not is_paused
        print(is_paused and "暂停" or "继续")
    elseif key == "r" then
        math.randomseed(os.time())
        for i = 1, grid_size do
            for j = 1, grid_size do
                grid[i][j] = math.random(1, 5)
            end
        end
        print("重置随机")
    elseif key == "d" then
        local i, j = math.floor(grid_size/2)+1, math.floor(grid_size/2)+1
        local current = grid[i][j]
        local neigh = get_neighbors(i, j)
        local E = calculate_E(current, neigh)
        print("中心("..i..","..j..")="..symbols[current]..", E="..E.." (邻居:"..table.concat(neigh, ",")..")")
    end
end

function love.draw()
    for i = 1, grid_size do
        for j = 1, grid_size do
            love.graphics.setColor(colors[grid[i][j]])
            love.graphics.print(symbols[grid[i][j]], (j-1)*cell_size, (i-1)*cell_size)
        end
    end
    love.graphics.setColor(1, 1, 1)
end