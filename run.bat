@echo off
REM ==============================
REM Run Love2D game or tests
REM ==============================

set LOVE=C:\DevTools\Love2D\lovec.exe

REM Love2D 总是运行当前目录 (.)
REM 如果传入参数 "test"，则将 "test" 作为参数传递给 Love2D 游戏本身
REM 运行测试：启用 --console 并传递 "test" 参数
if "%1"=="test" (
    "%LOVE%" --console . "test"
) else (
    "%LOVE%" .
)

pause