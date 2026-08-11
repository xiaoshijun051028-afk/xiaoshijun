# ============================================================
#  星陨之境 / Aetherfall — Windows 正式构建脚本
#  前置：Godot 4.7-stable 导出模板已安装到标准模板目录。
#  用法（PowerShell）：
#    $env:GODOT = "C:\path\to\Godot_v4.7-stable_win64.exe"
#    powershell -ExecutionPolicy Bypass -File build_windows.ps1
#  输出：build\Aetherfall.exe + build\Aetherfall.pck
# ============================================================
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- 定位 Godot 二进制 ---
$godot = $null
$candidates = @()
if ($env:GODOT) { $candidates += $env:GODOT }
$candidates += Join-Path $proj "tools\godot\Godot_v4.7-stable_win64.exe"
$candidates += Join-Path $proj "..\tools\godot\Godot_v4.7-stable_win64.exe"
$candidates += Join-Path $proj "Godot_v4.7-stable_win64.exe"
foreach ($c in $candidates) { if (Test-Path $c) { $godot = $c; break } }
if (-not $godot) {
    Write-Error "未找到 Godot 二进制。请设置环境变量 GODOT 指向 Godot_v4.7-stable_win64.exe。"
    exit 1
}

# --- 定位 Windows 导出模板（标准 Godot 模板目录）---
$appData = [System.Environment]::GetFolderPath("ApplicationData")
$templatesRoot = Join-Path $appData "Godot\templates"
$winTpl = $null
if (Test-Path $templatesRoot) {
    $verDirs = Get-ChildItem $templatesRoot -Directory | Where-Object { $_.Name -like "4.7*" }
    foreach ($d in $verDirs) {
        $cand = Join-Path $d.FullName "windows_release_x86_64.exe"
        if (Test-Path $cand) { $winTpl = $cand; break }
    }
}
if (-not $winTpl) {
    Write-Host "[Aetherfall] 未找到 Windows 导出模板（windows_release_x86_64.exe）。" -ForegroundColor Red
    Write-Host "请先安装 Godot 4.7-stable 导出模板：" -ForegroundColor Yellow
    Write-Host "  1) 下载：https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz" -ForegroundColor Yellow
    Write-Host "  2) 解包后将内部 templates/ 目录内容放到：$templatesRoot\4.7.stable.official.5b4e0cb0f\" -ForegroundColor Yellow
    exit 2
}
Write-Host "[Aetherfall] 使用导出模板：$winTpl" -ForegroundColor Cyan

# --- 执行发布导出 ---
$buildDir = Join-Path $proj "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$outExe = Join-Path $buildDir "Aetherfall.exe"
Write-Host "[Aetherfall] 导出 Windows 构建 -> $outExe" -ForegroundColor Cyan
& $godot --headless --path $proj --export-release "Windows Desktop" $outExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "导出失败（exit $LASTEXITCODE）。"
    exit $LASTEXITCODE
}
Write-Host "[Aetherfall] 构建完成：双击 $outExe 即可游玩（无需引擎二进制）。" -ForegroundColor Green
