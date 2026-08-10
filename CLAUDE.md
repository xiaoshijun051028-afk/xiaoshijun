# CLAUDE.md · 工程编码标准（路径作用域）

> 星陨之境 Aetherfall · Godot 4.7.1-stable（标准构建，非 .NET）· GDScript
> 依据：`docs/architecture/architecture.md` §10.2 / `docs/architecture/control-checklist.md` §M
> 本文件是 AI 协作与人工提交的编码纪律入口；与架构文档冲突时以架构文档为准。

## 0. 全局铁律（不可协商）

- **全项目强制静态类型**：所有 `.gd` 一律标注类型（`var hp: int`、`func f(x: float) -> void`）。
- **`_process` 内禁止修改游戏状态或被插值节点的 transform**（architecture §3.2 / §7.4）。渲染插值依赖物理 tick 已是过去值，改它会产生抖动。
- **注释解释「为什么」而非「做什么」**。
- **signal 过去式命名**（只陈述已发生的事实，不用于请求动作）；要改状态一律调权威者方法（如 `ResonancePool.try_spend()`）。

## 1. 单一真相源

- 所有玩法常量来自 `GameConstants`（autoload #1），语义色来自 `ColorTokens`。**禁止**任何硬编码玩法数值或 hex 颜色字面量（由 `tools/lint/lint_hex_literals.gd` 拦截）。
- 改常量流程：**先改 GDD（systems-index.md §2）→ 改 `game_constants.gd` → 同步 `resources/constants/game_constants.tres`**。`tests/unit/test_constants_match_gdd.gd` 是承重墙，漂移即红。

## 2. 路径作用域规则

| 路径 | 规则 |
|---|---|
| `game/src/core/**` | **热路径零分配**：`_physics_process` 内禁新建 `Array`/`Dictionary`/`String`；预分配复用；禁 `find_child`（O(n) 遍历）。 |
| `game/src/combat/**`, `game/src/movement/**` | **数据驱动**：数值一律来自 `.tres` 或 `GameConstants`；**代码内禁止玩法数值字面量**（除 0/1/-1）。 |
| `game/src/ai/**` | **可调试**：每次状态迁移写入环形日志缓冲，`DebugOverlay` 可视化当前 state + telegraph 剩余帧。 |
| `game/src/ui/**`, `game/scenes/ui/**` | **不持有游戏状态**：只读订阅 EventBus；禁止 UI 直接改玩法状态；禁止 UI 调 `ResonancePool.add()`。 |
| `game/scenes/**` | 禁跨场景 `preload` 兄弟场景；禁 `get_node("../..")` 长路径；跨层引用用 `@export var target: Node` 或唯一名 `%Node`。 |
| 全局 | 强制静态类型；`class_name` 唯一；signal 过去式；注释讲「为什么」。 |

## 3. 时间基准（最高优先级横切决策）

- **物理 tick 60Hz ≡ GDD 1 帧**。一切玩法逻辑跑 `_physics_process`，整数帧计时（`var frames_left: int`），**不用 `float` 累加秒**。
- `CANCEL_WINDOW=8` / `PARRY_WINDOW=6` / `DASH_IFRAMES=10` 是字面意义的整数 tick。
- `physics_interpolation=true`：相机在 `_process` 读插值后 `global_position`，不放 `_physics_process`。

## 4. 共鸣池（P4 支柱的架构强制）

- `ResonancePool._current` 私有、**无 setter**；唯一入口 `try_spend(cost, reason)` / `add(amount, source)`。
- 任何绕过入口改 `_current` 的写法在评审打回——那等于拆掉 P4 支柱。
- 存档只存当前值，不存任何 `GameConstants` 常量（`test_save_no_constants` 守卫）。

## 5. 测试纪律

- **先写测试**：每个 Story 实现前先落断言（GDD §⑦ 每个复选框须指向一个测试文件）。
- 帧级测试一律 `runner.simulate_frames(n)`，禁 `await` 真实时间（确定性、不 flaky）。
- 每个 `*_test.gd` 的 `before_test()` 调 `ResonancePool.reset_for_test()` 隔离全局态。
- 工具：gdUnit4 v6.2.x（`game/addons/gdUnit4`）；CI 中 `--import` 必须先于测试。

## 6. 提交 / 分支

- `main` 恒可运行；Story 级改动走 `feat/<story-id>` 分支 + PR。
- **移动/重命名资源必须在 Godot 编辑器内操作**，不要用文件管理器（保 UID 不断引用）。
- 不提交 `.godot/`、导出产物、`*.tmp`、本地存档（见 `.gitignore`）。
