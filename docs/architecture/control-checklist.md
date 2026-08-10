# 控制清单 · Phase 4/5 实现前必须 scaffold

> 版本 v1.0 ｜ 日期 2026-08-08 ｜ 作者 程基岩 ｜ 引擎 Godot 4.7.1-stable
> 用法：**逐项勾选，全部完成才算 S0 地基就绪，方可开始 S3 系统实现。**
> 依据：`architecture.md` v1.0、`adr-001..005.md`、`architecture-review.md`
> 图例：🔴 阻塞项（不做后面全塌）｜🟡 重要｜🟢 可延后但别忘

---

## A. 工程初始化

- [ ] 🔴 安装 **Godot 4.7.1-stable 标准构建**（非 .NET）；版本号写入 `README.md` 与 CI `GODOT_VERSION`，单点声明
- [ ] 🔴 创建项目，`project.godot` 按 `architecture.md` 附录 A 配置
- [ ] 🔴 `rendering/renderer/rendering_method = forward_plus`（SDFGI/体积雾/SSR/Compositor 的前提，选错后面全部失效）
- [ ] 🔴 `physics/common/physics_ticks_per_second = 60`（**1 tick ≡ GDD 的 1 帧**）
- [ ] 🔴 `physics/common/physics_interpolation = true`
- [ ] 🟡 `physics/3d/physics_engine = "Jolt Physics"`（4.6 起新建项目默认，确认已启用）
- [ ] 🟡 Windows 导出图形 API 设 D3D12；记录 Vulkan 回退启动参数 `--rendering-driver vulkan`
- [ ] 🟡 `display/window/stretch/mode = canvas_items`（GDD S6 要求 1280×720–4K 适配）
- [ ] 🟡 垂直同步默认 Adaptive，设置界面预留 Disabled 选项
- [ ] 🟢 MSAA 3D = 2x

## B. 目录结构

- [ ] 🔴 按 `architecture.md` §2.1 建全部目录（`autoloads/ src/ scenes/ resources/ shaders/ tests/ tools/ art/ audio/`）
- [ ] 🔴 `src/` 与 `scenes/` 严格分离（纯逻辑 vs 节点接线）——这是单测能跑起来的前提
- [ ] 🟡 每个目录放 `.gdignore` 或 `README.md` 说明职责，防止后期乱塞

## C. 版本控制

- [ ] 🔴 `git init`；`.gitignore` 含 `.godot/`、`export/`、`*.tmp`、`user://` 产物
- [ ] 🔴 **确认 `*.import` 文件入库**（不入库会导致每人重导入产生不同 UID）
- [ ] 🟡 Git LFS 配置：`art/**`（psd/blend/大纹理）、`audio/**`（wav）
- [ ] 🟡 分支约定：`main` 恒可运行 + `feat/<story-id>`；Story 级改动走 PR
- [ ] 🟢 在 `README.md` 写明"移动/重命名资源必须在 Godot 编辑器内操作，不要用文件管理器"

## D. Autoload 单例（顺序即依赖顺序，不可颠倒）

- [ ] 🔴 1. `GameConstants` —— 全部常量照抄 systems-index §2；含 `SOURCE_OF_TRUTH` 指向 GDD 路径
- [ ] 🔴 2. `EventBus` —— 按 `architecture.md` §5.2 声明全部 signal（过去式命名，无状态无逻辑无 `_process`）
- [ ] 🔴 3. `ResonancePool` —— 按 ADR-002：`_current` 私有、**无 setter**、只读访问器、`try_spend()` / `add()` 唯一入口、`reset_for_test()`
- [ ] 🔴 4. `SaveManager` —— 按 ADR-004：版本化 JSON、原子写、checksum、`.bak` 回退、读档逐字段钳制
- [ ] 🔴 5. `InputManager` —— 动作映射、设备仲裁（4.7 设备 ID）、≤6 帧输入缓冲、优先级裁决（格>闪>斩）
- [ ] 🟡 6. `AudioDirector` —— 音频总线骨架（Master/Music/SFX/UI/Ambience）
- [ ] 🟡 7. `EchoDirector` —— S7 残响收集（可延后到 S7，但先占位）
- [ ] 🔴 8. `DebugOverlay` —— F3 切换；**确认 release 导出经 feature tag 剥离**
- [ ] 🔴 校验 Autoload 准入红线：新增任何 Autoload 前对照"全局唯一 + 跨场景存活 + ≥3 系统消费"三条

## E. 核心节点与基类

- [ ] 🔴 `src/core/state.gd`（`State` 基类）—— `frames_in_state`、`cancel_open_at_frame`、**`is_cancellable()` 单点实现**
- [ ] 🔴 `src/core/state_machine.gd` —— `try_transition()` 唯一转移入口，含 hitstun 拒绝、`can_enter()` 校验、状态事件广播
- [ ] 🔴 `Player.tscn` 骨架：`CharacterBody3D` + `StateMachine` + 8 个状态节点 + Hitbox/Hurtbox
- [ ] 🔴 `src/movement/locomotion.gd` —— 纯函数积分，`GRAVITY = -5.88`，`DELTA = 1.0/60` **常量**（非 `_physics_process` 传入）
- [ ] 🟡 敌人 `StateMachine` 复用同一基类，状态集 `Idle/Telegraph/Attack/Recover/Stagger/Dead`
- [ ] 🔴 `CameraRig` **独立于 Player**，在 `_process` 跟随（放 `_physics_process` 会把画面锁回 60 Hz 台阶）
- [ ] 🔴 `Boot.tscn` 设为 main scene；`Main` 场景含 `WorldRoot`/`PlayerRoot`/`CameraRig`/`UILayer`

## F. 资源管线（数据驱动）

- [ ] 🔴 `resources/constants/game_constants.tres`
- [ ] 🔴 `resources/colors/color_tokens.tres` —— **唯一语义色源**；取值全部来自 `ColorTokens`（权威 = `design/color-tokens.md` v1.0，**已裁决 (color-tokens.md v1.0)**）：`THREAT=#A62C6B`（强制锁定，仅敌/混沌）、`PLAYER_ALLY_MAIN=FRIENDLY_TEAL=#5FD2C8`、`RESONANCE_GLOW=#9FF7E8`（自发光态）、`FRIENDLY_AMBER=#F2C15E`、`FRIENDLY_CORAL=#FF8A65`、`DAMAGE_WARN=#E5484D`（低血/受击，非敌色）、`UI_BG=#1A2233`。**退役禁用**：`#2BB6A8`、`#F4B740` 不得作为活值出现（lint 拒绝名单）
- [ ] 🟡 `resources/colors/color_tokens_cvd.tres` —— 色盲模式第二套，运行时热切换
- [ ] 🔴 `VerbDefinition` 资源类 + 6 个动词 `.tres`（帧数/位移/伤害/cd/取消窗开启帧）
- [ ] 🔴 `EnemyDefinition` 资源类 + 3 原型 `.tres`（**telegraph 以帧存储**：Normal 36–72、Hard 24–48）
- [ ] 🟡 `EchoEntry` / `SkillNode` 资源类（可延后，先定 schema）
- [ ] 🔴 纹理导入预设：**ORM 打包**（美术圣经 §4.3）
- [ ] 🟡 统一基材质模板，参数锁在美术圣经 §4.1 区间内
- [ ] 🟡 `rim.gdshader` 全项目 Fresnel Rim include（hero 强 / 环境弱）

## G. 渲染管线

- [ ] 🔴 `resources/env/base_env.tres`（WorldEnvironment 基线）
- [ ] 🔴 SDFGI 启用并跑通（户外）；VoxelGI 方案验证（封闭遗迹）
- [ ] 🔴 VolumetricFog + 指数雾 + 高度雾（云海托底）
- [ ] 🔴 单一 `DirectionalLight3D`「星核之日」+ PSSM 4 split
- [ ] 🟡 自定义 Sky Shader（渐变天幕 + 星陨流光 + 极光带）
- [ ] 🟡 `CompositorEffect` 栈骨架 4 项（ChaosGlitch / DashPhase / SpeedStreaks / ResonancePulse），**每项暴露 `intensity` 且受全局可访问性系数控制**
- [ ] 🟡 Glow 高阈值 + AgX tonemap 配置
- [ ] 🟢 stencil 描边验证（4.5+，用于可交互物/可抓锚点提示）
- [ ] 🟢 `AreaLight3D` 验证（4.7 新节点，用于神龛/共鸣节点发光面）
- [ ] 🔴 **三档画质切换骨架**（Low/High/Ultra），并验证 **Low 档下 THREAT 色与 telegraph 依然清晰**（硬约束）
- [ ] 🔴 可访问性开关：故障强度滑块、镜头抖动减弱、暗角减弱（与画质档**正交**）

## H. 输入系统

- [ ] 🔴 InputMap 定义全部动作（`verb_slash/dash/grapple/leap/parry/resonate`、`move_*`、`ui_*`）
- [ ] 🔴 键鼠 + 手柄双套默认映射（`architecture.md` §8.2 表）
- [ ] 🔴 设备仲裁：用 4.7 的 `DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` + 摇杆死区防漂移
- [ ] 🔴 输入缓冲 ≤6 帧
- [ ] 🔴 优先级裁决 格 > 闪 > 斩（在 InputManager，**不在 FSM**）
- [ ] 🟡 全动作可重映射 UI + `user://input_map.json` 持久化（**独立于存档**）+ 冲突检测
- [ ] 🟡 可访问性输入项：长按↔切换、连点辅助、死区/灵敏度可调
- [ ] 🟢 `Input.set_use_accumulated_input(false)`（延迟优化，配合 CONCERN-B 实测）

## I. 存档

- [ ] 🔴 `src/meta/save_model.gd` —— 纯逻辑序列化/反序列化，schema 按 ADR-004
- [ ] 🔴 原子写：`.tmp` → 校验 → `.bak` 轮转 → `rename`
- [ ] 🔴 `schema_version` + `checksum` + 迁移链骨架 `migrate_N_to_N+1()`
- [ ] 🔴 读档逐字段钳制（`clampi` 池值等，防篡改导致非法状态）
- [ ] 🔴 **单测断言：存档中不含任何 `GameConstants` 常量**（保护 ADR-002 单一真相源）
- [ ] 🟡 `settings.json` / `input_map.json` 与存档分离
- [ ] 🔴 复活流程：**不读盘**（内存复位 + 传送）；传送后调 `reset_physics_interpolation()`；无神龛兜底中枢岛

## J. 测试脚手架

- [ ] 🔴 **gdUnit4 v6.2.x** 以 git submodule 装入 `addons/gdUnit4/`（确认支持 4.7.1）
- [ ] 🔴 `tests/unit/` + `tests/integration/` + `tests/fixtures/` 目录
- [ ] 🔴 `tests/unit/test_constants_match_gdd.gd` —— **硬断言全部 systems-index §2 常量**（一致性门禁）
- [ ] 🔴 `tests/integration/test_cancel_window.gd` —— SceneRunner 逐帧验证第 8 帧可取消、第 9 帧不可
- [ ] 🔴 `ResonancePool.reset_for_test()` 在 `before_test()` 调用，隔离全局状态
- [ ] 🟡 S3 四条 GDD 验收标准的单测（上限不溢出 / 恰扣 40·30 / **池=35 互斥** / 节点 5s cd）
- [ ] 🟡 `tools/` 关卡校验：可达性扫描、死路检测、锚点密度、神龛覆盖
- [ ] 🟢 建立"每个 Story 的 GDD 验收复选框 → 测试文件路径"映射表

## K. CI / DevOps

- [ ] 🔴 `.github/workflows/ci.yml`：checkout(lfs+submodules) → 缓存 Godot 与 `.godot/` → **`--headless --import`** → gdUnit4 跑测试
- [ ] 🔴 **确认 CI 中 `--import` 先于测试执行**（漏掉会导致资源未导入、测试全红）
- [ ] 🟡 `gdlint` 静态检查纳入门禁
- [ ] 🟡 `tools/lint_hex_literals.gd` —— 扫描 `color_tokens.tres` 之外的 hex 颜色字面量
- [ ] 🟡 `tools/lint_magic_numbers.gd` —— 扫描 `src/combat|movement` 中的裸玩法数值
- [ ] 🟢 导出脚本（Windows 主 + Linux）与 Steam 上传流程占位
- [ ] 🟢 每夜任务：关卡校验工具扫描

## L. 性能 Profiler 接入

- [ ] 🔴 `DebugOverlay`（F3）：帧时间曲线、物理 tick 占用、draw call、三角数、粒子实例数、当前状态机状态名、共鸣池值
- [ ] 🔴 **预算超限红字告警**（超 `architecture.md` §7.3 任一预算即高亮）
- [ ] 🔴 建立 3 个固定性能基准场景：①中枢岛静立 ②3 敌战斗 ③Boss 战
- [ ] 🟡 一键性能脚本：跑基准场景 → 输出 CSV → 与基线比对，**回归 >10% 报警**
- [ ] 🟡 在 S0 完成时立刻记录首份性能基线（**不要等内容堆起来才测**）
- [ ] 🟢 Godot 内置 Profiler / Monitors 使用规范写入 README

## M. 编码标准落地

- [ ] 🔴 全项目强制静态类型标注
- [ ] 🔴 路径作用域规则写入 `CLAUDE.md` 或 `CONTRIBUTING.md`：
  - `src/core/**` 热路径零分配
  - `src/combat|movement/**` 数据驱动，**禁玩法数值字面量**
  - `src/ai/**` 状态迁移写环形日志，可调试
  - `src/ui/**`, `scenes/ui/**` **不持有游戏状态**
  - `scenes/**` 禁跨场景 preload 兄弟场景、禁 `get_node("../..")`
- [ ] 🔴 **`_process` 内禁止修改游戏状态或被插值节点的 transform**（写入规范并在 review 中检查）
- [ ] 🟡 signal 过去式命名约定
- [ ] 🟡 注释解释"为什么"而非"做什么"

---

## N. Phase 4 优先 Spike（地基就绪后立即做，按顺序）

- [ ] 🔴 **SPIKE-1 输入延迟实测（CONCERN-B / 缺口 G2）** —— 240 fps 摄像测按键到画面响应；对照 S6 的 <50 ms（键鼠）/<80 ms（手柄）。
      **这是唯一可能推翻 `architecture.md` §3 时间基准决策的风险，必须最先做。** 超标则启用 §7.5 逃生门。
- [ ] 🔴 **SPIKE-2 渲染性能基线（CONCERN-C / 风险 RISK-ENG-1）** —— SDFGI + VolumetricFog 同开在 1660S 级 GPU 的真实成本；验证 4.7 行为与 4.3–4.6 一致。
- [ ] 🔴 **SPIKE-3 手感原型（P1 核心）** —— 斩/闪/跃三动词 + 8 帧取消窗跑通，主观手感确认。**这是全项目最高价值验证。**
- [ ] 🟡 **SPIKE-4 荡索约束求解（ADR-005）** —— 摆荡手感 + 连续荡动量传递 + 脱钩自然滑落。
- [ ] 🟡 **SPIKE-5 stencil 描边 + AreaLight3D** —— 验证 4.5/4.7 新能力在本项目美术方向下的实际效果。

---

## O. 待主理人裁决（不阻塞开工，但需跟踪）

- [x] **CONCERN-A 语义色 hex 冲突** —— ✅ **已裁决 (color-tokens.md v1.0)**：`design/color-tokens.md` v1.0 为唯一权威，色彩来源一律指向 `ColorTokens`（见 F 节 `color_tokens.tres`）。`#2BB6A8`/`#F4B740` 已退役禁用。遗留：文策渊同步 systems-index §2（不阻塞工程）
- [x] **G8 lock-on 摄像机是否做** —— ✅ **已裁决（2026-08-08）：做 lock-on**。`CameraRig` 需含目标锁定层；Dash 方向解算 = 目标相对极坐标解（详见 ADR-003）
- [x] **G5 Steam Deck 是否列 Should** —— ✅ **已裁决（2026-08-08）：v1 不支持**；但画质档下限与 UI 缩放接口**按 Deck 规格预留**
- [x] **G6 共鸣潮汐周期时长** —— ✅ **已收口**：`RESONANCE_TIDE_PERIOD_SEC = 90–120s`
- [ ] **G7 慢动作时音频处理** —— 交阮和鸣
- [ ] **`CANCEL_WINDOW` 不提供可访问性放宽选项**的取舍确认 —— 交文策渊 UX 规格

---

## P. S0 地基出口条件（全部满足才进 S3）

- [ ] ✅ CI 全绿
- [ ] ✅ `test_constants_match_gdd.gd` 通过（常量与 GDD 一致）
- [ ] ✅ 空场景 / 冒烟场景稳定 60 fps，且首份性能基线已记录
- [ ] ✅ 8 个 Autoload 全部就位且顺序正确
- [ ] ✅ `Player.tscn` 可单独运行不崩（缺世界时有 fallback 地面）
- [ ] ✅ SPIKE-1 输入延迟结论已出（无论通过与否，**必须有数据**）
- [ ] ✅ `DebugOverlay` 可显示状态机状态与共鸣池值

> **纪律提醒**：本清单的 🔴 项若跳过，代价会在 Phase 5 以 10 倍返工出现。尤其是 A 组的 tick/插值配置、D 组的 `ResonancePool` 封装、J 组的常量一致性测试——这三处是整个架构的承重墙。
