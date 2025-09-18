-- Wu Xing (Five Elements) Cellular Automaton: Enhanced Version
-- States: 1=Wood(Green), 2=Fire(Red), 3=Earth(Yellow), 4=Metal(White), 5=Water(Blue)
-- Controls: Space=Pause/Resume, R=Reset, D=Debug, S=Step, +/-=Speed, 1-5+Click=Paint

local grid_size = 200
local cell_size = 5
local update_interval = 0.3

-- Energy thresholds (adjustable parameters)
 

--[[  

### 1. `birth_energy_threshold = 3`
* **作用**：当一个空白格（`current = 0`）周围有足够能量的“生成信号”时，这个阈值决定它能否生成新元素。
* **逻辑**：
  * 计算周围邻居元素对当前空格的“生成能量”（根据生克关系）。
  * 如果能量 ≥ `birth_energy_threshold`，空格就有机会诞生一个新元素。
* **调整影响**：
  * 调高 → 新元素更难诞生，网格空白更多。
  * 调低 → 新元素更容易生成，整个网格更活跃。
### 2. `transform_energy_threshold = 3`
* **作用**：决定已有元素在周围能量作用下是否“转化”成它所生的元素。
* **逻辑**：
  * 如果当前元素周围的 **生能量 - 克能量** ≥ `transform_energy_threshold`，它就会变成它生的下一个五行元素（如木生火 → 木转火）。
* **调整影响**：
  * 调高 → 元素转化更困难，格局更稳定。
  * 调低 → 元素更容易变化，格局更动态。
### 3. `death_energy_threshold = -2`
* **作用**：当元素周围受克能量过大时，判断是否被克制而死亡或被替换。
* **逻辑**：
  * 如果 **周围能量** ≤ `death_energy_threshold`，元素会被它的克制元素随机替代或消亡。
* **调整影响**：
  * 调高（绝对值减小） → 元素更容易死亡，格局不稳定。
  * 调低 → 元素更抗击打，生存能力强。
### 4. `disappear_energy_threshold = -3`
* **作用**：当元素受到极端负能量（被克制非常严重）时，它直接消失（空格化）。
* **逻辑**：
  * 能量 ≤ `disappear_energy_threshold` → 元素消失，不被替代。
* **调整影响**：
  * 调高 → 元素容易消失，网格稀疏。
  * 调低 → 元素更稳定，不易消失。
### 5. `random_death_rate = 0.01`
* **作用**：模拟随机死亡或突发事件的概率。
* **逻辑**：
  * 每次更新时，每个元素有 `1%` 的概率直接消失或被清空。
* **调整影响**：
  * 调高 → 元素随机性增加，格局更混乱。
  * 调低 → 元素随机死亡很少，格局更规律。
### 6. `neighbor_birth_threshold = 3`
* **作用**：空格周围至少有多少邻居元素时，才有可能生成新元素。
* **逻辑**：
  * 如果周围非空邻居数量 ≥ 3，则空格有机会诞生新元素（结合 `birth_probability`）。
* **调整影响**：
  * 调高 → 新元素生成需要更多邻居，稀疏。
  * 调低 → 新元素容易生成，网格更密集。
### 7. `birth_probability = 0.3`
* **作用**：控制空格生成新元素的随机概率。
* **逻辑**：
  * 空格满足生成条件后，仍以 `30%` 的概率生成新元素，其余保持空格。
* **调整影响**：
  * 调高 → 空格生成新元素更频繁，格局活跃。
  * 调低 → 新元素生成不稳定，空白更多。
💡 **总结**：
* `birth_energy_threshold` + `neighbor_birth_threshold` + `birth_probability` → 控制 **新元素诞生规则**。
* `transform_energy_threshold` → 控制 **已有元素转化规则**。
* `death_energy_threshold` + `disappear_energy_threshold` + `random_death_rate` → 控制 **元素消亡或克制规则**。
整体上，这些参数就像 **五行的生态系统调节器**，调节能量阈值就能让元胞机呈现不同的“循环平衡”或“动荡格局”。

]]



local birth_energy_threshold = 3
local transform_energy_threshold = 3
local death_energy_threshold = -2
local disappear_energy_threshold = -3
local random_death_rate = 0.01
local neighbor_birth_threshold = 3
local birth_probability = 0.3

local grid = {}
local next_grid = {}
local symbols = {"W", "F", "E", "M", "A"}  -- Wood, Fire, Earth, Metal, wAter
local colors = {{0.2,0.8,0.2}, {0.9,0.2,0.1}, {0.8,0.8,0.2}, {0.9,0.9,0.9}, {0.2,0.4,0.9}}
local sheng = {[1]=2, [2]=3, [3]=4, [4]=5, [5]=1}  -- Generation: Wood->Fire->Earth->Metal->Water->Wood
local ke = {[1]=3, [2]=4, [3]=5, [4]=1, [5]=2}      -- Destruction: Wood->Earth, Fire->Metal, etc.

local timer = 0
local is_paused = false
local generation = 0
local brush_element = 0  -- 0=no brush, 1-5=element brush
local stats = {0, 0, 0, 0, 0}

function love.load()
    love.window.setMode(grid_size * cell_size + 200, grid_size * cell_size)
    love.window.setTitle("Wu Xing Cellular Automaton")
    love.graphics.setFont(love.graphics.newFont(12))
    
    math.randomseed(os.time())
    initialize_with_pattern()
    
    print("Controls:")
    print("Space: Pause/Resume")
    print("R: Reset random")
    print("S: Single step")
    print("+/-: Adjust speed")
    print("P: Special pattern")
    print("1-5 + Click: Paint elements")
    print("D: Debug info")
end

function initialize_with_pattern()
    for i = 1, grid_size do
        grid[i] = {}
        next_grid[i] = {}
        for j = 1, grid_size do
            if math.random() < 0.3 then
                grid[i][j] = 0  -- Empty space
            else
                grid[i][j] = math.random(1, 5)
            end
        end
    end
    
    -- Create Wu Xing cycle core in center
    local center = math.floor(grid_size/2)
    for offset = -2, 2 do
        if center + offset > 0 and center + offset <= grid_size then
            grid[center][center + offset] = ((offset + 2) % 5) + 1
            grid[center + offset][center] = ((offset + 2) % 5) + 1
        end
    end
end

function get_neighbors(i, j)
    local neighbors = {}
    local dirs = {{-1,-1}, {-1,0}, {-1,1}, {0,-1}, {0,1}, {1,-1}, {1,0}, {1,1}}
    
    for _, d in ipairs(dirs) do
        local ni = i + d[1]
        local nj = j + d[2]
        
        -- Wrap-around boundaries
        if ni < 1 then ni = grid_size end
        if ni > grid_size then ni = 1 end
        if nj < 1 then nj = grid_size end
        if nj > grid_size then nj = 1 end
        
        if grid[ni][nj] ~= 0 then
            table.insert(neighbors, grid[ni][nj])
        end
    end
    return neighbors
end

function calculate_wuxing_energy(current, neighbors)
    if current == 0 then return 0 end
    
    local sheng_count = 0    -- Times being generated
    local ke_me_count = 0    -- Times being destroyed
    local i_sheng_count = 0  -- Times I generate others
    local i_ke_count = 0     -- Times I destroy others
    
    for _, n in ipairs(neighbors) do
        if sheng[n] == current then sheng_count = sheng_count + 1 end
        if ke[n] == current then ke_me_count = ke_me_count + 1 end
        if sheng[current] == n then i_sheng_count = i_sheng_count + 1 end
        if ke[current] == n then i_ke_count = i_ke_count + 1 end
    end
    
    local energy = sheng_count * 2 - ke_me_count * 2 - i_sheng_count * 0.5 - i_ke_count * 0.5
    return energy
end

function find_birth_element(neighbors)
    local element_strength = {0, 0, 0, 0, 0}
    
    for _, n in ipairs(neighbors) do
        element_strength[sheng[n]] = element_strength[sheng[n]] + 1
    end
    
    local max_strength = 0
    local birth_element = math.random(1, 5)
    
    for i = 1, 5 do
        if element_strength[i] > max_strength then
            max_strength = element_strength[i]
            birth_element = i
        end
    end
    
    return birth_element
end

function update_grid()
    for i = 1, 5 do stats[i] = 0 end
    local empty_count = 0
    
    for i = 1, grid_size do
        for j = 1, grid_size do
            local current = grid[i][j]
            local neighbors = get_neighbors(i, j)
            
            if current == 0 then  -- Empty space - potential birth
                empty_count = empty_count + 1
                if #neighbors >= neighbor_birth_threshold then
                    local birth_prob = (#neighbors / 8.0) * birth_probability
                    if math.random() < birth_prob then
                        next_grid[i][j] = find_birth_element(neighbors)
                    else
                        next_grid[i][j] = 0
                    end
                else
                    next_grid[i][j] = 0
                end
            else  -- Existing element transformation
                local energy = calculate_wuxing_energy(current, neighbors)
                
                if math.random() < random_death_rate then
                    next_grid[i][j] = 0  -- Random death
                elseif energy >= transform_energy_threshold then
                    next_grid[i][j] = sheng[current]  -- Transform to generated element
                elseif energy <= death_energy_threshold then
                    -- Transform to element that destroys me
                    local destroyers = {}
                    for k, v in pairs(ke) do
                        if v == current then table.insert(destroyers, k) end
                    end
                    if #destroyers > 0 then
                        next_grid[i][j] = destroyers[math.random(#destroyers)]
                    else
                        next_grid[i][j] = 0
                    end
                elseif energy <= disappear_energy_threshold then
                    next_grid[i][j] = 0  -- Disappear
                else
                    next_grid[i][j] = current  -- Stay the same
                end
            end
        end
    end
    
    -- Apply changes and count statistics
    for i = 1, grid_size do
        for j = 1, grid_size do
            grid[i][j] = next_grid[i][j]
            if grid[i][j] > 0 then
                stats[grid[i][j]] = stats[grid[i][j]] + 1
            end
        end
    end
    
    generation = generation + 1
end

function love.update(dt)
    if not is_paused then
        timer = timer + dt
        if timer > update_interval then
            update_grid()
            timer = 0
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and brush_element > 0 then  -- Left click with brush
        local grid_x = math.floor(y / cell_size) + 1
        local grid_y = math.floor(x / cell_size) + 1
        
        if grid_x >= 1 and grid_x <= grid_size and grid_y >= 1 and grid_y <= grid_size then
            grid[grid_x][grid_y] = brush_element
            print("Painted " .. symbols[brush_element] .. " at (" .. grid_x .. "," .. grid_y .. ")")
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        is_paused = not is_paused
        print(is_paused and "Paused" or "Running")
    elseif key == "r" then
        generation = 0
        initialize_with_pattern()
        print("Grid reset")
    elseif key == "s" then
        if is_paused then
            update_grid()
            print("Single step - Generation: " .. generation)
        end
    elseif key == "=" or key == "kp+" then
        update_interval = math.max(0.01, update_interval - 0.01)
        print("Speed up - Interval: " .. string.format("%.2f", update_interval))
    elseif key == "-" or key == "kp-" then
        update_interval = update_interval + 0.01
        print("Speed down - Interval: " .. string.format("%.2f", update_interval))
    elseif key == "p" then
        -- Create special Wu Xing ring pattern
        local center = math.floor(grid_size/2)
        for i = 1, grid_size do
            for j = 1, grid_size do
                grid[i][j] = 0
            end
        end
        
        local positions = {
            {center-1, center-1, 1}, -- Wood
            {center-1, center+1, 2}, -- Fire  
            {center+1, center+1, 3}, -- Earth
            {center+1, center-1, 4}, -- Metal
            {center, center, 5}      -- Water
        }
        for _, pos in ipairs(positions) do
            if pos[1] > 0 and pos[1] <= grid_size and pos[2] > 0 and pos[2] <= grid_size then
                grid[pos[1]][pos[2]] = pos[3]
            end
        end
        print("Wu Xing ring pattern set")
    elseif key == "1" then
        brush_element = 1
        print("Brush set to Wood (Green)")
    elseif key == "2" then
        brush_element = 2
        print("Brush set to Fire (Red)")
    elseif key == "3" then
        brush_element = 3
        print("Brush set to Earth (Yellow)")
    elseif key == "4" then
        brush_element = 4
        print("Brush set to Metal (White)")
    elseif key == "5" then
        brush_element = 5
        print("Brush set to Water (Blue)")
    elseif key == "0" then
        brush_element = 0
        print("Brush disabled")
    elseif key == "d" then
        print("Generation: " .. generation)
        print("Element distribution - Wood:" .. stats[1] .. " Fire:" .. stats[2] .. " Earth:" .. stats[3] .. " Metal:" .. stats[4] .. " Water:" .. stats[5])
        
        -- Show center area details
        local center = math.floor(grid_size/2)
        print("Center area (5x5):")
        for i = center-2, center+2 do
            local line = ""
            for j = center-2, center+2 do
                if i > 0 and i <= grid_size and j > 0 and j <= grid_size then
                    line = line .. (grid[i][j] == 0 and "." or tostring(grid[i][j])) .. " "
                else
                    line = line .. "  "
                end
            end
            print(line)
        end
    end
end

function love.draw()
    -- Draw grid
    for i = 1, grid_size do
        for j = 1, grid_size do
            local element = grid[i][j]
            if element > 0 then
                love.graphics.setColor(colors[element])
                love.graphics.rectangle("fill", (j-1)*cell_size, (i-1)*cell_size, cell_size-1, cell_size-1)
                
                -- Draw symbol
                love.graphics.setColor(0, 0, 0)
                love.graphics.print(symbols[element], (j-1)*cell_size + 2, (i-1)*cell_size + 1)
            end
        end
    end
    
    -- Draw info panel
    love.graphics.setColor(1, 1, 1)
    local info_x = grid_size * cell_size + 10
    love.graphics.print("Wu Xing Cellular Automaton", info_x, 20)
    love.graphics.print("Generation: " .. generation, info_x, 50)
    love.graphics.print("Speed: " .. string.format("%.2f", update_interval) .. "s", info_x, 70)
    love.graphics.print(is_paused and "Status: Paused" or "Status: Running", info_x, 90)
    
    -- Brush info
    if brush_element > 0 then
        love.graphics.setColor(colors[brush_element])
        love.graphics.print("Brush: " .. symbols[brush_element], info_x, 110)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Brush: Off", info_x, 110)
    end
    
    -- Element statistics
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("=== Element Count ===", info_x, 140)
    local element_names = {"Wood", "Fire", "Earth", "Metal", "Water"}
    for i = 1, 5 do
        love.graphics.setColor(colors[i])
        love.graphics.print(element_names[i] .. ": " .. stats[i], info_x, 160 + i * 20)
    end
    
    -- Controls
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("=== Controls ===", info_x, 280)
    love.graphics.print("Space: Pause/Resume", info_x, 300)
    love.graphics.print("S: Single step", info_x, 320)
    love.graphics.print("+/-: Speed control", info_x, 340)
    love.graphics.print("R: Reset", info_x, 360)
    love.graphics.print("P: Ring pattern", info_x, 380)
    love.graphics.print("1-5: Set brush", info_x, 400)
    love.graphics.print("0: Disable brush", info_x, 420)
    love.graphics.print("D: Debug info", info_x, 440)
    
    -- Wu Xing relationships
    love.graphics.print("=== Wu Xing Rules ===", info_x, 500)
    love.graphics.print("Generation: W->F->E->M->A->W", info_x, 520)
    love.graphics.print("Destruction: W>E, F>M", info_x, 540)
    love.graphics.print("             E>A, M>W", info_x, 560)
    love.graphics.print("             A>F", info_x, 580)
end