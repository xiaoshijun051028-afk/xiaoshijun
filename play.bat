@echo off
REM ============================================================
REM  星陨之境 / Aetherfall — Windows 启动器
REM  双击即可游玩（需 Godot 4.7 引擎二进制）。
REM ============================================================
setlocal
set "PROJ=%~dp0"

REM 依次尝试：环境变量 GODOT -> 项目内 tools\godot -> 上级 tools\godot -> 同目录
if defined GODOT (set "GODOT_BIN=%GODOT%") else (set "GODOT_BIN=")
if not defined GODOT_BIN if exist "%PROJ%tools\godot\Godot_v4.7-stable_win64.exe" set "GODOT_BIN=%PROJ%tools\godot\Godot_v4.7-stable_win64.exe"
if not defined GODOT_BIN if exist "%PROJ%..\tools\godot\Godot_v4.7-stable_win64.exe" set "GODOT_BIN=%PROJ%..\tools\godot\Godot_v4.7-stable_win64.exe"
if not defined GODOT_BIN if exist "%PROJ%Godot_v4.7-stable_win64.exe" set "GODOT_BIN=%PROJ%Godot_v4.7-stable_win64.exe"

if not defined GODOT_BIN (
  echo [Aetherfall] 未找到 Godot 引擎二进制。
  echo   请把 Godot_v4.7-stable_win64.exe 放到以下任一位置：
  echo     - 与 play.bat 同目录
  echo     - %PROJ%tools\godot\
  echo     - %PROJ%..\tools\godot\
  echo   或设置环境变量 GODOT 指向它。
  pause
  exit /b 1
)

echo [Aetherfall] 启动星陨之境 / Aetherfall ...
start "" "%GODOT_BIN%" --path "%PROJ%" --resolution 1280x720 --windowed
endlocal
