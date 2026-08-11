# ============================================================
#  星陨之境 / Aetherfall — Windows 启动器 (PowerShell)
#  用法：powershell -ExecutionPolicy Bypass -File play.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Definition

$candidates = @()
if ($env:GODOT) { $candidates += $env:GODOT }
$candidates += Join-Path $proj "tools\godot\Godot_v4.7-stable_win64.exe"
$candidates += Join-Path $proj "..\tools\godot\Godot_v4.7-stable_win64.exe"
$candidates += Join-Path $proj "Godot_v4.7-stable_win64.exe"

$godot = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $godot = $c; break }
}

if (-not $godot) {
    Write-Host "[Aetherfall] 未找到 Godot 引擎二进制。" -ForegroundColor Red
    Write-Host "  请把 Godot_v4.7-stable_win64.exe 放到与 play.ps1 同目录 / tools\godot\ / 上级 tools\godot\，或设置环境变量 GODOT。"
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host "[Aetherfall] 启动星陨之境 / Aetherfall ..." -ForegroundColor Cyan
& $godot --path $proj --resolution 1280x720 --windowed
