@echo off
setlocal

:: 1. 强制切换到脚本所在目录 (解决路径错误和 /d 问题)
cd /d "%~dp0"

REM 删除旧文件，防止干扰
if exist TankGame.obj del TankGame.obj
if exist TankGame.exe del TankGame.exe

REM 2. 编译 (使用 ml)
echo [1/2] Compiling...
ml /c /coff TankGame.asm
if errorlevel 1 goto err

REM 3. 链接 (使用 link)
echo [2/2] Linking...
link /subsystem:windows TankGame.obj
if errorlevel 1 goto err

echo.
echo =========================
echo   Build SUCCESS! Launching Game...
echo =========================

REM 4. 成功后直接启动程序

start TankGame.exe

goto :eof

:err
echo.
echo =========================
echo   Build FAILED! 
echo =========================
pause
exit /b 1