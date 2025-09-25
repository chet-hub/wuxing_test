local fennel = require("lib.fennel")
fennel.install()
local TestRunner = require("lib.cc.test")


function love.load(args)
    pcall(TestRunner.try_run_tests,args)
    print("--- 启动主游戏 ---")
end

