# Epic E0 · S0 地基 (Foundation)

- **系统**：工程底座（GDD 无编号；DAG 未含但实现顺序强制前置）
- **依赖**：无
- **目标**：满足 `control-checklist.md` §P 的 S0 出口条件，使后续系统可在其上「先写测试」推进。
- **出口**：CI 全绿 ｜ `test_constants_match_gdd` 通过 ｜ 空/冒烟场景稳定 60fps 且首份性能基线已记录 ｜ 8 个 Autoload 就位且顺序正确 ｜ `Player.tscn` 独立可跑不崩 ｜ **SPIKE-1/2 有数据（无论通过与否）** ｜ DebugOverlay 可显示状态机状态与共鸣池值。
- **关联 ADR**：adr-001（引擎）、adr-002（ResonancePool）、adr-004（存档）、adr-005（移动/物理）。
- **承接**：control-checklist.md §A–§M（脚手架）、§N（SPIKE）、§P（出口）。

## 故事清单（12）

### ENG-S0-01 · SPIKE-1 输入延迟实测（CONCERN-B，放行闸门）
- **依据**：architecture.md §7.5 / RISK-PERF-1 / G2；control-checklist §N-SPIKE-1、§P。
- **验收**：
  - [ ] 用 240fps 摄像测「按键 → 画面响应」端到端延迟，键鼠与手柄各取样 ≥30 次。
  - [ ] 产出 `tools/spike/input_latency/<date>.csv`：设备 / 动作 / 帧延迟 / ms。
  - [ ] 对照 S6 红线（键鼠 <50ms / 手柄 <80ms）得出结论；超标则启用 architecture.md §7.5 逃生门并回报。
  - [ ] **S0 出口前必须有数据**，无论通过与否。
- **测试路径**：`tools/spike/input_latency/` + 手动帧分析（见 `test-plan.md` §4）。
- **估算**：M ｜ **优先级 🔴**（架构评审放行条件，排最前）

### ENG-S0-02 · SPIKE-2 渲染性能基线（CONCERN-C，放行闸门）
- **依据**：architecture.md §7 / RISK-ENG-1 / G1；control-checklist §N-SPIKE-2、§P、§L。
- **验收**：
  - [ ] 建渲染冒烟场景（SDFGI + VolumetricFog + 1 CompositorEffect + 中等粒子）。
  - [ ] 建 3 个固定基准场景：①中枢岛静立 ②3 敌战斗 ③Boss 战（同 control-checklist §L）。
  - [ ] 跑 `tools/spike/perf_baseline.gd` → 输出 `tools/spike/perf_baseline/<date>.csv`（CPU/GPU/draw call/三角/粒子）。
  - [ ] 验证 4.7 行为与 4.3–4.6 一致；记录首份基线，S0 出口前完成。
- **测试路径**：`tools/spike/perf_baseline/` + CSV（见 `test-plan.md` §5）。
- **估算**：M ｜ **优先级 🔴**（排最前，与 SPIKE-1 并行）

### ENG-S0-03 · 工程初始化与 project.godot 配置
- **依据**：adr-001；architecture.md §13 附录 A；control-checklist §A。
- **验收**：
  - [ ] Godot 4.7.1-stable 标准构建（非 .NET）；版本写入 `README.md` 与 CI `GODOT_VERSION`（单点声明）。
  - [ ] `rendering/renderer/rendering_method=forward_plus`。
  - [ ] `physics/common/physics_ticks_per_second=60`（**1 tick ≡ GDD 1 帧**）。
  - [ ] `physics/common/physics_interpolation=true`。
  - [ ] `physics/3d/physics_engine="Jolt Physics"`。
  - [ ] Windows 图形 API = D3D12；记录 Vulkan 回退 `--rendering-driver vulkan`。
- **测试路径**：`tests/unit/test_project_settings.gd`（断言关键 setting）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S0-04 · 目录结构与版本控制
- **依据**：control-checklist §B、§C。
- **验收**：
  - [ ] 按 architecture.md §2.1 建 `autoloads/ src/ scenes/ resources/ shaders/ tests/ tools/ art/ audio/`。
  - [ ] `src/`（纯逻辑）与 `scenes/`（节点接线）严格分离。
  - [ ] `git init`；`.gitignore` 含 `.godot/ export/ *.tmp`；**`*.import` 入库**；Git LFS 配 `art/ audio/`。
  - [ ] 分支约定：`main` 恒可运行 + `feat/<story-id>`；Story 级走 PR。
- **测试路径**：CI 脚本断言目录存在（`tools/ci_check_dirs.gd` 或 bash）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S0-05 · 8 个 Autoload 单例接线
- **依据**：adr-002、adr-004；architecture.md §4.1/§5.2；control-checklist §D。
- **验收**（顺序即依赖顺序，不可颠倒）：
  - [ ] 1 `GameConstants`（systems-index §2 常量全抄，含 `SOURCE_OF_TRUTH` 指向 GDD）。
  - [ ] 2 `EventBus`（§5.2 全部 signal，过去式命名，无状态无逻辑无 `_process`）。
  - [ ] 3 `ResonancePool`（adr-002：`_current` 私有、无 setter、`try_spend()`/`add()`/`reset_for_test()`）。
  - [ ] 4 `SaveManager`（adr-004：版本化 JSON、原子写、checksum、`.bak`、逐字段钳制）。
  - [ ] 5 `InputManager`（动作映射、4.7 设备 ID 仲裁、≤6 帧缓冲、优先级 格>闪>斩）。
  - [ ] 6 `AudioDirector`（Master/Music/SFX/UI/Ambience 总线骨架）。
  - [ ] 7 `EchoDirector`（S7 占位）。
  - [ ] 8 `DebugOverlay`（F3 切换；release 经 feature tag 剥离）。
  - [ ] 新增任何 Autoload 前对照「全局唯一 + 跨场景存活 + ≥3 系统消费」三条红线。
- **测试路径**：`tests/unit/test_autoload_wiring.gd`（断言 8 个单例就绪且顺序）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-06 · 核心基类与场景骨架
- **依据**：adr-003（FSM）、adr-005；architecture.md §4.3/§4.4；control-checklist §E。
- **验收**：
  - [ ] `src/core/state.gd`：`frames_in_state`、`cancel_open_at_frame`、`is_cancellable()` 单点实现。
  - [ ] `src/core/state_machine.gd`：`try_transition()` 唯一转移入口，含 hitstun 拒绝、`can_enter()` 校验、状态事件广播。
  - [ ] `Player.tscn` 骨架：`CharacterBody3D` + `StateMachine` + 8 状态节点 + Hitbox/Hurtbox（缺世界时有 fallback 地面）。
  - [ ] `CameraRig` 独立于 Player，在 `_process` 跟随（不放 `_physics_process`）。
  - [ ] `Boot.tscn` 为 main；`Main` 含 `WorldRoot/PlayerRoot/CameraRig/UILayer`。
- **测试路径**：`tests/integration/test_cancel_window.gd`（SceneRunner 逐帧：第 8 帧可取消、第 9 帧不可）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-07 · 资源管线基类（数据驱动）
- **依据**：architecture.md §4.2/§4.6/§9；control-checklist §F。
- **验收**：
  - [ ] `resources/constants/game_constants.tres`（systems-index §2 全集）。
  - [ ] `resources/colors/color_tokens.tres` 按 `design/color-tokens.md` v1.0（**唯一语义色真相源，优先级高于 systems-index §2 与美术圣经 §2**）全量落值，含以下 7 个 Token：
    - `THREAT` = `#A62C6B`（mandated 不可变，仅敌/混沌）
    - `PLAYER_ALLY_MAIN` / `FRIENDLY_TEAL` = `#5FD2C8`（星辉青，退役旧 `#2BB6A8`）
    - `FRIENDLY_GOLD` = `#F2C15E`（暖金，退役旧 `#F4B740`；注：主理人摘要表写作 `FRIENDLY_AMBER`，以 color-tokens.md v1.0 的 `FRIENDLY_GOLD` 为权威名）
    - `FRIENDLY_CORAL` = `#FF8A65`
    - `RESONANCE_GLOW` = `#9FF7E8`（青白 emissive 发光态，与 `PLAYER_ALLY_MAIN` 是基色 vs 发光态两 Token，非冲突）
    - `DAMAGE_WARN` = `#E5484D`（**新增**：受击/危险区/低血闪，取代原先误用 THREAT 的场景；守 THREAT 仅敌/混沌铁律）
    - `UI_BG` = `#1A2233`（**新增**：UI 底）
  - [ ] `color_tokens_cvd.tres`（色盲第二套，运行时热切换）**同步补 `DAMAGE_WARN` 字段**（其余 Token 随 Normal 套同步）。
  - [ ] `VerbDefinition` 资源类 + 6 动词 `.tres`（帧数/位移/伤害/cd/取消窗开启帧）。
  - [ ] `EnemyDefinition` 资源类 + 3 原型 `.tres`（telegraph 以帧存储：Normal 36–72、Hard 24–48）。
  - [ ] `color_tokens_cvd.tres`（色盲第二套，运行时热切换）。
- **测试路径**：`tests/unit/test_constants_match_gdd.gd`（硬断言全部 systems-index §2 常量）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-08 · 渲染管线骨架
- **依据**：architecture.md §6；control-checklist §G。
- **验收**：
  - [ ] `resources/env/base_env.tres`（WorldEnvironment 基线）。
  - [ ] SDFGI 跑通（户外）；VoxelGI 方案验证（封闭遗迹）。
  - [ ] VolumetricFog + 指数雾 + 高度雾（云海托底）。
  - [ ] 单一 `DirectionalLight3D`「星核之日」+ PSSM 4 split。
  - [ ] `CompositorEffect` 栈骨架 4 项（ChaosGlitch/DashPhase/SpeedStreaks/ResonancePulse），每项暴露 `intensity` 且受全局可访问性系数控制。
  - [ ] **三档画质切换骨架**（Low/High/Ultra）；**Low 档下 THREAT 色与 telegraph 仍清晰**（硬约束）。
  - [ ] 可访问性开关：故障强度滑块、镜头抖动减弱、暗角减弱（与画质档正交）。
- **测试路径**：`tests/integration/test_render_tiers.gd`（断言三档切换 + Low 档 telegraph 可见性）。
- **估算**：L ｜ **优先级 🟡**

### ENG-S0-09 · 输入系统
- **依据**：architecture.md §8；control-checklist §H。
- **验收**：
  - [ ] InputMap 定义全部动作（`verb_slash/dash/grapple/leap/parry/resonate`、`move_*`、`ui_*`）。
  - [ ] 键鼠 + 手柄双套默认映射。
  - [ ] 设备仲裁：4.7 `DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` + 摇杆死区防漂移。
  - [ ] 输入缓冲 ≤6 帧；优先级裁决 格>闪>斩（在 InputManager，不在 FSM）。
  - [ ] `Input.set_use_accumulated_input(false)`（延迟优化，配合 CONCERN-B）。
- **测试路径**：`tests/unit/test_input_buffer.gd`、`test_device_arbitration.gd`。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-10 · 存档骨架
- **依据**：adr-004；control-checklist §I。
- **验收**：
  - [ ] `src/meta/save_model.gd` 纯逻辑序列化/反序列化（schema 按 adr-004）。
  - [ ] 原子写：`.tmp` → 校验 → `.bak` 轮转 → `rename`。
  - [ ] `schema_version` + `checksum` + 迁移链骨架 `migrate_N_to_N+1()`。
  - [ ] 读档逐字段钳制（`clampi` 池值等）。
  - [ ] **单测断言：存档中不含任何 `GameConstants` 常量**（保护 ADR-002 单一真相源）。
  - [ ] 复活流程：不读盘（内存复位 + 传送）；传送后 `reset_physics_interpolation()`；无神龛兜底中枢岛。
- **测试路径**：`tests/unit/test_save_atomic.gd`、`test_save_clamp.gd`、`test_save_no_constants.gd`。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-11 · 测试脚手架与 CI
- **依据**：architecture.md §11；control-checklist §J、§K。
- **验收**：
  - [ ] **gdUnit4 v6.2.x** 以 git submodule 装入 `addons/gdUnit4/`（支持 4.7.1）。
  - [ ] `tests/unit/` + `tests/integration/` + `tests/fixtures/` 目录。
  - [ ] `ResonancePool.reset_for_test()` 在 `before_test()` 调用，隔离全局状态。
  - [ ] `.github/workflows/ci.yml`：checkout(lfs+submodules) → 缓存 Godot 与 `.godot/` → `--headless --import` → gdUnit4 跑测试。
  - [ ] **确认 CI 中 `--import` 先于测试**（漏掉测试全红）。
  - [ ] `gdlint` 纳入门禁；`tools/lint_hex_literals.gd` + `tools/lint_magic_numbers.gd`。
- **测试路径**：CI 本身即门禁；`tests/unit/test_constants_match_gdd.gd` 为一致性门禁。
- **估算**：M ｜ **优先级 🔴**

### ENG-S0-12 · 性能 Profiler 接入与编码标准
- **依据**：architecture.md §7.6/§11.4；control-checklist §L、§M。
- **验收**：
  - [ ] `DebugOverlay`（F3）：帧时间曲线、物理 tick 占用、draw call、三角数、粒子实例数、当前状态机状态名、共鸣池值。
  - [ ] **预算超限红字告警**（超 architecture.md §7.3 任一即高亮）。
  - [ ] 建立 3 个固定性能基准场景（同 ENG-S0-02）。
  - [ ] 一键性能脚本：跑基准 → CSV → 与基线比对，回归 >10% 报警。
  - [ ] 全项目强制静态类型；路径作用域规则写入 `CLAUDE.md`；`_process` 内禁改游戏状态/被插值节点 transform。
- **测试路径**：`tools/perf_report.gd`；`gdlint` 静态门禁。
- **估算**：M ｜ **优先级 🔴**

## S0 出口自检（来自 control-checklist §P，转可执行见 test-plan.md §6）
CI 全绿 ｜ 常量一致性测试通过 ｜ 空场景稳定 60fps + 首份基线 ｜ 8 Autoload 就位且顺序对 ｜ Player.tscn 独立可跑 ｜ SPIKE-1/2 有数据 ｜ DebugOverlay 可见状态机状态与共鸣池值。
