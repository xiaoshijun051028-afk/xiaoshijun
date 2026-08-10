# 主架构文档 · 星陨之境 (Aetherfall)

> 版本 v1.0 ｜ Phase 3 技术搭建 ｜ 作者 程基岩（engineering-lead）｜ 评审 Solo
> 引擎 **Godot 4.7.1 stable** ｜ 平台 PC / Steam（Windows 主，Linux/Proton 次）
> 上游事实依据：`design/concept/game-concept.md` v0.2、`design/art-bible.md` v0.1、`design/gdd/` 10 篇（**常量单一真相源 = `design/gdd/systems-index.md` §2**）
> 下游：Phase 4 预制作、Phase 5 制作的事实依据
> 配套：`adr-001..005.md`、`architecture-review.md`、`control-checklist.md`

---

## 0. 阅读约定

- 本文**不重新定义任何 GDD 数值**。所有玩法常量一律引用 `systems-index.md §2`，工程侧以**唯一一个** `GameConstants` 资源承载（见 §4.2）。若本文与 systems-index 冲突，**以 systems-index 为准**并回报主理人修订本文。
- 标注 `[ADR-00X]` 处表示该决策有独立决策记录，含备选方案与后果。
- 标注 `[GAP]` 处为知识缺口或待主理人拍板项，已汇总于 §12。

---

## 1. 引擎选型论证：Godot 4 为何胜任本项目

### 1.1 版本钉定

**钉定 `Godot 4.7.1-stable`（标准构建，非 .NET）** [ADR-001]。

截至 2026-08-08 的官方发布状态（已核验 godotengine.org 发布页与 release policy）：

| 分支 | 发布 | 支持级别 | 本项目取舍 |
|---|---|---|---|
| 4.8 (master) | Q4 2026 预计 | 开发中 | ✗ 不用于生产 |
| **4.7** | 2026-06-18（4.7.1 于 07-14） | **完整支持** | ✔ **钉定** |
| 4.6 | 2026-01-26 | 完整支持 | 备选（见 ADR-001 后果） |
| 4.5 | 2025-09-15 | 仅安全/平台修复 | ✗ |
| 4.4 及更早 | — | 已停止支持 | ✗ |

选 4.7 而非 4.6 的关键增量，**每一条都直接命中本项目需求**：

- **HDR 输出**（Windows/macOS/Linux-Wayland）：美术圣经 §3.3 要求 Glow 强化"星辉青/暖金能量感"且"阈值偏高避免发灰"——HDR 输出让高亮自发光在 HDR 显示器上真正拉开动态范围，而非靠 tonemap 压缩。
- **`AreaLight3D`（矩形面光源，新节点）**：美术圣经 §4.2 的 ResonanceMetal 自发光镶边、神龛/共鸣节点的柔性辉光，此前只能"自发光材质 + GI"近似；现在可直接用实时矩形面光，软阴影与反射更准，且**省掉一部分对 SDFGI 的依赖**（性能利好）。
- **键鼠设备 ID**（`InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`）：S6 GDD §⑥明确要求"双设备同时输入 → 最近输入设备优先"。4.7 之前键鼠事件无设备标识，需靠事件类型手工推断；4.7 可直接按设备 ID 判定活跃设备（见 §8.3）。
- **`Control` 的 `offset_transform_*` 属性**：S6 HUD 需要低血脉冲、共鸣满槽跳动等"juice"动画。此前 Container 重排会吃掉子节点 transform，必须加一层 Control 包装；4.7 的 offset transform 是自包含的、且默认纯视觉不影响鼠标命中，HUD 动画实现直接简化一层节点。
- **`tween_await()`**：S7 残响回声的"播放 → 等待 → 收束"时序编排可直接线性书写，不再靠嵌套回调。
- **逐 Pass 独立环境 uniform 缓冲**：渲染并行度提升，对我们多 Pass（SDFGI + 体积雾 + CompositorEffect）的堆叠是净收益。

4.7 于 2026-06 发布、已有 4.7.1 维护版（4.7.2-rc1 于 08-03），早期分支缺陷已过一轮收敛，进入 Phase 4 预制作时机合适。

### 1.2 Godot 4 胜任 3D stylized 的论证（能力 → 需求映射）

| 美术圣经要求 | Godot 4 原生能力 | 引入版本 | 判定 |
|---|---|---|---|
| 户外大世界实时 GI（浮岛弹跳光）§3.1 | **SDFGI**（Forward+） | 4.0 | ✔ 原生 |
| 封闭遗迹/洞窟 GI §3.1 | `VoxelGI` / 反射探针 | 4.0 | ✔ 原生 |
| 体积光束 god-rays、云海层雾 §3.1 | **VolumetricFog** + 指数 Fog + 高度雾 | 4.0 | ✔ 原生 |
| 全屏自定义特效（故障/径向模糊/色散）§3.3 §8 | **CompositorEffect** | **4.3** | ✔ 原生（版本充裕） |
| 共鸣光效、花粉光点、拖尾 §8 | **GPUParticles3D** + ShaderMaterial | 4.0 | ✔ 原生 |
| 程序化天幕 + 星陨流光 + 极光 §3.2 | 自定义 `Sky` Shader | 4.0 | ✔ 原生 |
| 全项目 Fresnel Rim「精美描边」§4.3 | ShaderMaterial + **模板缓冲(stencil)** | 4.5 | ✔ 原生（stencil 使外描边可靠） |
| ORM 贴图打包省采样 §4.3 | `BaseMaterial3D` ORM 通道 | 4.0 | ✔ 原生 |
| 克制的 SSR §8.1 | SSR **完全重写** + 半分辨率模式 | **4.6** | ✔ 原生（成本已显著下降） |
| 材质去色带（大面积渐变天空/雾） | 3D 材质 debanding | 4.6 | ✔ 原生 |
| UI 无障碍（屏幕阅读器）§9 | AccessKit 无障碍描述 / 地标导航 | 4.5 / 4.7 | ✔ 原生 |

**结论：美术圣经附录声称的"SDFGI / VolumetricFog / CompositorEffect / GPUParticles3D 均为 Godot 4 内置、PC·Steam 目标下性能充裕"经核验成立**，且 4.5–4.7 的 stencil、SSR 重写、HDR 输出、AreaLight3D 进一步扩大了余量。**全项目零非常规第三方依赖**（见 §11 依赖策略）。

### 1.3 为何 Godot 优于备选（简要）

- **vs Unity**：Solo 规模下，Godot 的场景/节点组合模型迭代更快；无运行时费用与许可政策风险；GDScript 热迭代（改脚本即时生效）对"手感靠反复试"的动作游戏是核心生产力。Unity 的 DOTS/HDRP 优势在本项目（单人、单场景规模有限）用不上。
- **vs Unreal 5**：UE5 的 Nanite/Lumen 面向写实高模，与本项目 **stylized + 干净大块明暗**（美术圣经 §4.3 明确"避免高频噪点法线"）方向相反；GAS 对单人 6 动词是过度工程；C++/Blueprint 双轨对 Solo 是负担；包体与构建时间显著更差。
- **决定性因素**：本项目瓶颈是**手感迭代速度**（P1 流动即正义，取消窗口靠反复调），不是渲染上限。Godot 的秒级迭代 > 引擎理论画质天花板。

详见 [ADR-001]。

### 1.4 渲染方法与语言

- **渲染方法：`Forward+`**。SDFGI / VolumetricFog / SSR / CompositorEffect 均要求 Forward+；Mobile 与 Compatibility 后端不支持 SDFGI。PC 独占目标下无妥协必要。
- **Windows 导出图形 API：D3D12**（4.6 起为 Windows 导出默认，驱动更稳）；Vulkan 作为启动项回退（`--rendering-driver vulkan`），用于排查驱动问题。
- **语言：GDScript 为主，零 C#**。理由：① 标准构建体积小、导出简单；② 热重载迭代快；③ 本项目无重 CPU 计算需求（见 §7.3 性能预算，玩法逻辑帧预算仅 4 ms）。若后期出现真实 CPU 瓶颈，走 **GDExtension**（GDScript 接口不变）而非全项目迁 C#。
- **静态类型强制**：所有 `.gd` 一律标注类型（`var hp: int`、`func f(x: float) -> void`）。GDScript 静态类型可显著减少运行时装箱与查表；同时是 lint 门禁项（§10.2）。

---

## 2. 项目目录与场景结构

### 2.1 顶层目录

```text
res://
├── project.godot
├── addons/
│   └── gdUnit4/                  # 测试框架（git submodule，见 §10.1）
├── autoloads/                    # 全局单例脚本（§4）
│   ├── event_bus.gd
│   ├── game_constants.gd
│   ├── resonance_pool.gd
│   ├── save_manager.gd
│   ├── input_manager.gd
│   ├── audio_director.gd
│   └── debug_overlay.gd
├── src/                          # 纯逻辑（尽量不依赖场景树，便于单测）
│   ├── core/                     # 帧计时、状态机基类、工具、RNG
│   ├── combat/                   # S1 动词、判定、伤害
│   ├── movement/                 # S2 轻重力、锚点求解
│   ├── ai/                       # S4 行为、telegraph 调度
│   ├── world/                    # S5 岛屿/闸门/神龛逻辑
│   ├── meta/                     # S8 存档模型、技能树
│   ├── narrative/                # S7 残响
│   └── ui/                       # S6 视图模型（不含节点）
├── scenes/
│   ├── boot/                     # Boot.tscn（唯一入口）、Loading
│   ├── player/                   # Player.tscn + 状态节点
│   ├── enemies/                  # Brute / Skirmisher / Sentinel / Boss
│   ├── world/                    # 岛屿场景、神龛、闸门、锚点、残响节点
│   ├── ui/                       # HUD、暂停、技能树、设置
│   └── vfx/                      # 粒子与特效预制
├── resources/                    # .tres 数据资产（数据驱动，§3.3）
│   ├── constants/                # game_constants.tres（唯一常量源）
│   ├── colors/                   # color_tokens.tres（语义色，§9）
│   ├── verbs/                    # 每个动词一个 VerbDefinition.tres
│   ├── enemies/                  # 每个敌人一个 EnemyDefinition.tres
│   ├── skills/                   # 技能树节点
│   └── echoes/                   # 残响条目
├── shaders/                      # .gdshader + CompositorEffect 脚本
├── art/                          # 美术源导入（林绘澄交付落点）
├── audio/
├── tests/
│   ├── unit/                     # 纯逻辑，无场景树
│   ├── integration/              # SceneRunner 帧级测试
│   └── fixtures/
└── tools/                        # 编辑器插件：关卡校验、可达性扫描
```

**`src/` 与 `scenes/` 分离的理由**：GDD 的可测试性条款（如 S3「池=35 时可开门不可终结技」、S1「闪 iframes 期间 0 伤害」）都是**纯逻辑断言**。把这些逻辑放在不依赖节点树的类里，单测可在毫秒级跑完、无需实例化场景，CI 才跑得动。场景只负责"把逻辑接到节点/视觉上"。

### 2.2 场景树运行时形态

```text
Boot (唯一 main scene)
└── /root
    ├── [Autoloads]  EventBus, GameConstants, ResonancePool, SaveManager,
    │                InputManager, AudioDirector, DebugOverlay
    └── Main
        ├── WorldRoot          # 当前岛屿场景挂载点（异步换场）
        │   └── Island_Hub.tscn
        │       ├── Geometry/          (静态网格, gi_mode=Static)
        │       ├── Anchors/           (S2 锚点 Area3D)
        │       ├── Gates/             (S3 闸门)
        │       ├── Shrines/           (S8 神龛)
        │       ├── EchoNodes/         (S7 残响)
        │       ├── EnemySpawns/
        │       └── WorldEnvironment + DirectionalLight3D
        ├── PlayerRoot
        │   └── Player.tscn
        ├── CameraRig          # 独立于 Player，_process 内插值跟随（§7.4）
        └── UILayer (CanvasLayer)
            ├── HUD.tscn
            └── MenuStack
```

**关键：`CameraRig` 与 `Player` 解耦并挂在 Main 下**。相机在 `_process` 读取玩家的**插值后**位置（物理插值开启时 `global_position` 在渲染帧返回插值值），而非在 `_physics_process` 硬跟随——这是 144 Hz 显示器上消除抖动的必要条件（§7.4）。

### 2.3 场景职责纪律

- **一个场景 = 一个可独立运行的单元**。`Player.tscn` 单独运行不崩（缺世界时用 fallback 地面）；`Island_*.tscn` 单独运行可加载（Autoload 提供全局态）。这让"改一个岛不用跑全流程"，是 Solo 迭代速度的关键。
- **场景不互相 `preload` 兄弟场景**。跨场景引用一律经 `EventBus` 或由 `Main` 注入，避免循环依赖与加载爆炸。
- **`@export` 优先于硬编码路径**。禁止 `get_node("../../../Foo")` 这类脆弱路径；跨层引用用 `@export var target: Node` 或唯一名 `%Node`。

---

## 3. 时间基准：把 GDD 的"帧"变成工程契约

这是本架构**最高优先级的横切决策**，因为 GDD 的三个核心手感常量全部以帧计：`CANCEL_WINDOW=8f`、`PARRY_WINDOW=6f`、`DASH_IFRAMES=10f`。

### 3.1 问题

PC 玩家显示器刷新率从 60 Hz 到 240 Hz 不等，且可关垂直同步。若把这些窗口写在 `_process(delta)` 里按秒累加，**144 Hz 玩家与 60 Hz 玩家的取消窗口宽度会出现实测差异**（浮点累加误差 + 输入采样点不同），直接摧毁 P1「流动即正义」的可验证性——GDD S1 的验收标准「测量任意两动词间取消延迟 ≤ 8 帧」将无法稳定通过。

### 3.2 决定

1. **`physics/common/physics_ticks_per_second = 60`（固定，不可玩家修改）**。
2. **一切玩法逻辑跑在 `_physics_process`**：输入消费、FSM 推进、命中判定、AI 决策、共鸣池增减。于是 **1 物理 tick ≡ GDD 的 1 帧**，`CANCEL_WINDOW=8f` 就是字面意义的 8 次 tick，无需换算、无浮点漂移。
3. **开启 `physics/common/physics_interpolation = true`**（Godot 4.3 起 2D/3D 均原生支持）。渲染帧在物理 tick 之间插值，144 Hz 下画面依然顺滑，而**模拟本身完全不变**（插值是纯视觉的）。
4. **`_process` 只做表现**：相机、HUD 补间、VFX、音频包络。**禁止在 `_process` 里修改任何游戏状态或被插值节点的 transform**（会导致插值计算错误并产生抖动）。
5. **传送/复活/换场后必须调用 `reset_physics_interpolation()`**（神龛复活、越界重生、Boss 阶段位移），否则会出现一帧拉丝。
6. **帧计数用整数**：窗口倒计时一律 `var cancel_frames_left: int`，每 tick `-= 1`，**不用 `float` 累加秒数**。

### 3.3 后果

- ✔ GDD 帧常量成为**可直接断言的整数**，测试能精确验证（gdUnit4 SceneRunner 支持逐帧 `simulate_frames()`，见 §10.1）。
- ✔ 全平台/全刷新率手感一致，`DASH_IFRAMES` 不会因硬件而变宽变窄。
- ✔ 高刷显示器上 CPU 反而更省（玩法逻辑不再每渲染帧跑）。
- ⚠ 60 Hz 固定 tick 引入最多 ~16.7 ms 的输入-模拟延迟；叠加物理插值会再增一点视觉延迟。S6 要求「输入延迟 <50ms 键鼠」——预算仍然够（见 §7.5 延迟账），但**必须在 Phase 4 用高速摄像实测**，列为控制清单项。
- ⚠ 团队纪律成本：任何人误在 `_process` 里推进状态都会破坏一致性。已写入编码标准与 lint 检查（§10.2）。

> **备选被否**：可变时间步 + 按秒定义窗口（拒绝：破坏帧常量可验证性）；提高 tick 到 120 Hz 降延迟（拒绝：GDD 帧常量以 60 fps 为基准定义，改 tick 就要重算全部常量，违反单一真相源；且 CPU 翻倍）。

---

## 4. 核心系统 → Godot 实现映射

### 4.1 映射总表

| 系统 | 实现形态 | 理由 |
|---|---|---|
| **GameConstants** | Autoload + `Resource` | 常量单一真相源，零逻辑 |
| **EventBus** | Autoload（纯 signal 容器） | 解耦跨系统广播 |
| **S3 共鸣池** | **Autoload 单例** `ResonancePool` | 全局唯一、被 S1/S5/S6/S7/S8 共享 [ADR-002] |
| **S8 存档** | **Autoload** `SaveManager` | 跨场景生命周期、需原子写盘 [ADR-004] |
| **输入** | **Autoload** `InputManager` | 设备切换、重映射、输入缓冲 |
| **音频** | **Autoload** `AudioDirector` | 总线管理、共鸣潮汐音乐层 |
| **S1 战斗** | **Scene + 节点化 FSM** | 每玩家/敌人一份实例状态 [ADR-003] |
| **S2 移动** | `CharacterBody3D` + 手动积分 | 确定性优先，不用刚体 [ADR-005] |
| **S4 敌人 AI** | Scene + 同一 FSM 基类 + `EnemyDefinition.tres` | 数据驱动 3 原型 + Boss |
| **S5 世界** | Scene（每岛一 `.tscn`）+ 组(group)查询 | 关卡即数据 |
| **S6 HUD** | `CanvasLayer` + Control，**订阅 EventBus** | UI 不持有游戏状态 |
| **S7 叙事** | 轻量 Autoload `EchoDirector` + `EchoEntry.tres` | 需跨场景记录收集 |

### 4.2 `GameConstants`：单一真相源的工程落点

```gdscript
# autoloads/game_constants.gd  (Autoload 名: GameConstants)
extends Node

## 唯一常量源。所有数值来自 design/gdd/systems-index.md §2。
## 禁止在任何其他文件硬编码这些值。改动必须先改 GDD，再改此处。
const SOURCE_OF_TRUTH := "design/gdd/systems-index.md#2"

# --- 帧基准（60 fps，1 物理 tick = 1 帧）---
const TICKS_PER_SECOND   : int = 60
const CANCEL_WINDOW      : int = 8    # 帧 ≈133ms
const PARRY_WINDOW       : int = 6    # 帧 ≈100ms
const DASH_IFRAMES       : int = 10   # 帧 ≈167ms

# --- 共鸣池 ---
const RESONANCE_MAX      : int = 100
const RESONANCE_INITIAL  : int = 50
const GATE_COST          : int = 30
const FINISHER_COST      : int = 40
const GAIN_HIT           : int = 1
const GAIN_PERFECT_PARRY : int = 5
const GAIN_KILL          : int = 15
const GAIN_NODE          : int = 10
const GAIN_OUT_OF_COMBAT_PER_SEC : int = 2
const NODE_COOLDOWN_SEC  : float = 5.0
const OUT_OF_COMBAT_SEC  : float = 3.0

# --- 技能树下限（S8）---
const CANCEL_WINDOW_MIN  : int = 5    # 技能树最多减 3 帧
```

**纪律**：`tests/unit/test_constants_match_gdd.gd` 会硬断言这些值。任何人改动而未同步 GDD，CI 立即红灯——这是把"文档一致性"变成"可执行门禁"的手段。

### 4.3 Autoload 清单与顺序

Autoload 按依赖顺序注册（Godot 按 project.godot 中顺序初始化）：

| # | 名称 | 依赖 | 职责 | 禁止 |
|---|---|---|---|---|
| 1 | `GameConstants` | — | 常量 | 任何逻辑 |
| 2 | `EventBus` | — | signal 容器 | 任何状态 |
| 3 | `ResonancePool` | 1,2 | S3 池权威 | 直接改 UI |
| 4 | `SaveManager` | 1,2,3 | 序列化/写盘 | 游戏逻辑 |
| 5 | `InputManager` | 1,2 | 设备/重映射/缓冲 | 游戏逻辑 |
| 6 | `AudioDirector` | **2,3** | 总线/音乐层 | — |
| 7 | `EchoDirector` | 2,4 | S7 残响收集 | — |
| 8 | `DebugOverlay` | 全部 | 调试面板 | 发布构建启用 |

> **AudioDirector 依赖为 `2,3` 的理由（AUD-3，2026-08-10 修订，原为 `2`）**：共鸣三态听觉化（`AUD_RES_BED_L0` / `L1_READY` / `L2_FULL`，见 `design/audio/audio-event-list.md` §2.4）要求 `AudioDirector` 在 `_ready()` 内以 **L3 权威查询**读取 `ResonancePool.current`，把共鸣床层在**冷启动即对齐到当前池值**（与 §4.6 HUD 的冷启动对齐同理）。否则读档进入时池值为 50，音频却从静音爬升，等于对玩家谎报"共鸣为 0"——这条床层是 HUD 共鸣条的可访问性替代通道，不能失真。
> **无循环风险**：`ResonancePool`(3) 早于 `AudioDirector`(6) 初始化；且 `ResonancePool` 不反向依赖 `AudioDirector`（它只 `emit resonance_changed`，不知道谁在听，见 §5.1 L2 规则）。依赖方向仍是严格单向的 6 → 3。

**Autoload 准入红线（防单例泛滥）**：只有同时满足①全局唯一、②跨场景存活、③被 ≥3 个系统消费 的才准入。`DebugOverlay` 在 release 导出中通过 feature tag 剥离。

### 4.4 战斗 FSM（S1/S4 共用）

采用**节点化 FSM**：`StateMachine` 节点 + 每个状态一个子节点脚本 [ADR-003]。

```text
Player.tscn
├── CharacterBody3D (root)
├── StateMachine            (Node)     # 持有 current_state、frame 计时
│   ├── Idle                (Node)
│   ├── Slash               (Node)     # 4 段连段由 combo:int 驱动
│   ├── Dash                (Node)     # 进入时 set iframes = DASH_IFRAMES
│   ├── Grapple             (Node)
│   ├── Leap                (Node)
│   ├── Parry               (Node)     # armed 窗口 = PARRY_WINDOW
│   ├── Resonate            (Node)
│   └── Hitstun             (Node)     # 上限 0.5s 防卡死
├── Hurtbox / Hitbox        (Area3D)
├── Visual (Skeleton3D, AnimationTree)
└── ResonanceLink                      # 只读订阅 ResonancePool
```

**取消窗口的统一实现**（避免每个状态各写一遍）：

```gdscript
# src/core/state.gd —— 所有状态基类
class_name State extends Node

var frames_in_state: int = 0
## 该状态进入"可被取消"的起始帧（-1 = 不可取消）
@export var cancel_open_at_frame: int = -1

func physics_tick() -> void:
    frames_in_state += 1

## 是否处于取消窗内：从 cancel_open_at_frame 起，持续 CANCEL_WINDOW 帧
func is_cancellable() -> bool:
    if cancel_open_at_frame < 0:
        return false
    var elapsed := frames_in_state - cancel_open_at_frame
    return elapsed >= 0 and elapsed < GameConstants.CANCEL_WINDOW
```

取消窗只在**一处**实现，所有动词共享——直接兑现概念文档「6 动词共用一套取消/预警语言」，也让 S8 技能树改窗口（最低 5 帧）只需改一个读取点。

**输入优先级**（S1 §⑥「同时按 ≥3 键时 格 > 闪 > 斩」）在 `InputManager` 统一裁决后再交给 FSM，FSM 只消费"已裁决的单一意图"，避免每个状态重复实现优先级。

### 4.5 敌人 AI 复用同一 FSM

`Brute / Skirmisher / Sentinel / Boss` 共用 `StateMachine` 基类，状态集为 `Idle / Telegraph / Attack / Recover / Stagger / Dead`（与 GDD S4 §③ 完全一致）。差异全部外置到 `EnemyDefinition.tres`：

```gdscript
# src/ai/enemy_definition.gd
class_name EnemyDefinition extends Resource
@export var display_name: String
@export var max_hp: int                        # Brute 120 / Skirmisher 60 / Sentinel 80
@export var telegraph_frames_min: int          # 由秒→帧换算，见下
@export var telegraph_frames_max: int
@export var damage_min: int
@export var damage_max: int
@export var move_speed: float
@export var has_weakpoint: bool                # Sentinel = true, x2 倍率
@export var attack_patterns: Array[AttackPattern]
```

**telegraph 时长以帧存储**（Normal 0.6–1.2s → 36–72 帧；Hard 0.4–0.8s → 24–48 帧），与 §3 帧基准一致，避免秒/帧两套单位混用。`[GAP]` Hard 下限 24 帧对应 CONCERN-1，Phase 4 A/B 调参时**只改 .tres 不改代码**——这正是数据驱动的收益。

### 4.6 S6 HUD：不持有游戏状态

HUD 是**纯投影**：订阅 `EventBus` 信号 → 更新 Control。禁止 HUD 缓存"权威"数值或反向写入。

```gdscript
# scenes/ui/hud.gd
func _ready() -> void:
    EventBus.resonance_changed.connect(_on_resonance_changed)
    EventBus.player_hp_changed.connect(_on_hp_changed)
    EventBus.enemy_telegraph_started.connect(_on_threat)
    # 冷启动对齐：主动拉一次当前值，防止 HUD 显示 0
    _on_resonance_changed(ResonancePool.current, ResonancePool.current)

func _on_resonance_changed(new_value: int, _old: int) -> void:
    bar.value = new_value
    # 三态色（GDD S6 §⑤）——阈值来自 GameConstants，不硬编码
    if new_value >= GameConstants.FINISHER_COST:
        bar.modulate = ColorTokens.RESONANCE_GLOW   # 可终结技
    elif new_value >= GameConstants.GATE_COST:
        bar.modulate = ColorTokens.GATE_READY       # 可开门
    else:
        bar.modulate = ColorTokens.INACTIVE         # 灰
```

S6 §⑥「状态源断连 → 显示最后已知值 + `?`，不崩溃」由 HUD 侧的 `_source_stale: bool` 实现，不需要额外系统。

---

## 5. 数据流与事件总线策略

### 5.1 三层通信规则（何时用哪种）

Godot 的 signal 很容易被滥用成"全局广播面条"。本项目**强制三分法**：

| 层级 | 机制 | 使用场景 | 例 |
|---|---|---|---|
| **L1 局部** | 节点自身 `signal` + 直连 | 父子/兄弟节点，同一场景内 | `Hitbox.hit_landed` → 本机 FSM |
| **L2 系统级** | **`EventBus` 全局 signal** | 跨系统、发送方不该知道接收方 | 共鸣池变化 → HUD/VFX/音频 |
| **L3 权威查询** | 直接读 Autoload 属性 | 需要"当前值"而非"变化事件" | `ResonancePool.can_afford_finisher()` |

**红线**：L2 只广播**已发生的事实**（过去式命名：`resonance_changed`、`enemy_died`），**不用于请求动作**。要改状态一律调用权威者的方法（`ResonancePool.try_spend_finisher()`），不能靠发信号请求。这条规则杜绝了"两个监听者都以为对方会处理"的经典 bug。

### 5.2 EventBus 定义

```gdscript
# autoloads/event_bus.gd  (Autoload 名: EventBus)
extends Node
## 纯信号容器：无状态、无逻辑、无 _process。
## 命名一律过去式 —— 只陈述已发生的事实。

# --- S3 共鸣 ---
signal resonance_changed(new_value: int, old_value: int)
signal resonance_spend_rejected(cost: int, reason: String)
signal resonance_node_consumed(node_id: StringName)

# --- S1 战斗 ---
signal player_hp_changed(new_hp: int, old_hp: int)

## 玩家 FSM 进入新状态。唯一发出方 = StateMachine（ADR-003 §4 转移裁决第 5 步）。
## state_name 是**闭集**，取值必为下列 9 个之一，音频/VFX/HUD 可据此写死分派表：
##   &"Idle"  &"Slash"  &"SlashHeavy"  &"Dash"  &"Grapple"
##   &"Leap"  &"Parry"  &"Resonate"    &"Hitstun"
## 命名规则：PascalCase，`state_name == 状态节点的 node.name`，与 §4.4 / ADR-003 §1 的
## 节点树 1:1 对应。新增状态必须同时改这三处，否则视为破坏契约。
## 三条防误接线约定：
##   1) 斩的 4 段连段**不是 4 个状态**——只有一个 &"Slash"，段号走 combo_advanced(count)。
##      **不存在 &"Slash1".. &"Slash4"**（ADR-003 §1：「4 段连段由 combo:int 驱动，非 4 个状态」）。
##   2) 本信号**仅玩家**。敌人状态集（§4.5 Idle/Telegraph/Attack/Recover/Stagger/Dead）
##      不经此信号广播，一律走 enemy_* 系列。
##   3) S2 移动不另立状态机：movement.md §③ 的 grounded/airborne/grappling 是**标志位**，
##      闪/跃/荡本身已是上表内的动词状态。
signal player_state_entered(state_name: StringName)

signal combo_advanced(count: int)
signal perfect_parry_landed(target: Node3D)
signal finisher_executed(damage: int)
signal combat_state_changed(in_combat: bool)

# --- S4 敌人 ---
signal enemy_telegraph_started(enemy: Node3D, frames: int)
signal enemy_telegraph_cleared(enemy: Node3D)
signal enemy_staggered(enemy: Node3D, frames: int)
signal enemy_died(enemy: Node3D)
signal boss_phase_changed(phase: int)

# --- S5 世界 / S8 神龛 ---
signal gate_opened(gate_id: StringName)
signal shrine_activated(shrine_id: StringName)
signal player_respawned(shrine_id: StringName)
signal island_entered(island_id: StringName)

# --- S7 残响 ---
signal echo_triggered(echo_id: StringName)
signal echo_finished(echo_id: StringName)
signal echo_collected(echo_id: StringName, total: int)

# --- 系统 ---
signal save_completed(success: bool)
signal settings_changed(key: StringName)
signal game_paused()
signal game_resumed()

# --- 时间膨胀（慢动作 / hit-stop，见 §5.4）---
signal time_dilation_started(scale: float, duration_frames: int)
signal time_dilation_ended()
```

**新增 6 条信号的发出方 / 消费方契约（AUD 批次，2026-08-10）**

上游依据 `design/audio/audio-event-list.md` §3。6 条均为**过去式、无状态、无逻辑**，只陈述已发生的事实，满足 §5.1 的 L2 红线与「≥2 系统消费」的准入门槛（音频只是消费者之一，不为音频单独开信号）。

| 信号 | 唯一发出方 | 消费方（≥2） | 契约备注 |
|---|---|---|---|
| `time_dilation_started(scale, duration_frames)` | 战斗 FSM 中**实际写 `Engine.time_scale` 的那一处**（v1 = 完美格挡分支，`scale≈0.5`、`duration_frames=18`），与赋值**同帧**发出 | ① `AudioDirector`：`SFX`/`Ambience` 低通下潜 + `Music` duck ② `CameraRig`：降低跟随刚度、微推近 ③ Compositor 栈：去饱和 / 径向模糊强度 | `duration_frames` 是**名义**时长，仅供表现层规划包络；**禁止**据此倒计时判定结束（见下条）。将来终结技若加慢动作，是**第二个发出点**，消费方无需改动——这正是不把它绑死在 `perfect_parry_landed` 上的原因 |
| `time_dilation_ended()` | 同上，恢复 `time_scale = 1.0` 的同帧 | 同 `time_dilation_started` 三方，做反向复原 | **必须显式发出**：慢动作可被提前打断（敌人死亡 / 玩家受击），若消费方靠 `duration_frames` 自行倒计时，低通会**卡死在下潜态** |
| `game_paused()` | 暂停菜单控制器（写 `Engine.time_scale = 0` 的同帧，见 §5.4.1） | ① `AudioDirector`：duck/mute 全部 gameplay 总线 ② `InputManager`：清空输入缓冲、切 UI 输入上下文 ③ `DebugOverlay`：冻结帧时间曲线采样 | `Engine.time_scale = 0` **不会停音频**（§5.4.1）。本信号是全项目**唯一**的暂停事实来源 |
| `game_resumed()` | 同上，恢复 `time_scale = 1.0` 的同帧 | 同 `game_paused` 三方，做反向复原 | 与 `game_paused` **严格配对且不可重入**：已暂停时再次进入子菜单不得重复发 |
| `combat_state_changed(in_combat: bool)` | `ResonancePool`——脱战计时权威已在此（`OUT_OF_COMBAT_SEC = 3.0` / `GAIN_OUT_OF_COMBAT_PER_SEC = 2`，§4.2）；仅在布尔值**翻转**时发 | ① `AudioDirector`：音乐 Explore↔Combat 切段 ② `EchoDirector`：战斗中不触发/降级残响（S7「战斗中不卡输入」） ③ HUD：连段区 / 威胁区显隐 | 只广播既有计算结果，**不改变** `ResonancePool` 的回复逻辑，不违反其「禁止游戏逻辑外溢」约束。「进战」尚可用 `enemy_telegraph_started` 近似，**「脱战」此前无任何信号可推导** |
| `echo_finished(echo_id: StringName)` | `EchoDirector`（S7）：VO 播完、或被新残响顶替时 | ① `AudioDirector`：`Music` 从 L0 极简垫恢复 ② HUD：VO 字幕 / 残响面板收起 ③ 残响节点 VFX：辉光收束 | 与 `echo_triggered` **严格配对**；被打断也必须发，否则音乐**永久压在 L0**、字幕永不消失 |

> **AUD-7 · `player_state_entered.state_name` 枚举的来源与裁决（程基岩，2026-08-10）**
>
> - **GDD 未定义字符串枚举**，故按 §0 约定在此定义并注明来源：
>   - `design/gdd/combat.md` §② 只给出小写动词集合「idle → {slash, dash, grapple, leap, parry, resonate}」——是**设计意图**，不是工程标识符；§③ 的 `HP / combo / hitstun / iframe / parryArmed` 是**变量**，不是状态。
>   - `design/gdd/movement.md` §③ 的 `grounded / airborne / grappling` 是**标志位**；S2 明确「与战斗共享取消窗口」，不另立状态机。**移动侧零新增状态**。
> - **工程枚举权威 = `architecture.md` §4.4 + `ADR-003` §1 的状态节点名**（PascalCase，`state_name == node.name`），共 8 个：`Idle / Slash / Dash / Grapple / Leap / Parry / Resonate / Hitstun`。
> - **`SlashHeavy` 为本次新增的第 9 个状态**：`combat.md` §②「重击蓄力」与 §⑤「重击 18–25 dmg」定义了重击，其**蓄力是可中断的持续态**（音频侧 `AUD_VRB_SLASH_HEAVY_CHARGE` 需要一个循环蓄力层的进入/退出边界），与轻击 4 段共用同一个 `Slash` 状态无法表达。`ADR-003` §1 的节点树漏列此状态。→ **以本表为准，`ADR-003` §1 与 §4.4 的节点树待同步（已回报主理人，待批准后修订）**。
> - **音频侧已知错误纠正**：`design/audio/audio-event-list.md` §2.1 假设了 `player_state_entered("Slash1..4")` 四个状态名，**不成立**。正确接线 = 订阅 `&"Slash"` 进入事件，段号取 `combo_advanced(count)`（或 L3 读 `StateMachine.combo`）后再分派 `AUD_VRB_SLASH_SWING_1..4`。

### 5.3 关键数据流（对照 GDD §③ 逐条落地）

**流 A · 共鸣终结技**（S1 → S3 → S6，GDD systems-index §3 第 1 条）

```text
输入(共鸣键) → InputManager 裁决意图
  → FSM.Slash 末段检查 is_cancellable()
  → ResonancePool.try_spend(FINISHER_COST)   ← 权威裁决，非信号
       ├ 成功 → 扣 40 → emit resonance_changed → HUD 刷新 / VFX 谐波脉冲 / 音频
       │        → FSM 进入 Resonate 状态 → 伤害结算
       └ 失败 → emit resonance_spend_rejected("insufficient")
                → HUD 灰显 + "共鸣不足" 提示（GDD S1 §⑥）
```

**流 B · 完美格挡**（S4 ↔ S1 → S3，systems-index §3 第 3 条）

```text
敌人 FSM 进入 Telegraph → emit enemy_telegraph_started
  → HUD 威胁标记(THREAT 色 2Hz 脉冲) + 敌人材质 emissive 脉冲 + 音效
玩家按格 → FSM.Parry，parry_armed_frames = PARRY_WINDOW(6)
敌人攻击命中判定帧：
  ├ parry_armed_frames > 0 → 完美格
  │    → ResonancePool.add(GAIN_PERFECT_PARRY=5)
  │    → 敌人 Stagger 72 帧(1.2s) + 慢动作 0.3s (Engine.time_scale)
  │    → emit perfect_parry_landed
  └ 否则 → 玩家扣血 → Hitstun（上限 30 帧 = 0.5s）
```

**流 C · 神龛存档**（S5 → S8 → 全系统，systems-index §3 第 5 条）

```text
玩家交互神龛 → SaveManager.save_at_shrine(shrine_id)
  → 向各系统收集快照（ResonancePool / World / Echo / Meta / Player transform）
  → 序列化 → 原子写盘（temp → rename，见 ADR-004）
  → emit save_completed(true/false)
       └ 失败 → HUD 提示"未保存"，保留内存态不崩溃（GDD S8 §⑥）
```

### 5.4 慢动作与 hit-stop 的时间处理

GDD 要求 hit-stop 60–90 ms（S1 §②）与完美格慢动作 0.3 s（S1 §⑤）。

- **实现**：`Engine.time_scale` 缩放。注意 `time_scale` 会同时缩放物理 tick 的真实间隔，但**不改变 tick 计数逻辑**——我们的窗口是按 tick 计数的整数，所以 `CANCEL_WINDOW=8` 在慢动作中依然是 8 个 tick（只是这 8 tick 占用更长真实时间）。这符合动作游戏直觉：慢动作里玩家有更多真实时间反应，但游戏内帧数一致。
- **hit-stop 用 tick 冻结而非 time_scale=0**：60–90 ms ≈ 4–6 帧，实现为受击双方 FSM `frozen_frames`，不动全局 time_scale（避免影响 UI 与音频）。
- **UI 与音频免疫**：HUD 补间用 `Tween.set_process_mode(TWEEN_PROCESS_IDLE)` 且 `AudioDirector` 不随 time_scale 变调（音高扭曲会很难听）。
- **慢动作的音频处理已由阮和鸣给出方案（原 `[GAP] G7`）**：不改音高，改**滤镜**。挂点为新增的 `time_dilation_started` / `time_dilation_ended`（§5.2），处理为 `SFX` 低通 20500→1800 Hz（40 ms **真实**时间）、`Ambience`→1200 Hz、`Music` duck −3 dB，结束回升 120 ms。包络用真实毫秒而非帧——它不参与玩法判定（`design/audio/audio-event-list.md` §1.1 / §2.7）。**硬约束**：`AUD_ENM_TELEGRAPH_WARN` 必须**旁通**该低通（Tier-0 可访问性命脉，慢动作中预警音须保持可辨识，同上 §5 备注 2）。→ **建议将 §12.3 的 G7 标记为 RESOLVED，待主理人确认后同步**（本文暂未改 §12.3，避免越权）。

#### 5.4.1 暂停：`Engine.time_scale = 0` **不会**停止音频（AUD-6，2026-08-10）

**已核实的引擎事实**：`Engine.time_scale` 只缩放 `_process` / `_physics_process` 收到的 `delta` 与 `SceneTree` 的时间推进，**完全不作用于 `AudioServer`**。音频流由音频线程按真实时间驱动，总线、正在播放的 `AudioStreamPlayer*` 与总线特效在 `time_scale = 0` 下**照常推进**。

`design/ux/ux-spec.md` 的暂停实现采用 `Engine.time_scale = 0`。若不作显式处理，**暂停菜单背后的战斗音效、环境床与全部循环音**（`AUD_VRB_GRAPPLE_SWING_LOOP`、`AUD_PLR_LOW_HP_LOOP`、敌人预警层）**会继续播放**；其中循环音因为推进它们的玩法逻辑已被冻结，**永远等不到收束条件，等于卡死在响**。这是一个必现缺陷，不是边界情况。

**处理（强制，S0 接线时落地）**：

1. **`AudioDirector` 在 `_ready()` 订阅 `EventBus.game_paused` / `game_resumed`**（§5.2 新增），显式处理各总线：
   - `SFX_Combat` / `SFX_World` / `SFX_Resonance` / `Ambience` → 80 ms 淡出至静音。**用总线音量淡出，不用 `stop()`**——`stop()` 会让循环音在 resume 时从头开始、丢失相位与摆荡多普勒的连续性。
   - `Music` → duck −12 dB 保留（暂停不该死寂，也保住"游戏仍在运行"的心理反馈）。
   - `UI` → **不动**。暂停菜单自身的导航/确认音必须照常出声，否则暂停界面在可访问性上变成哑的。
   - `VO` → 当前残响念白 `stream_paused = true`，resume 时**续播而非重播**。
   - `game_resumed` 反向淡入 120 ms（与 §5.2 表一致）。
2. **淡出补间必须无视 time_scale**：`time_scale = 0` 时 `Tween` 收到的 delta 为 0，`TWEEN_PROCESS_IDLE` 也救不了——补间会和游戏一起冻住，淡出永远走不完。`AudioDirector` 的所有暂停相关 `Tween` 必须 `set_ignore_time_scale(true)`。**这是本条最容易漏的一处。**
3. **不得依赖 SceneTree 暂停的任何副作用**：本项目暂停走 `Engine.time_scale = 0`，**不是** `get_tree().paused = true`，因此一切"节点被暂停时音频自动停"的引擎行为在本项目**均不成立**。同样**禁止**用 `AudioServer` 全局静音替代（会把 `UI` 总线一起吞掉）。唯一合法路径 = `game_paused` 信号 + 总线级淡出。若 Phase 4 改用 `get_tree().paused`，本条与 `AudioDirector.process_mode`（需 `PROCESS_MODE_ALWAYS`）须一并重审。
4. **暂停期间禁止推进任何音频侧的帧计数**：`AudioDirector` 不得在暂停时消耗 `time_dilation_started` 的 `duration_frames` 之类的名义时长（本就不该倒计时，见 §5.2 契约表）。
5. **验收**：`tests/integration/test_pause_audio.gd` —— ① 发 `game_paused` 后 80 ms 内 `AudioServer.get_bus_volume_db("SFX_Combat")` ≤ 静音阈值；② 同期 `UI` 总线音量**不变**；③ 发 `game_resumed` 后 120 ms 内全部总线恢复暂停前取值；④ 暂停→恢复往返后循环音实例数不变（验证走的是淡出而非 `stop()`）。

---

## 6. 渲染管线

依据美术圣经 §3/§4/§8，全部落到 Godot 4 原生能力。

### 6.1 管线组成

```text
WorldEnvironment (每岛一份，共享基础 .tres 再局部覆盖)
├── Background: 自定义 Sky Shader（渐变天幕 + 星陨流光 + 极光带）  [美术 §3.2]
├── Ambient:    Sky 贡献 + 苍穹蓝/暮紫染调                        [美术 §3.1]
├── GI:         SDFGI（户外浮岛）/ VoxelGI（封闭遗迹）             [美术 §3.1]
├── Fog:        指数雾 + 高度雾（托住岛屿下缘云海）                 [美术 §3.1]
├── VolumetricFog: god-rays 光轴                                  [美术 §3.1]
├── SSR:        半分辨率模式（4.6 重写版），仅水面/抛光地面开启      [美术 §8.1 "慎用，记账"]
├── Tonemap:    AgX（4.6 起可配置）
├── Glow:       高阈值，只让星辉青/暖金能量溢出                     [美术 §3.3]
└── Adjustments: 轻微 exposure 提亮

Compositor (CompositorEffect 栈，4.3+)                            [美术 §3.3 §8.1]
├── ChaosGlitch      —— 混沌侵蚀区：UV 位移 + 色散 + 扫描线
├── DashPhase        —— 闪 i-frame：时间切片 + 瞬时去饱和
├── SpeedStreaks     —— 跃/荡：屏幕空间径向 streaks
└── ResonancePulse   —— 终结技/共鸣：全屏谐波环
```

**CompositorEffect 统一管理**：所有全屏特效注册进 `src/core/compositor_stack.gd`，每个效果暴露 `intensity: float (0..1)`。可访问性设置（美术 §9.3「故障特效强度滑块」「抖动/暗角减弱」）通过统一乘一个全局系数实现，**一个开关关掉所有光敏风险特效**。

### 6.2 光照

- **Key**：单一 `DirectionalLight3D`（"星核之日"），暖金偏白、低角度，开启阴影（PSSM 4 split，PC 档）。
- **Fill**：环境光 + 暮紫染调，不用额外方向光。
- **`AreaLight3D`（4.7 新增）**：用于神龛、共鸣节点、闸门符文、ResonanceMetal 镶边等"发光面"。**替代**原先"自发光材质 + 依赖 SDFGI 弹跳"的方案 → 光照更准、且减少对 SDFGI 高质量档的依赖。**预算：同屏 ≤ 8 盏**（见 §7.2）。
- **共鸣潮汐**（美术 §3.2，不做完整昼夜）：一条 `Curve` + `Gradient` 资源驱动 Key 光色温与天幕染色，在 `_process` 里插值（纯表现，允许在 `_process`）。**周期 `RESONANCE_TIDE_PERIOD_SEC` 初值 90–120 s（1.5–2 min）**，作为参数化常量暴露（`ColorTokens`/资源，不改代码）；原 6–8 分钟过慢、玩家难察觉氛围呼吸，90–120 s 更贴合「可感知的节奏」（G6 已收口）。

### 6.3 材质规范（对齐美术 §4.1）

统一基材质模板 `resources/materials/`，参数区间锁定在美术圣经给定范围内：

| 类别 | Roughness | Metalness | GI 模式 | 备注 |
|---|---|---|---|---|
| 浮空岩 / 建筑石 | 0.70–0.90 | 0.00 | Static | ORM 打包 |
| 共鸣金属（敌/机关） | 0.20–0.40 | 0.60–0.90 | Dynamic | + emissive 描边 |
| 植被 / 有机 | 0.50–0.80 | 0.00 | Static（大件）/ Disabled（草） | SSS 暖调 |
| 星木 / 结晶 | 0.30–0.60 | 0.00–0.20 | Dynamic | 透射/emission |

- **Fresnel Rim 全项目统一**：一个 `rim.gdshader` include，hero 强 rim / 环境弱 rim（美术 §4.3）。
- **描边用 stencil（4.5+）**：可交互物体、可抓锚点的"可交互提示描边"用模板缓冲实现外描边，比法线外扩更干净、不受模型尖角影响。
- **ORM 强制**：导入预设统一，Occlusion/Roughness/Metalness 合并，省采样（美术 §4.3）。

### 6.4 PC 画质档

三档，默认 **High**；玩家可自选。**所有档位不改变玩法可读性**（THREAT 色脉冲、telegraph 在 Low 档同样清晰——这是硬约束，不是画质选项）。

| 项目 | Low（1080p60 目标） | **High（默认，1440p60）** | Ultra（4K60 / 高刷） |
|---|---|---|---|
| 渲染缩放 | 0.77 (FSR/AA 放大) | 1.0 | 1.0 |
| SDFGI | 关（改用烘焙 LightmapGI + 反射探针） | 开，Cascades 4，半分辨率 | 开，Cascades 6，全分辨率 |
| VolumetricFog | 低密度，1/8 分辨率 | 中，1/4 分辨率 | 高，1/2 分辨率 |
| SSR | 关 | 半分辨率，仅水面 | 半分辨率，水面 + 抛光地面 |
| 阴影 | 2048，PSSM 2 split | 4096，PSSM 4 split | 4096，PSSM 4 split + 软阴影 |
| CompositorEffect | 仅 ChaosGlitch + DashPhase | 全部 | 全部（更高采样） |
| GPUParticles3D 上限 | 40% 预算 | 100% 预算 | 130% 预算 |
| AreaLight3D 同屏 | 4 | 8 | 12 |
| 网格 LOD 偏置 | 激进 | 默认 | 保守 |

**可访问性档位与画质档正交**：故障强度滑块、抖动减弱、暗角减弱独立于 Low/High/Ultra（美术 §9.3）。

---

## 7. 性能预算

### 7.1 目标与基准机

- **目标：60 fps 稳定 = 16.67 ms/帧**（GDD 帧基准；也是 §3 物理 tick 率）。
- **基准机（Target Spec，High 档 @1440p60）**：GTX 1660 Super / RX 5600 XT 级 GPU，6C12T CPU，16 GB RAM，SSD。
- **最低机（Min Spec，Low 档 @1080p60）**：GTX 1050 Ti / 集显 Radeon 780M 级，4C8T，8 GB RAM。
- **Steam Deck**：`[GAP]` 未列入 v1 Must（概念文档只写 PC/Steam）。Low 档有机会达 800p40，但**不承诺**，待主理人决定是否列为 Should。

### 7.2 帧时间预算（High 档 @1440p，基准机）

| 阶段 | 预算 | 说明 |
|---|---|---|
| **CPU 总计** | **≤ 9.0 ms** | 需留出提交与驱动开销 |
| ├ 玩法逻辑（物理 tick，FSM/AI/共鸣） | 4.0 ms | 60 Hz，非每渲染帧 |
| ├ 物理（Jolt，CharacterBody + Area 查询） | 2.0 ms | |
| ├ 动画（AnimationTree + Skeleton3D） | 1.5 ms | |
| └ 剔除 / 渲染指令提交 | 1.5 ms | |
| **GPU 总计** | **≤ 15.0 ms** | 与 CPU 并行，GPU 为实际瓶颈 |
| ├ 深度预 pass + 不透明 | 4.0 ms | |
| ├ SDFGI 更新 + 采样 | 3.0 ms | Cascade 更新摊帧 |
| ├ 阴影（PSSM 4 split） | 2.5 ms | |
| ├ VolumetricFog | 2.0 ms | 1/4 分辨率 |
| ├ 透明 + 粒子 | 1.5 ms | |
| ├ SSR（半分辨率，仅水面） | 1.0 ms | 无水面场景为 0 |
| └ 后处理（Glow + AgX + Compositor 栈） | 1.0 ms | |

**留 1.67 ms 余量**给 GC 尖峰、资源流式加载与录制/串流开销。

### 7.3 场景复杂度预算（每帧，High 档）

| 指标 | 预算 | 备注 |
|---|---|---|
| Draw calls | **≤ 1,500** | 静态几何用 MultiMesh / GridMap 合批 |
| 三角形（可见） | **≤ 2,000,000** | 含 LOD 后 |
| 同屏 GPU 粒子总数 | **≤ 30,000** | 战斗峰值；封顶且远处降密度（美术 §8.1） |
| 单个 GPUParticles3D | ≤ 2,000 | 硬上限，超出需评审 |
| 实时阴影投射光 | **≤ 4**（Key + 3） | AreaLight3D 默认不投影 |
| AreaLight3D 同屏 | ≤ 8 | §6.2 |
| 反射探针 | ≤ 6 / 岛 | |
| 材质唯一数 | ≤ 120 | 防状态切换爆炸 |
| 骨骼角色同屏 | ≤ 12 | 玩家 + 敌人峰值 |
| 纹理显存 | ≤ 2.5 GB | Min Spec 4 GB 显卡留余量 |
| 系统内存（含资源） | ≤ 3.5 GB | |

**加载/流式**：单岛加载 ≤ 3 s（SSD，异步 `ResourceLoader.load_threaded_request`），岛间切换有过场遮罩，不追求无缝。

### 7.4 消除高刷抖动（与 §3 配套）

必须三条同时成立，否则 144 Hz 玩家会看到卡顿：

1. `physics_interpolation = true`；
2. 玩家/敌人 transform **只在** `_physics_process` 修改；
3. **相机在 `_process` 跟随**，读取被跟随者的（插值后）`global_position`。相机若放在 `_physics_process`，会把画面重新锁回 60 Hz 台阶。

传送类操作（复活、换岛、Boss 位移）后调用 `reset_physics_interpolation()`。

### 7.5 输入延迟账（对照 S6「<50 ms 键鼠 / <80 ms 手柄」）

| 环节 | 典型 | 说明 |
|---|---|---|
| 输入设备 → OS | 1–8 ms | 手柄无线更高 |
| OS → 引擎事件 | ~1 ms | |
| 等待下一物理 tick | 0–16.7 ms（均值 8.3） | §3 固定 60 Hz 的代价 |
| 逻辑 → 渲染提交 | ~16.7 ms | 一帧 |
| 物理插值附加视觉延迟 | ~0–16.7 ms | 插值本质是显示"过去" |
| 显示器（60 Hz 假设） | ~8–16 ms | |
| **合计（键鼠，均值）** | **~40–50 ms** | 贴近上限，**必须实测** |

**缓解手段（已排期，见控制清单）**：
- `Input.set_use_accumulated_input(false)` —— 输入不按渲染帧累积，降低采样延迟；
- 垂直同步默认 **Adaptive**，并提供 Disabled 选项；
- 提供 `Swapchain Image Count = 2`（双缓冲）选项给延迟敏感玩家；
- **输入缓冲（input buffering）**：按下动词若当前不可取消，缓存该意图 **≤ 6 帧**，一进取消窗立即释放。这既降低"感知延迟"，也直接服务 P1 连段中断率 <5% 的验收目标。

> ⚠ **风险登记 RISK-PERF-1**：60 Hz 固定 tick + 物理插值使键鼠延迟贴近 50 ms 红线。Phase 4 必须用 240 fps 摄像实测；若超标，备选是关闭物理插值并要求 tick=60 的整数倍刷新率（代价：144 Hz 抖动），或提高 tick 到 120 并**同步重算全部帧常量**（需回 GDD 走变更流程，代价大）。

### 7.6 剖析接入

- 内置：Godot Profiler（CPU/GPU/物理帧时间）、Monitors（draw call、顶点、显存）。
- 自建 `DebugOverlay`（F3 切换）：实时帧时间曲线、物理 tick 占用、粒子实例数、当前状态机状态名、共鸣池值、预算超限**红字告警**（超 §7.3 任一预算即高亮）。
- **性能回归门禁**：Phase 4 起建立 3 个固定基准场景（中枢岛静立 / 3 敌战斗 / Boss 战），CI 每夜跑 `--headless` 无法测 GPU，故改为**本地一键脚本**输出 CSV 并与基线比对，超 10% 回归即报警。

---

## 8. 输入系统

### 8.1 结构

`InputManager`（Autoload）承担四件事，**FSM 只消费其输出**：

1. **动作映射**：使用 Godot InputMap，动作名固定为 6 动词 + 系统动作。
2. **设备仲裁**：判定当前活跃设备（键鼠 / 手柄），驱动 UI 按键图标切换。
3. **输入缓冲**：≤6 帧意图缓存（§7.5）。
4. **优先级裁决**：`格 > 闪 > 斩`（GDD S1 §⑥），输出单一意图。

```gdscript
# 动作名（InputMap actions）—— 全项目唯一命名源
# 玩法：verb_slash / verb_dash / verb_grapple / verb_leap / verb_parry / verb_resonate
# 移动：move_forward / move_back / move_left / move_right
# 系统：ui_pause / ui_interact / ui_map / debug_overlay
```

### 8.2 双输入方案（GDD S6 §②）

| 动词 | 键鼠 | 手柄（Xbox 布局） |
|---|---|---|
| 斩 Slash | 鼠标左键 | X / RB |
| 闪 Dash | Shift / 鼠标右键 | A |
| 荡 Grapple | E | RT |
| 跃 Leap | 空格 | B |
| 格 Parry | Q / 鼠标中键 | LT |
| 共鸣 Resonate | F | Y |
| 移动 | WASD | 左摇杆 |
| 视角 | 鼠标 | 右摇杆 |

手柄需 `[GAP]` 确认是否支持陀螺仪辅助瞄准（4.7 已支持控制器陀螺仪读取）——非 Must，列 Could。

### 8.3 设备仲裁（用 4.7 新能力）

GDD S6 §⑥要求"双设备同时输入 → 最近输入设备优先"。Godot 4.7 起键鼠事件带设备 ID（`InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`），可直接判定：

```gdscript
# autoloads/input_manager.gd
enum Device { KEYBOARD_MOUSE, GAMEPAD }
var active_device: Device = Device.KEYBOARD_MOUSE

func _input(event: InputEvent) -> void:
    var d := _classify(event)
    if d != active_device:
        active_device = d
        EventBus.settings_changed.emit(&"active_device")  # UI 换按键图标

func _classify(event: InputEvent) -> Device:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        return Device.GAMEPAD
    return Device.KEYBOARD_MOUSE   # 4.7 可进一步按 event.device 区分键/鼠
```

摇杆漂移防护：`InputEventJoypadMotion` 需超过死区（默认 0.2，可玩家调）才算"活跃输入"，否则漂移会把图标一直抢回手柄。

### 8.4 可重映射（呼应可访问性 Standard 基线）

- **全动作可重映射**，含键鼠与手柄两套独立映射表。
- 存储：`user://input_map.json`，与存档分离（换存档不丢按键设置）。
- 运行时用 `InputMap.action_erase_events()` + `action_add_event()` 应用。
- **冲突检测**：同一动作组内重复绑定给出警告并允许覆盖。
- **可访问性附加项**（美术圣经 §9 要求 UX 规格引用分级）：
  - 长按 → 切换（toggle）选项：格挡/瞄准可设为切换而非长按；
  - 连点辅助：斩可设为"按住自动连段"；
  - 死区与灵敏度独立可调；
  - 输入延迟宽容：`CANCEL_WINDOW` **不提供**放宽选项（会破坏 P1 与平衡），改为提供上述辅助项。`[GAP]` 该取舍需文策渊在 UX 规格确认。

---

## 9. 语义色的工程落点（`ColorTokens`）

**上游不一致已收口（CONCERN-A —— 已裁决：`design/color-tokens.md` v1.0 为唯一权威，2026-08-08）**：systems-index §2 与美术圣经 §2 曾对同一语义给出不同 hex，现已按下表收敛。**本表的"裁决值"列即工程唯一取值来源**：

| 语义 | systems-index §2（旧） | art-bible §2 | **裁决值 (color-tokens.md v1.0)** | 状态 |
|---|---|---|---|---|
| 威胁/混沌 THREAT | `#A62C6B` | `#A62C6B` | `#A62C6B`（强制锁定，永不变） | ✔ **RESOLVED**（本就一致） |
| 玩家/友方主色 PLAYER_ALLY_MAIN | — | `#5FD2C8`（星辉青） | `#5FD2C8` | ✔ **RESOLVED** |
| 共鸣辉光 RESONANCE_GLOW | `#9FF7E8`（青白） | `#5FD2C8`（星辉青） | `#9FF7E8` | ✔ **RESOLVED**：非真冲突，拆分为基色 `PLAYER_ALLY_MAIN=#5FD2C8` 与**自发光态** `RESONANCE_GLOW=#9FF7E8` |
| 友好 teal FRIENDLY_TEAL | ~~`#2BB6A8`~~（已退役） | `#5FD2C8` | `#5FD2C8` | ✔ **RESOLVED**：统一星辉青 |
| 友好 amber FRIENDLY_AMBER | ~~`#F4B740`~~（已退役） | `#F2C15E` | `#F2C15E` | ✔ **RESOLVED**：统一暖金 |
| 友好 coral FRIENDLY_CORAL | `#FF8A65` | 未列 | `#FF8A65` | ✔ **RESOLVED**：canon 化入册 |
| 伤害/警告 DAMAGE_WARN | — | `#E5484D` | `#E5484D` | ✔ **RESOLVED**：低血/受击专用，**非敌色**（守"THREAT 仅敌/混沌"铁律） |
| UI 底 UI_BG | — | `#1A2233` | `#1A2233` | ✔ **RESOLVED** |

> **退役 hex 禁令**：`#2BB6A8`、`#F4B740` 已退役，**禁止**作为活值出现在任何资源、代码、Shader 或文档中（仅允许出现在 `color-tokens.md` §4 退役对照表的历史记录里）。lint 应将二者列入拒绝名单。
>
> **THREAT 外溢禁令**：`#A62C6B` 仅敌人/混沌专属，任何模式不得外溢到中立/友方；低血与受击一律用 `DAMAGE_WARN`。

**工程对策**：建立**唯一**运行时色彩资源 `resources/colors/color_tokens.tres`，全项目（材质、Shader uniform、HUD、VFX）只从此处取色，禁止任何 hex 字面量。

```gdscript
# src/core/color_tokens.gd
class_name ColorTokens extends Resource
## 唯一语义色源。任何 hex 字面量出现在其他文件均视为违规（lint 拦截）。
## 全部取值权威 = design/color-tokens.md v1.0（已裁决，勿在此另立真相源）。
@export var THREAT: Color              # #A62C6B —— 强制锁定，仅敌/混沌，永不变
@export var PLAYER_ALLY_MAIN: Color    # #5FD2C8 星辉青 —— 玩家/友方基色
@export var RESONANCE_GLOW: Color      # #9FF7E8 青白 —— 自发光态（emission + Bloom）
@export var FRIENDLY_TEAL: Color       # #5FD2C8 —— 同 PLAYER_ALLY_MAIN（同 hue）
@export var FRIENDLY_AMBER: Color      # #F2C15E 暖金 —— 权威 Token 名为 FRIENDLY_GOLD
@export var FRIENDLY_CORAL: Color      # #FF8A65
@export var DAMAGE_WARN: Color         # #E5484D —— 低血/受击，非敌色
@export var GATE_READY: Color          # 共鸣≥30 态
@export var INACTIVE: Color            # 灰
@export var UI_BASE: Color             # #1A2233 —— 权威 Token 名为 UI_BG
```

取值已由 `design/color-tokens.md` v1.0 裁决闭合；`.tres` 按上表填入即可，Phase 4 无需再等裁决。**单资源结构继续保留**：未来任何色彩调整仍是"改一个 .tres 字段、零代码改动"。

**色盲模式**：`ColorTokens` 提供第二套 `color_tokens_cvd.tres`，运行时热切换。因为全项目只从一个资源取色，色盲模式**天然全覆盖**，不会漏掉某个写死 hex 的角落——这是把资源化做对的直接收益（美术 §9.1 要求"高对比/色盲模式"）。

---

## 10. 存档：神龛存档与复活

### 10.1 格式与位置 [ADR-004]

- **格式：JSON**（`JSON.stringify` / `JSON.parse`），非 `ConfigFile`、非二进制 `var_to_bytes`。
- **位置**：`user://saves/slot_<n>.json`（Windows 实际落在 `%APPDATA%/Godot/app_userdata/Aetherfall/`）。
- **单存档槽 v1**（GDD S8 只要求"唯一存档/复活点"，未要求多槽）；结构预留 `slot` 字段以便后续扩展。
- **设置与按键映射独立文件**（`user://settings.json`、`user://input_map.json`），不随游戏存档回滚。

### 10.2 数据结构

```jsonc
{
  "schema_version": 1,              // 版本不匹配 → 拒绝加载并提示（GDD S8 §⑥）
  "game_version": "0.4.0",
  "saved_at_unix": 1786000000,
  "checksum": "sha256:...",         // 覆盖除本字段外全部内容，检测损坏
  "player": {
    "hp": 100,                      // 复活恒满血，但存档时记录真实值
    "last_shrine_id": "hub_shrine_01",
    "island_id": "hub",
    "transform": [ /* 12 floats */ ]
  },
  "resonance": { "current": 50 },   // 上限/初始值不入档，来自 GameConstants
  "world": {
    "islands_unlocked": ["hub", "isle_01"],
    "gates_open": ["isle_01_gate_a"],
    "shrines_active": ["hub_shrine_01"],
    "nodes_triggered": ["isle_01_echo_02"]
  },
  "narrative": { "echoes_collected": ["echo_001", "echo_004"] },
  "meta": {
    "skill_points": 3,
    "skills_unlocked": ["swift_01", "resonance_02"],
    "milestones": ["first_boss"]
  },
  "stats": { "playtime_sec": 7240, "deaths": 12 }
}
```

**设计要点**：
- **只存"玩家造成的差异"，不存可推导数据**。`RESONANCE_MAX` / `GATE_COST` 等常量**绝不入档**——否则改平衡时老存档会带回旧数值，制造双真相源。这直接保护了 [ADR-002] 的单一真相源。
- HP / combo / hitstun 等**不持久**（GDD S1 §③明确"HP/combo 不持久"），复活恒满血。
- 共鸣池当前值**持久**（GDD S3 §③ 明确）。

### 10.3 原子写盘（应对 GDD S8「写盘失败不崩溃」）

```gdscript
# 1. 写入 user://saves/slot_1.json.tmp
# 2. flush + close
# 3. 校验：重新读取并解析 .tmp，checksum 通过
# 4. 通过 → DirAccess.rename(tmp, slot_1.json)   ← 单一原子步
#    失败 → 保留旧存档，emit save_completed(false)，HUD 提示"未保存"
# 5. 保留上一份为 slot_1.json.bak，损坏时可回退
```

断电/崩溃最坏情况只会丢**本次**存档，不会得到半截损坏文件。

### 10.4 复活流程（S2/S5/S8 共用）

```text
死亡 或 y < 世界下限
  → 淡出 0.5s（GDD S2 §⑥"0.5s 后复活"）
  → 从 SaveManager 取 last_shrine_id → 查 S5 神龛落点
  → 若无神龛（新档未存过）→ 兜底中枢岛神龛（GDD S8 §⑥）
  → 玩家 transform 复位 → reset_physics_interpolation()  ← 必须，否则拉丝
  → HP 满、combo 清零、iframe/hitstun 清零
  → 共鸣池：保持当前值（不重置，GDD 未要求重置）
  → 世界进度不回滚（GDD"不掉进度/不掉收集"）
  → emit player_respawned
```

> **注意**：复活**不**重新读盘。读盘只发生在启动与主动读档；复活是内存态复位 + 位置传送。这避免了"死一次丢掉上次存档后的探索进度"的严重体验问题。

---

## 11. 测试与 CI

### 11.1 测试框架：gdUnit4

选 **gdUnit4**（MIT）而非 GUT。核验（2026-08-08）：gdUnit4 `v6.2.x`（master）**明确支持 v4.7 / v4.7.1**，而 v6.1.x 支持到 4.6.3。

决定性理由：gdUnit4 的 **`SceneRunner` 支持逐帧推进**（`simulate_frames(n)`）与输入模拟。这正是验证 GDD 帧级验收标准所必需的：

```gdscript
# tests/integration/test_cancel_window.gd
func test_dash_can_cancel_slash_within_8_frames() -> void:
    var runner := scene_runner("res://scenes/player/Player.tscn")
    runner.invoke_input_action("verb_slash")
    runner.simulate_frames(GameConstants.CANCEL_WINDOW)   # 恰好第 8 帧
    runner.invoke_input_action("verb_dash")
    runner.simulate_frames(1)
    assert_str(runner.get_property("state_machine").current_state_name) \
        .is_equal("Dash")     # 8 帧内必须可取消

func test_dash_cannot_cancel_after_window() -> void:
    var runner := scene_runner("res://scenes/player/Player.tscn")
    runner.invoke_input_action("verb_slash")
    runner.simulate_frames(GameConstants.CANCEL_WINDOW + 1)  # 第 9 帧，超窗
    runner.invoke_input_action("verb_dash")
    runner.simulate_frames(1)
    assert_str(runner.get_property("state_machine").current_state_name) \
        .is_not_equal("Dash")
```

因为 §3 把「帧」定义为物理 tick，这类断言是**确定性**的，不会 flaky。

### 11.2 测试分层与 GDD 验收标准映射

| 层 | 位置 | 覆盖的 GDD 验收标准 | CI |
|---|---|---|---|
| **单元**（纯逻辑，无场景） | `tests/unit/` | S3 池上限 100 不溢出；恰扣 40/30；池=35 互斥；节点 5s cd；S8 存档还原/版本不匹配拒绝 | ✔ 每次 push |
| **集成**（SceneRunner 帧级） | `tests/integration/` | S1 取消 ≤8 帧；闪 iframes 期 0 伤害；完美格触发破防 ≥1s；S4 telegraph 100% 有 THREAT；Sentinel 弱点 x2 (±5%)；Boss 阶段切换无即死 | ✔ 每次 push |
| **工具扫描** | `tools/` | S5 0 逻辑死路；每岛可达比 ≥0.6；每岛 ≥1 神龛；≥1 纯空中路线 | ✔ 每夜 |
| **人工/录像** | — | 连段中断率 <5%（20 人）；输入延迟实测；60fps 达标 | ✗ 手动，交严守真 |

**先写测试**：每个 Story 实现前先落断言。GDD §⑦ 的每个复选框都必须能指向一个测试文件路径，否则该 Story 不算完成。

### 11.3 CI（GitHub Actions）

```yaml
# .github/workflows/ci.yml（要点）
env:
  GODOT_VERSION: "4.7.1"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true, submodules: recursive }   # gdUnit4 为 submodule
      - name: Cache Godot binary + .godot import cache
        uses: actions/cache@v4
      - run: godot --headless --import --quit-after 200   # 必须先导入资源
      - run: godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/
      # 门禁：gdlint 静态检查 + 常量一致性测试 + 禁 hex 字面量扫描
```

- Godot 4 标准二进制自带 `--headless`，CI 无需 Xvfb。
- **首次运行必须 `--import`**，否则资源未导入导致测试全红。
- **LFS**：`art/`、`audio/` 走 Git LFS（见 §12.2）。

### 11.4 编码标准（路径作用域）

| 路径 | 规则 |
|---|---|
| `src/core/**` | **热路径零分配**：`_physics_process` 内禁 `Array`/`Dictionary`/`String` 新建；预分配复用；禁 `find_child`（O(n) 遍历） |
| `src/combat/**`, `src/movement/**` | **数据驱动**：数值一律来自 `.tres` 或 `GameConstants`；**代码内禁止玩法数值字面量**（除 0/1） |
| `src/ai/**` | **可调试**：每次状态迁移写入环形日志缓冲，`DebugOverlay` 可视化当前 state + telegraph 剩余帧 |
| `src/ui/**`, `scenes/ui/**` | **不持有游戏状态**：只读订阅 EventBus；禁止 UI 直接改玩法状态；禁止 UI 调 `ResonancePool.add()` |
| `scenes/**` | 禁跨场景 `preload` 兄弟场景；禁 `get_node("../..")` 长路径 |
| 全局 | 强制静态类型；`class_name` 唯一；signal 过去式命名；`#` 注释解释**为什么**而非**做什么** |

Lint：`gdlint`（gdtoolkit）+ 自建 `tools/lint_hex_literals.gd`（扫描非 `color_tokens.tres` 中的 hex 颜色字面量）+ `tools/lint_magic_numbers.gd`（扫描 `src/combat|movement` 中的裸数值）。

---

## 12. 依赖、版本控制与知识缺口

### 12.1 依赖策略（Godot 原生优先）

| 依赖 | 用途 | 类型 | 风险 |
|---|---|---|---|
| Godot 4.7.1 标准构建 | 引擎 | 官方 | 低 |
| gdUnit4 v6.2.x | 测试 | MIT，git submodule | 低（可替换为 GUT） |
| gdtoolkit (gdlint/gdformat) | 静态检查 | 仅 CI，不进包 | 无 |

**运行时第三方依赖 = 0**。物理用 Godot 内置 Jolt（4.6 起 3D 默认），不引入 godot-jolt GDExtension。VFX/GI/后处理全部原生。这符合"避免非常规依赖"的约束，也让引擎升级成本可控。

### 12.2 版本控制

- Git；`art/`（psd/blend/高分辨率纹理）、`audio/`（wav）走 **Git LFS**。
- `.gitignore`：`.godot/`（导入缓存）、`export/`、`*.tmp`。
- **`.godot/` 不入库，但 `*.import` 文件必须入库**（否则每人重导入产生不同 UID）。
- Godot **4.6 起有唯一节点标识符（UID）**，重命名/移动资源不再断引用——但仍要求：**移动文件必须在编辑器内操作**，不要用文件管理器拖。
- 分支：`main`（可运行）+ `feat/<story-id>`；Solo 下允许直推 main 的小改，但 Story 级改动走 PR 以留下评审记录。

### 12.3 知识缺口与待裁决项 `[GAP]`

| # | 项 | 影响 | 建议处置 |
|---|---|---|---|
| ~~**G1**~~ | ~~**语义色冲突**：RESONANCE_GLOW / teal / amber 在 systems-index 与 art-bible 取值不同（§9）~~ | — | ✅ **RESOLVED（2026-08-08）**：已裁决，`design/color-tokens.md` v1.0 为唯一权威。`RESONANCE_GLOW=#9FF7E8`（自发光态）/ `PLAYER_ALLY_MAIN=FRIENDLY_TEAL=#5FD2C8` / `FRIENDLY_AMBER=#F2C15E` / `FRIENDLY_CORAL=#FF8A65` / `DAMAGE_WARN=#E5484D` / `UI_BG=#1A2233`；`#2BB6A8`、`#F4B740` 已退役禁用。详见 §9 |
| **G2** | 输入延迟能否守住 <50 ms（§7.5 RISK-PERF-1） | **高**。可能推翻 §3 插值方案 | Phase 4 首个 spike，240fps 摄像实测 |
| **G3** | Hard telegraph 下限 24 帧（0.4s）是否跌破心流带（承接 CONCERN-1） | 中 | 已数据驱动（`.tres`），Phase 4 A/B，无需改代码 |
| **G4** | 「荡中攻击」「洗点」（承接 CONCERN-2） | 中。架构已预留（FSM 允许 Grapple 态叠加 Slash 子状态），但**不实现** | 维持不纳入 v1；若纳入需回概念文档补 MoSCoW |
| ~~**G5**~~ | ~~Steam Deck 是否列 Should~~ | — | ✅ **RESOLVED（2026-08-08）**：**v1 不支持 Steam Deck**。但**架构预留**：画质档必须保留 Deck 规格的下限档，UI 缩放接口按 Deck 分辨率/DPI 预留，不得写死桌面分辨率假设 |
| **G6** | 共鸣潮汐周期时长（§6.2） | 低 | **已收口**：`RESONANCE_TIDE_PERIOD_SEC = 90–120s`（v0.2 拍板，交林绘澄确认） |
| ~~**G7**~~ | ~~慢动作时的音频处理（§5.4）~~ | — | ✅ **RESOLVED（2026-08-10）**：阮和鸣裁决——慢动作期间不做全局变调/变速，改用 `SFX`+`Ambience` 低通下潜 + `Music` duck + 满保真特写层，`Music`/`UI`/`VO` 免疫（方案已写入 §5.4，引用其 G7 收口） |
| ~~**G8**~~ | ~~lock-on 摄像机（GDD S1 §⑧开放问题）~~ | — | ✅ **RESOLVED（2026-08-08）**：**实现 lock-on 摄像机**。`CameraRig` 从一开始就设计目标锁定层（`LockOnTargeting` 子系统：目标搜集/评分/切换/丢失回退）。Dash 方向解算采用**目标相对极坐标解**（侧向输入→环形、前后输入→直线、斜向→螺旋），详见 ADR-003。UX 细节见 `design/ux/ux-spec.md` lock-on 章节 |
| **G9** | Godot 4.8（Q4 2026 预计）是否升级 | 低 | 按 ADR-001 版本策略：Beta 里程碑后冻结 |

> **知识诚实声明**：本文档中所有 Godot 版本能力（4.3 CompositorEffect、4.5 stencil/AccessKit、4.6 Jolt 默认/SSR 重写/D3D12 默认/UID、4.7 HDR 输出/AreaLight3D/键鼠设备 ID/Control offset transform、gdUnit4 版本兼容矩阵）均于 **2026-08-08** 核验自 godotengine.org 官方发布页、官方 release policy 与 gdUnit4 官方仓库兼容表。**4.7 的 SDFGI / VolumetricFog / CompositorEffect 未见专门更新说明**，故按 4.3–4.6 的既有行为规划；若 Phase 4 实测有出入，以实测为准并回报修订本文。

---

## 13. 实现顺序（对齐 GDD 依赖 DAG）

严格遵循 systems-index §1 的 **S3 → S1 → S2 → S4 → S5 → S8 → S6 → S7**，但**前置一个 S0 地基阶段**（DAG 未涵盖的工程底座）：

| 阶段 | 内容 | 出口条件 |
|---|---|---|
| **S0 地基** | 项目骨架、8 个 Autoload、GameConstants、EventBus、ColorTokens、FSM 基类、物理 tick/插值配置、gdUnit4 + CI、DebugOverlay | CI 绿；常量一致性测试通过；空场景稳定 60 fps |
| **S3** | 共鸣池（纯逻辑先行，无 UI） | 4 条 GDD 验收单测全绿 |
| **S1** | 6 动词 FSM + 取消窗 + 命中反馈 | 取消 ≤8 帧集成测试全绿；**手感 spike 通过** |
| **S2** | 轻重力 + 锚点 + 荡/跃 | 跃→闪→斩 ≤8 帧；越界复活 100% |
| **S4** | 3 原型 + telegraph | telegraph 100% 覆盖；弱点 x2 |
| **S5** | 中枢岛 + 3 浮岛 + 闸门/神龛/节点 | 0 死路；可达比 ≥0.6 |
| **S8** | 神龛存档/复活（技能树 Should 后置） | 存档还原 100%；写盘失败不崩 |
| **S6** | HUD + 输入设置 | 三态色正确；双设备通关 |
| **S7** | 残响回声 | 节点 +10 正确；战斗中不卡输入 |

**S0 必须先做**：S3 的单测需要 `GameConstants` 与 gdUnit4 就位，否则"先写测试"无从谈起。这是对 DAG 的工程侧补充，不改变 GDD 依赖关系。

---

## 附录 A · 关键项目设置（`project.godot`）

```ini
[application]
run/main_scene="res://scenes/boot/Boot.tscn"

[physics]
common/physics_ticks_per_second=60        ; §3 —— 1 tick = GDD 的 1 帧
common/physics_interpolation=true         ; §3 / §7.4
3d/physics_engine="Jolt Physics"          ; 4.6 起新建 3D 项目默认

[rendering]
renderer/rendering_method="forward_plus"  ; SDFGI/体积雾/SSR/Compositor 必需
rendering_device/driver.windows="d3d12"   ; 4.6 起 Windows 导出默认
anti_aliasing/quality/msaa_3d=2           ; 2x，stylized 干净边缘
environment/defaults/default_environment="res://resources/env/base_env.tres"

[display]
window/vsync/vsync_mode=2                 ; Adaptive，可玩家改
window/stretch/mode="canvas_items"        ; UI 支持 1280x720–4K（GDD S6 §⑥）

[input_devices]
pointing/emulate_touch_from_mouse=false
```

## 附录 B · 文档间引用契约

| 本文引用 | 来源 | 若冲突 |
|---|---|---|
| 全部玩法常量 | `design/gdd/systems-index.md §2` | **以 GDD 为准**，改本文 |
| 渲染能力项、材质区间、可访问性分级 | `design/art-bible.md` §3/§4/§8/§9 | 以美术圣经为准，除非技术不可行（须回报） |
| 支柱验证指标（中断率 <5%、可达比 ≥0.6） | `design/concept/game-concept.md` §1 | 以概念文档为准 |
| 语义色 hex | **冲突中**，见 §9 / G1 | **待主理人裁决** |




