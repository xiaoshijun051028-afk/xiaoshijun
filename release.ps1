# ============================================================
#  星陨之境 / Aetherfall — 一键发布脚本
#  流程：冒烟测试 → 重导独立 exe → 自包含校验 → 放桌面 → (可选) commit + push
#  用法（PowerShell，从项目根目录运行）：
#    powershell -ExecutionPolicy Bypass -File release.ps1            # 出包 + 放桌面（不提交）
#    powershell -ExecutionPolicy Bypass -File release.ps1 -Push     # 上述 + git commit + push
#    powershell -ExecutionPolicy Bypass -File release.ps1 -Push -Message "feat: ..."
#  说明：
#    - 默认不 push（push 属高影响动作，需显式 -Push 人工触发）。
#    - 冒烟测试作为质量门：任一失败立即中止，绝不发布坏包。
#    - 仅依赖 Godot 4.7-stable 二进制与 git，无需其他工具。
# ============================================================
param(
    [switch]$Push = $false,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Find-Godot {
    $cands = @()
    if ($env:GODOT) { $cands += $env:GODOT }
    $cands += Join-Path $proj "tools\godot\Godot_v4.7-stable_win64.exe"
    $cands += Join-Path $proj "..\tools\godot\Godot_v4.7-stable_win64.exe"
    $cands += Join-Path $proj "Godot_v4.7-stable_win64.exe"
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    return $null
}

function Invoke-Godot {
    param([string[]]$Args)
    $out = & $godot @Args 2>&1 | Out-String
    return @{ exit = $LASTEXITCODE; out = $out }
}

# --- 1. 定位 Godot ---
$godot = Find-Godot
if (-not $godot) {
    Write-Error "未找到 Godot 二进制。请设置环境变量 GODOT 指向 Godot_v4.7-stable_win64.exe。"
    exit 1
}
Write-Host "[release] Godot: $godot" -ForegroundColor Cyan

# --- 2. 冒烟测试（质量门）---
Write-Host "[release] 重建类名缓存..." -ForegroundColor Cyan
$null = Invoke-Godot @("--headless", "--path", $proj, "--import")

$tests = @("res://test_mecha_placeholder.tscn", "res://test_arena_wave_smoke.tscn")
foreach ($t in $tests) {
    Write-Host "[release] 冒烟测试: $t" -ForegroundColor Cyan
    $r = Invoke-Godot @("--headless", "--path", $proj, $t)
    if ($r.exit -ne 0 -or $r.out -notmatch "TEST_FINISHED_OK") {
        Write-Host "---------- 失败输出 ----------" -ForegroundColor Red
        Write-Host $r.out -ForegroundColor Red
        Write-Error "冒烟测试未通过 ($t)，发布中止。请先修复再发布。"
        exit 3
    }
    Write-Host "  OK (TEST_FINISHED_OK)" -ForegroundColor Green
}

# --- 3. 重导独立 exe ---
$buildDir = Join-Path $proj "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$outExe = Join-Path $buildDir "Aetherfall.exe"
Write-Host "[release] 导出 Windows 构建 -> $outExe" -ForegroundColor Cyan
$r = Invoke-Godot @("--headless", "--path", $proj, "--export-release", "Windows Desktop", $outExe)
if ($r.exit -ne 0) {
    Write-Host $r.out -ForegroundColor Red
    Write-Error "导出失败（exit $($r.exit)）。"
    exit $r.exit
}

# --- 4. 自包含校验（剥离 pck 单独跑）---
Write-Host "[release] 自包含校验（临时目录无 pck 启动）..." -ForegroundColor Cyan
$tmp = Join-Path $env:TEMP ("aether_verify_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Copy-Item $outExe (Join-Path $tmp "Aetherfall.exe") | Out-Null
$tmpExe = Join-Path $tmp "Aetherfall.exe"
& $tmpExe --headless --quit-after 8 2>&1 | Out-Null
$selfExit = $LASTEXITCODE
try { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue } catch { }
if ($selfExit -ne 0) {
    Write-Error "自包含校验失败（exit $selfExit）：exe 无法脱离 pck 自启动。"
    exit 4
}
Write-Host "  OK (自包含 EXIT=0)" -ForegroundColor Green

# --- 5. 放桌面 ---
$desktop = Join-Path $env:USERPROFILE "Desktop"
$dest = Join-Path $desktop "Aetherfall.exe"
Copy-Item $outExe $dest -Force
Write-Host "[release] 已部署到桌面: $dest" -ForegroundColor Green

# --- 6. 可选 commit + push ---
if ($Push) {
    Write-Host "[release] 暂存改动..." -ForegroundColor Cyan
    git -C $proj add -A
    $st = (git -C $proj status --porcelain)
    if ([string]::IsNullOrWhiteSpace($st)) {
        Write-Host "[release] 无待提交改动，跳过 commit。" -ForegroundColor Yellow
    } else {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $Message = "chore(release): 重导独立 exe（Embed Pck）+ 部署桌面 " + (Get-Date -Format "yyyy-MM-dd HH:mm")
        }
        git -C $proj commit -q -m $Message
        Write-Host "[release] 已提交: $Message" -ForegroundColor Green
        Write-Host "[release] 推送到 origin/master..." -ForegroundColor Cyan
        git -C $proj push origin master 2>&1 | Out-String | ForEach-Object { Write-Host $_ }
        Write-Host "[release] 推送完成。" -ForegroundColor Green
    }
}

Write-Host "" 
Write-Host "[release] 发布完成。双击桌面 Aetherfall.exe 即可游玩。" -ForegroundColor Green
