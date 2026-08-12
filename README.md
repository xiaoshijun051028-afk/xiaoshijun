# 星陨之境 · Aetherfall

> 单人 3D 动作冒险（stylized）。支柱 P4「共鸣统一」：单一共享共鸣池同时驱动解谜（开门）
> 与战斗（终结技），且天然互斥。本仓库当前处于 **Phase 5 Sprint 1**：S0 地基 + S3 共鸣池
> 垂直切片（证明 P4 在架构层成立）。

## 引擎（单一声明，请勿在多处硬编码版本）

- **Godot `4.7.1-stable`（标准构建，非 .NET）** — 见 `project.godot` 与 CI `GODOT_VERSION`。
- 语言：**GDScript**（零 C#）；物理：**Jolt**（4.6 起 3D 默认）。
- 测试框架：**gdUnit4 v6.2.x**（支持 4.7.1；v6.1.x 仅到 4.6.3）。

## 目录结构

```
project.godot            引擎配置（autoload 顺序、物理/渲染）
game/
  autoload/               8 个全局单例（GameConstants/EventBus/ResonancePool/...）
  src/                    纯逻辑（core/combat/movement/ai/world/meta/ui）
  scenes/                 节点接线（boot/player/ui/...）
  resources/              数据驱动 .tres（constants/colors/env）
  tools/                  lint / spike 脚本
  addons/gdUnit4/         测试框架（git submodule）
tests/                    unit/ integration/ fixtures/（gdUnit4 测试）
docs/                     架构、ADR、测试计划
design/                   GDD、UX、美术、音频、色板
production/              Epic / Sprint 计划
```

## 快速开始

```bash
# 1. 安装 Godot 4.7.1-stable（标准构建）
# 2. 拉取 gdUnit4 子模块（首次需网络）
git submodule update --init --recursive
# 3. 编辑器打开本目录，Project Settings → Plugins → 启用 gdUnit4
# 4. 运行测试
godot --headless -s game/addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/
# 5. 静态检查
gdlint game/src game/autoload
godot --headless -s game/tools/lint/lint_hex_literals.gd
```

## 发布（Release）— 一键独立 exe

仓库自带 `release.ps1`：把当前代码导出为**单文件自包含**的 Windows 独立 exe（Embed Pck，无需附带 `.pck`）并部署到桌面，可选提交 + 推送。

**前置**：Godot 4.7-stable 二进制。脚本按以下顺序查找：环境变量 `GODOT` → `tools/godot/Godot_v4.7-stable_win64.exe` → `../tools/godot/...`。

```powershell
# 仅出包 + 放桌面（不提交）
powershell -ExecutionPolicy Bypass -File release.ps1

# 出包 + 提交 + 推送（显式 -Push 才推送，防误发）
powershell -ExecutionPolicy Bypass -File release.ps1 -Push
powershell -ExecutionPolicy Bypass -File release.ps1 -Push -Message "feat: ..."
```

**流水线（任一冒烟测试失败立即中止，绝不发布坏包）：**
1. 冒烟测试质量门：须 `test_mecha_placeholder.tscn` 与 `test_arena_wave_smoke.tscn` 均输出 `TEST_FINISHED_OK`
2. 重导独立 exe：`--export-release "Windows Desktop" build/Aetherfall.exe`
3. 自包含校验：把 exe 单独放进无 `.pck` 的临时目录 headless 启动，须 `EXIT=0`
4. 部署：`build/Aetherfall.exe` → `~/Desktop/Aetherfall.exe`
5. （`-Push`）`git add -A` + commit + `git push origin master`

产物：`build/Aetherfall.exe`（单文件，约 111MB）；桌面副本 `Desktop/Aetherfall.exe` 即玩家双击入口。

> 注：本环境 PowerShell 工具直接 `& release.ps1` 偶发不执行主体，可改在 Bash 内用 godot 二进制 + git 逐步跑等效步骤（逻辑与脚本一致）。

## ⚠ 执行缺口（Sprint 1 已知，待补）

本仓库源码与测试**可审阅但本地未实跑**，原因：

1. **本机未安装 Godot 4 引擎**（无 `godot` on PATH、无 config 目录）。
   所有 `.gd` / gdUnit4 测试需安装 Godot 4.7.1-stable + 真实运行 CI 才能验证。
   代码均按架构文档与 gdUnit4 v6 API 撰写，未运行前已做人工审阅，但**未经本地编译/执行**。
2. **`game/addons/gdUnit4` 子模块为空**（仅 `.git` 元数据，无 `plugin.cfg`/源码）。
   需 `git submodule update --init --recursive`（联网）拉取 v6.2.x，否则编辑器/CI 无法启用测试框架。
3. **场景（`.tscn`）尚未创建**：`Boot.tscn` / `Player.tscn` / `CameraRig` 属于 ENG-S0-06，
   当前仅落地了纯逻辑（`state.gd` / `state_machine.gd`）。`test_cancel_window` 等集成测试
   依赖场景，待场景补齐后运行。
4. **`game/resources/*` 的 `.tres` 尚未落盘**（颜色/常量/环境），ENG-S0-07 范围。

> 工程纪律（先写测试、常量单一真相源、ResonancePool 无 setter、整数帧计时）已全部就位为代码与测试，
> 待引擎就位即可在 CI 跑通。详见 `docs/architecture/` 与 `production/sprint-01-plan.md`。

## 质量门（Sprint 1 退出标准，见 sprint-01-plan §4）

- CI 全绿；`test_constants_match_gdd` 通过。
- S3 四条单测（AC-S3-01..04）全绿 —— **AC-S3-03（池=35 开门可·终结技不可）是 P4 唯一硬证据**。
- `test_cancel_window` 第 8 帧可取消 / 第 9 帧不可。
- 垂直切片可玩：节点共鸣 +10（cd 5s）→ 池≥40 放终结技扣 40 → HUD 三态正确。
