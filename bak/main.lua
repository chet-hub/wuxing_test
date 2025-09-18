-- Wu Xing (Five Elements) Cellular Automaton: Enhanced Version
-- States: 1=Wood(Green), 2=Fire(Red), 3=Earth(Yellow), 4=Metal(White), 5=Water(Blue)
-- Controls: Space=Pause/Resume, R=Reset, D=Debug, S=Step, +/-=Speed, 1-5+Click=Paint

-- Adjustable parameters
local grid_size = 80
local cell_size = 8
local update_interval = 0.3
local brush_size = 8

-- Energy thresholds (adjustable with hotkeys)
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
local brush_element = -1  -- -1=disabled, 0=erase, 1-5=element brush
local stats = {0, 0, 0, 0, 0}

function love.load()
    love.window.setMode(grid_size * cell_size + 250, grid_size * cell_size + 50)
    love.window.setTitle("Wu Xing Cellular Automaton")
    love.graphics.setFont(love.graphics.newFont(12))  -- Smaller font for smaller cells
    
    math.randomseed(os.time())
    initialize_with_pattern()
    
    print("Controls:")
    print("Space: Pause/Resume")
    print("R: Reset random")
    print("S: Single step")
    print("+/-: Adjust speed")
    print("P: Special pattern")
    print("1-5 + Click: Paint elements")
    print("6 + Click: Erase (empty)")
    print("0: Disable brush")
    print("")
    print("Grid Size:")
    print("[ ]: Increase/Decrease grid size")
    print("")
    print("Thresholds (Q/W/E/R/T/Y/U):")
    print("Q/A: Birth energy ±1")
    print("W/S: Transform energy ±1") 
    print("E/D: Death energy ±1")
    print("R/F: Disappear energy ±1")
    print("T/G: Neighbor birth threshold ±1")
    print("Y/H: Random death rate ±0.01")
    print("U/J: Birth probability ±0.1")
end

function resize_grid(new_size)
    local old_grid = {}
    local old_size = grid_size
    
    -- Save current grid
    for i = 1, old_size do
        old_grid[i] = {}
        for j = 1, old_size do
            old_grid[i][j] = grid[i][j]
        end
    end
    
    grid_size = math.max(20, math.min(200, new_size))  -- Clamp between 20-200
    
    -- Resize window
    love.window.setMode(grid_size * cell_size + 250, grid_size * cell_size + 50)
    
    -- Create new grid
    grid = {}
    next_grid = {}
    for i = 1, grid_size do
        grid[i] = {}
        next_grid[i] = {}
        for j = 1, grid_size do
            -- Copy from old grid if within bounds, otherwise empty
            if i <= old_size and j <= old_size then
                grid[i][j] = old_grid[i][j]
            else
                grid[i][j] = 0
            end
        end
    end
    
    print("Grid resized to " .. grid_size .. "x" .. grid_size)
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

local brush_size = 8

function love.mousepressed(x, y, button)
    if button == 1 and brush_element >= 0 then  -- 左键画笔
        local grid_cx = math.floor(y / cell_size) + 1  -- 中心格子坐标
        local grid_cy = math.floor(x / cell_size) + 1

        -- 半径（因为要以中心扩展）
        local half = math.floor(brush_size / 2)

        -- 遍历方形区域
        for gx = grid_cx - half, grid_cx + half do
            for gy = grid_cy - half, grid_cy + half do
                if gx >= 1 and gx <= grid_size and gy >= 1 and gy <= grid_size then
                    grid[gx][gy] = brush_element
                end
            end
        end

        -- 打印提示
        if brush_element == 0 then
            print("Erased area centered at (" .. grid_cx .. "," .. grid_cy .. "), size=" .. brush_size)
        else
            print("Painted " .. symbols[brush_element] ..
                  " area centered at (" .. grid_cx .. "," .. grid_cy .. "), size=" .. brush_size)
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
        update_interval = math.max(0.05, update_interval - 0.05)
        print("Speed up - Interval: " .. string.format("%.2f", update_interval))
    elseif key == "-" or key == "kp-" then
        update_interval = update_interval + 0.05
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
    elseif key == "6" then
        brush_element = 0
        print("Brush set to Erase (Empty)")
    elseif key == "0" then
        brush_element = -1  -- Disabled state
        print("Brush disabled")
    elseif key == "8" then
        brush_size = brush_size - 1  
    elseif key == "9" then
        brush_size = brush_size + 1  
    elseif key == "[" then
        resize_grid(grid_size - 10)
    elseif key == "]" then
        resize_grid(grid_size + 10)
    -- Threshold controls
    elseif key == "q" then
        birth_energy_threshold = birth_energy_threshold + 1
        print("Birth energy threshold: " .. birth_energy_threshold)
    elseif key == "a" then
        birth_energy_threshold = birth_energy_threshold - 1
        print("Birth energy threshold: " .. birth_energy_threshold)
    elseif key == "w" then
        transform_energy_threshold = transform_energy_threshold + 1
        print("Transform energy threshold: " .. transform_energy_threshold)
    elseif key == "s" then
        transform_energy_threshold = transform_energy_threshold - 1
        print("Transform energy threshold: " .. transform_energy_threshold)
    elseif key == "e" then
        death_energy_threshold = death_energy_threshold + 1
        print("Death energy threshold: " .. death_energy_threshold)
    elseif key == "d" then
        death_energy_threshold = death_energy_threshold - 1
        print("Death energy threshold: " .. death_energy_threshold)
    elseif key == "r" then
        disappear_energy_threshold = disappear_energy_threshold + 1
        print("Disappear energy threshold: " .. disappear_energy_threshold)
    elseif key == "f" then
        disappear_energy_threshold = disappear_energy_threshold - 1
        print("Disappear energy threshold: " .. disappear_energy_threshold)
    elseif key == "t" then
        neighbor_birth_threshold = math.min(8, neighbor_birth_threshold + 1)
        print("Neighbor birth threshold: " .. neighbor_birth_threshold)
    elseif key == "g" then
        neighbor_birth_threshold = math.max(1, neighbor_birth_threshold - 1)
        print("Neighbor birth threshold: " .. neighbor_birth_threshold)
    elseif key == "y" then
        random_death_rate = math.min(1.0, random_death_rate + 0.01)
        print("Random death rate: " .. string.format("%.3f", random_death_rate))
    elseif key == "h" then
        random_death_rate = math.max(0.0, random_death_rate - 0.01)
        print("Random death rate: " .. string.format("%.3f", random_death_rate))
    elseif key == "u" then
        birth_probability = math.min(1.0, birth_probability + 0.1)
        print("Birth probability: " .. string.format("%.2f", birth_probability))
    elseif key == "j" then
        birth_probability = math.max(0.0, birth_probability - 0.1)
        print("Birth probability: " .. string.format("%.2f", birth_probability))
    elseif key == "z" then  -- Debug info (moved from 'd' to avoid conflict)
        print("Generation: " .. generation)
        print("Grid size: " .. grid_size .. "x" .. grid_size)
        print("Element distribution - Wood:" .. stats[1] .. " Fire:" .. stats[2] .. " Earth:" .. stats[3] .. " Metal:" .. stats[4] .. " Water:" .. stats[5])
        print("Current thresholds:")
        print("  Birth energy: " .. birth_energy_threshold)
        print("  Transform energy: " .. transform_energy_threshold)  
        print("  Death energy: " .. death_energy_threshold)
        print("  Disappear energy: " .. disappear_energy_threshold)
        print("  Neighbor birth: " .. neighbor_birth_threshold)
        print("  Random death rate: " .. string.format("%.3f", random_death_rate))
        print("  Birth probability: " .. string.format("%.2f", birth_probability))
        
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
                
                -- Draw symbol (only if cell is big enough)
                if cell_size >= 10 then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.print(symbols[element], (j-1)*cell_size + 1, (i-1)*cell_size)
                end
            end
        end
    end
    
    -- Draw brush preview
    if brush_element >= 0 then
        local mx, my = love.mouse.getPosition()
        local center_x = math.floor(my / cell_size) + 1
        local center_y = math.floor(mx / cell_size) + 1
        local half_size = math.floor(brush_size / 2)
        
        for dx = -half_size, half_size do
            for dy = -half_size, half_size do
                local grid_x = center_x + dx
                local grid_y = center_y + dy
                
                if grid_x >= 1 and grid_x <= grid_size and grid_y >= 1 and grid_y <= grid_size then
                    love.graphics.setColor(1, 1, 1, 0.8)  -- Semi-transparent white
                    love.graphics.rectangle("line", (grid_y-1)*cell_size, (grid_x-1)*cell_size, cell_size-1, cell_size-1)
                end
            end
        end
    end
    
    -- Draw info panel
    love.graphics.setColor(1, 1, 1)
    local info_x = grid_size * cell_size + 15
    local y_offset = 25
    
    love.graphics.print("Wu Xing Cellular Automaton", info_x, y_offset)
    y_offset = y_offset + 25
    
    love.graphics.print("Generation: " .. generation, info_x, y_offset)
    y_offset = y_offset + 20
    
    love.graphics.print("Grid: " .. grid_size .. "x" .. grid_size, info_x, y_offset)
    y_offset = y_offset + 20
    
    love.graphics.print("Speed: " .. string.format("%.2f", update_interval) .. "s", info_x, y_offset)
    y_offset = y_offset + 20
    
    love.graphics.print(is_paused and "Status: PAUSED" or "Status: RUNNING", info_x, y_offset)
    y_offset = y_offset + 30
    
    -- Brush info
    if brush_element > 0 then
        love.graphics.setColor(colors[brush_element])
        love.graphics.print("Brush: " .. symbols[brush_element] .. " (" .. brush_size .. "x" .. brush_size .. ")", info_x, y_offset)
    elseif brush_element == 0 then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Brush: ERASE (" .. brush_size .. "x" .. brush_size .. ")", info_x, y_offset)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Brush: OFF", info_x, y_offset)
    end
    y_offset = y_offset + 35
    
    -- Element statistics
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("=== ELEMENT COUNT ===", info_x, y_offset)
    y_offset = y_offset + 25
    
    local element_names = {"Wood", "Fire", "Earth", "Metal", "Water"}
    for i = 1, 5 do
        love.graphics.setColor(colors[i])
        love.graphics.print(element_names[i] .. ": " .. stats[i], info_x, y_offset)
        y_offset = y_offset + 18
    end
    y_offset = y_offset + 15
    
    -- Thresholds
    love.graphics.setColor(0.9, 0.9, 0.6)
    love.graphics.print("=== THRESHOLDS ===", info_x, y_offset)
    y_offset = y_offset + 25
    
    love.graphics.print("Birth Energy: " .. birth_energy_threshold .. " (Q/A)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Transform E: " .. transform_energy_threshold .. " (W/S)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Death Energy: " .. death_energy_threshold .. " (E/D)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Disappear E: " .. disappear_energy_threshold .. " (R/F)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Neighbor: " .. neighbor_birth_threshold .. " (T/G)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Death Rate: " .. string.format("%.3f", random_death_rate) .. " (Y/H)", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Birth Prob: " .. string.format("%.2f", birth_probability) .. " (U/J)", info_x, y_offset)
    y_offset = y_offset + 25
    
    -- Controls
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("=== CONTROLS ===", info_x, y_offset)
    y_offset = y_offset + 25
    
    love.graphics.print("Space: Pause/Resume", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("S: Single Step", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("+/-: Speed Control", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("[ ]: Grid Size", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("P: Ring Pattern", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("1-5: Set Brush", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("6: Erase Brush", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("9/8: Brush Size", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("0: Disable Brush", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Z: Debug Info", info_x, y_offset)
    y_offset = y_offset + 25
    
    -- Wu Xing relationships  
    love.graphics.setColor(0.6, 0.8, 1.0)
    love.graphics.print("=== WU XING RULES ===", info_x, y_offset)
    y_offset = y_offset + 25
    love.graphics.print("Generation Cycle:", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Wood → Fire → Earth", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("→ Metal → Water → Wood", info_x, y_offset)
    y_offset = y_offset + 20
    love.graphics.print("Destruction Cycle:", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Wood > Earth, Fire > Metal", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Earth > Water, Metal > Wood", info_x, y_offset)
    y_offset = y_offset + 18
    love.graphics.print("Water > Fire", info_x, y_offset)
end