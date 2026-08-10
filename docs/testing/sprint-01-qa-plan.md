# Sprint 1 QA 计划 · Aetherfall

> 配套文档：`docs/testing/test-plan.md`（母本）、`production/sprint-01-plan.md`（16 Story）、
> `production/epics/epic-s0-foundation.md`、`production/epics/epic-s3-resonance.md`。
> 本计划为 Sprint 1（S0 地基 + S3 共鸣池垂直切片）专属 QA 展开。

## 1. 范围

**测什么**
- S0 地基：8 个 Autoload 单例（GameConstants / EventBus / ResonancePool / SaveManager /
  InputManager / AudioDirector / EchoDirector / DebugOverlay）能无报错加载。
- S3 共鸣池垂直切片：`game/scenes/sprint1_resonance_slice.tscn` 可加载并跑通核心循环。
- 三套自动化测试：`test_constants_match_gdd.gd`（CI 承重墙）、`test_resonance_pool.gd`
  （含 AC-S3-03 硬成功线）、`test_event_bus_signals.gd`（27 信号契约）。
- SPIKE-1 / SPIKE-2 脚手架场景可打开。

**不测什么**（后续 Sprint）
- 战斗/移动 FSM（S1/S2）、敌人 AI（S4）、世界/神龛（S5）、UX/HUD（S6）、叙事（S7）、
  元进度（S8）、美术资产、音频实际发声。

## 2. 测试分层

### 2.1 自动化单测（gdUnit4，落 `game/test/`）

| 测试文件 | 对应 AC / 契约 | 断言点 |
|---|---|---|
| `test_constants_match_gdd.gd` | 架构承重墙 | `RESONANCE_MAX=100` `RESONANCE_INITIAL=50` `GATE_COST=30` `FINISHER_COST=40` `CANCEL_WINDOW=8` `PARRY_WINDOW=6` `DASH_IFRAMES=10` `PARRY_SLOWMO_FRAMES=18` `PARRY_SLOWMO_SCALE=0.3` `RESONANCE_TIDE_PERIOD_FRAMES_DEFAULT=6300` `LATENCY_BUDGET_KBM_MS=50` `LATENCY_BUDGET_GAMEPAD_MS=80`；`FINISHER_USES_SLOWMO=false`（AUD-1 焊死） |
| `test_resonance_pool.gd` | AC-S3-01..04 | 上限钳制 / 五增益 / **AC-S3-03 池=35 可开门不可终结技** / 节点 cd / 脱战回充 |
| `test_event_bus_signals.gd` | architecture §5.2 | EventBus 含且**仅含** 27 条信号，名字逐一核对 |

### 2.2 集成 / 场景测试
- 垂直切片场景加载即证明核心循环可玩：命中 +1 → 节点 +10(cd) → 池≥30 开门 → 池≥40 终结技（互斥）。
- SPIKE-1：240fps tick 计数测输入→响应延迟。
- SPIKE-2：空跑 + 最小负载采样 FPS/帧时间/draw call。

### 2.3 手动验收（3 条，MANUAL）
| 编号 | 步骤 | 判据 |
|---|---|---|
| M1 | Godot 打开 `sprint1_resonance_slice.tscn`，运行 | HUD 显示 `Resonance: 50/100`，无报错 |
| M2 | 触发开门（池≥30）→ 触发终结技（池≥40） | 开门扣 30、终结技扣 40；池不足时对应动作被拒且有反馈 |
| M3 | 踩共鸣节点两次（间隔 <5s） | 第二次不二次增益；间隔 >5s 后可再触发 |

## 3. S0 退出门（8 项核对）

| # | 退出条件 | 满足证据 |
|---|---|---|
| 1 | 8 单例无报错加载 | `project.godot` [autoload] ×8 注册；Godot 打开工程无脚本错误 |
| 2 | GameConstants 单一真相源 | `test_constants_match_gdd.gd` 绿 |
| 3 | EventBus 27 信号契约 | `test_event_bus_signals.gd` 绿 |
| 4 | 共鸣池互斥成立 | `test_resonance_pool.gd` AC-S3-03 绿 |
| 5 | 无 hex 字面量硬编码 | `tools/lint/lint_hex_literals.gd` 通过（架构 §9） |
| 6 | 无魔法数字漂移 | `tools/lint/lint_magic_numbers.gd` 通过 |
| 7 | 垂直切片可加载 | M1 手动验收通过 |
| 8 | SPIKE 场景可打开 | SPIKE-1/2 场景在编辑器打开无错 |

## 4. 烟雾测试（Smoke Test）清单

| 序号 | 验证 | 自动/手动 | 备注 |
|---|---|---|---|
| S1 | 工程可打开 | 手动 | 待 Godot 安装 |
| S2 | 单例无报错 | 自动 | gdUnit4 Run All |
| S3 | 共鸣加/扣/互斥 | 自动 | test_resonance_pool |
| S4 | 场景加载 | 手动 | M1 |
| S5 | SPIKE 场景打开 | 手动 | SPIKE-1/2 |

## 5. 性能门

| 指标 | 预算（architecture §7.3） | 记录模板 |
|---|---|---|
| FPS | ≥60 | ___ |
| 帧时间 | ≤16.67ms | ___ |
| CPU | ≤9.0ms | ___ |
| GPU | ≤15.0ms | ___ |
| draw call | ≤1500 | ___ |
| 三角面 | ≤2M | ___ |
| 粒子 | ≤30k | ___ |
| 输入延迟 KBM | ≤50ms（SPIKE-1） | ___ |
| 输入延迟 手柄 | ≤80ms（SPIKE-1） | ___ |

## 6. 风险与阻塞

### ⚠ 最大阻塞：本机无 Godot 4 引擎
开发机未安装 Godot 4.7.1-stable，且 gdUnit4 插件未完整落地（见
`game/addons/gdUnit4/README_SETUP.md`）。所有**运行型**测试/场景无法在本机执行。

**降级门禁（无引擎时的替代验证）**——Sprint 1 收尾可据此判 PASS/CONCERN：
1. ✅ 代码静态审查：所有文件真实落盘、非零字节、类名/常量名/信号名与架构一致。
2. ✅ 测试文件存在性：3 套测试 + 场景文件齐备，语法可审阅。
3. ✅ 一致性 grep 断言：`project.godot` 8 autoload 注册；AC-S3-03 断言存在；27 信号名单。
4. ❌ 实际运行 / CI 绿：需用户侧安装 Godot 4.7.1 + gdUnit4 v6.2.x 后闭环。

## 7. 质量门判定标准

- **PASS**：降级门禁 1–3 全绿 + 用户侧安装引擎后 CI 全绿。
- **CONCERN**：降级门禁 1–3 全绿，但引擎未安装导致运行型验证缺失（Sprint 1 当前状态）。
- **FAIL**：关键文件缺失、AC-S3-03 逻辑错误或常量与 GDD 不一致。

> Sprint 1 当前判定：**CONCERN** —— 工程结构/测试/场景已真实补齐且静态自洽，
> 仅因缺 Godot 引擎无法运行验证。属环境阻塞，非设计/实现缺陷。
