--[[
# how to use
function love.load(args)
    local success, result =  pcall(TestRunner.try_run_tests,args)
    if success and result == true then
        -- 程序已接管并退出，这里不需要做任何事
        return
    end
    print("--- 启动主游戏 ---")
end

# test file example: *_test.lua, file and function name must end with _test 

function example_test()
    local p = { name = "Alice", hp = 100 }
    assert(p.name == "Alice", "Name should be Alice") -- pass
    assert(p.hp == 90, "HP should be 90")             -- fail
end

function another_test()
    local p = { hp = 100 }
    p.hp = p.hp - 20
    assert(p.hp == 80, "HP should be 80")             -- pass
end

# test result example:
--- Running tests in src/example_test.lua ---   
[PASS] src/example_test.lua example_test
[FAIL] src/example_test.lua another_test [ASSERT FAIL] HP should be 80

--- Test finished ---
Total test functions: 2, Passed: 1, Failed: 1


# command to run tests:
LOVE --console . "test"

]]

local M = {}

-- 递归扫描指定目录及子目录，找到所有 _test.lua 文件
local function get_test_files(dir)
    dir = dir or ""  -- 根目录传空字符串
    local files = {}

    for _, item in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir == "" and item or dir .. "/" .. item
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "file" and item:match("_test%.lua$") then
                table.insert(files, path)
            elseif info.type == "directory" then
                local subfiles = get_test_files(path) -- 递归子目录
                for _, f in ipairs(subfiles) do
                    table.insert(files, f)
                end
            end
        end
    end

    return files
end

-- 安全断言函数
local function safe_assert(cond, msg)
    if not cond then
        print("[ASSERT FAIL]", msg or "Assertion failed")
        return false
    end
    return true
end


local function run_tests()

    local total_tests, passed_tests = 0, 0

    local test_files = get_test_files("")
    for _, file in ipairs(test_files) do
        -- 打印文件名
        print(string.format("\n--- Running tests in %s ---", file))
        -- 加载测试文件
        local ok, err = pcall(dofile, file)
        if not ok then
            print("[ERROR] Failed to load file:", file, err)
        else
            -- 遍历全局函数表
            for name, func in pairs(_G) do
                if type(func) == "function" and name:match("_test$") then
                    total_tests = total_tests + 1
                    -- 每个函数独立执行，不影响其他
                    local success, err_msg = pcall(function()
                        _G.assert = safe_assert  -- 使用安全断言
                        func()
                    end)
                    if success then
                        print("[PASS]", file, name)
                        passed_tests = passed_tests + 1
                    else
                        print("[FAIL]", file, name, err_msg)
                    end
                end
            end
        end
    end

    print(string.format("\n--- Test finished ---"))
    print(string.format("Total test functions: %d, Passed: %d, Failed: %d",
        total_tests, passed_tests, total_tests - passed_tests))

    -- 清理全局函数表中的测试函数
    for _, file in ipairs(test_files) do
        dofile(file)  -- 重新加载会覆盖
    end

    love.event.quit()
end

function M.try_run_tests(args)
    local is_test_mode = false

    for i, arg in ipairs(args) do
        if arg == "test" then
            is_test_mode = true
            break
        end
    end

    if is_test_mode then
        run_tests()
        return true
    else
        return false
    end
end

return M