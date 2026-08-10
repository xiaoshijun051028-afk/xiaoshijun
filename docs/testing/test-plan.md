# 测试框架脚手架规划 · 星陨之境 (Aetherfall)

> 版本 v1.0 ｜ 作者 程基岩 ｜ 引擎 Godot 4.7.1-stable ｜ 框架 gdUnit4 v6.2.x
> 依据：`docs/architecture/architecture.md` §11、`adr-001..005`、`control-checklist.md` §J/§K/§L/§N/§P
> 下游：`production/epics/`、`docs/testing/` CI、性能基线
> 范围：Phase 4 预制作测试脚手架 + 早期放行 Spike + S0 出口定义 + GDD §⑦ 验收落地 + Sprint 1 草案

---

## 0. 总览与纪律

- **先写测试**：每个 Story 实现前先落断言。GDD §⑦ 的每个复选框必须能指向一个测试文件路径，否则该 Story 不算完成（architecture.md §11.2）。
- **确定性优先**：因 §3 把「帧」定义为物理 tick（60Hz），所有帧级断言为**确定性**，不 flaky。
- **三层通信**：L1 本地调用 / L2 EventBus 信号 / L3 权威查询；测试只验 L1+L2 行为，不依赖渲染像素。
- **放行闸门**：CONCERN-B（输入延迟）/ CONCERN-C（性能基线）的 Spike 排最前，S0 出口前必须有数据。

---

## 1. gdUnit4 接入步骤（支持 Godot 4.7.1）

> 核验（2026-08-08）：gdUnit4 **v6.2.x**（master）明确支持 v4.7 / v4.7.1；v6.1.x 仅到 4.6.3。务必锁 v6.2.x。

### 1.1 步骤
1. `git submodule add https://github.com/MikeSchulze/gdUnit4.git addons/gdUnit4`（锁定 commit 对应 v6.2.x）。
2. Godot 编辑器 → Project → Project Settings → Plugins → 启用 `gdUnit4`。
3. 编辑器内生成测试：`right-click script → Create Test`（生成 `tests/unit/<name>.gd` 骨架）。
4. CLI 跑全量：`godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/`。
5. 报告导出：`--report-dir logs/` 供 CI 归档。

### 1.2 目录约定
```
tests/
  unit/          纯逻辑，无场景（ResonancePool / SaveModel / 常量 / 输入缓冲）
  integration/   SceneRunner 帧级（cancel_window / iframes / parry / boss / gate / respawn）
  fixtures/      测试用 .tscn / .tres（最小 Player、占位锚点源、假敌人）
  tools/         关卡校验 / 性能 / spike 脚本（非 gdUnit，独立 CLI）
```
- 命名：`test_<被测>.gd`；一个被测类一个测试文件。
- 全局状态隔离：每个 `*_test.gd` 的 `before_test()` 调 `ResonancePool.reset_for_test()` 与 `GameConstants` 无副作用断言。
- 帧级测试一律用 `runner.simulate_frames(n)`（见 §11.2 示例），禁止 `await` 真实时间。

### 1.3 关键 API 速记（4.7.1 兼容）
```gdscript
var runner := scene_runner("res://scenes/player/Player.tscn")
runner.invoke_input_action("verb_slash")
runner.simulate_frames(GameConstants.CANCEL_WINDOW)
runner.invoke_input_action("verb_dash")
runner.simulate_frames(1)
assert_str(runner.get_property("state_machine").current_state_name).is_equal("Dash")
```

---

## 2. CI（GitHub Actions）yml 大纲

```yaml
# .github/workflows/ci.yml
name: CI
env:
  GODOT_VERSION: "4.7.1"
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true, submodules: recursive }   # gdUnit4 为 submodule
      - name: Cache Godot binary + .godot import cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.local/share/godot
            .godot/
          key: godot-${{ env.GODOT_VERSION }}-${{ hashFiles('project.godot') }}
      - name: Import assets (MUST run before tests)
        run: godot --headless --import --quit-after 200   # 漏掉 → 资源未导入 → 测试全红
      - name: Run gdUnit4
        run: godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ --report-dir logs/
      - name: Static lint gate
        run: |
          pip install gdtoolkit && gdlint src/   # gdlint 门禁
          godot --headless -s tools/lint_hex_literals.gd
          godot --headless -s tools/lint_magic_numbers.gd
      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v4
        with: { name: gdunit-report, path: logs/ }
  nightly-level-scan:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 3 * * *'
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true, submodules: recursive }
      - run: godot --headless --import --quit-after 200
      - run: godot --headless -s tools/level_scan.gd   # 0 死路 / 可达比 / 神龛覆盖
```

- Godot 4 标准二进制自带 `--headless`，CI 无需 Xvfb。
- **门禁顺序**：`--import` → 测试 → `gdlint` + 自研 lint。**常量一致性测试 `test_constants_match_gdd` 为硬性门禁**（架构承重墙）。
- 每夜任务跑 `tools/level_scan.gd`（死路/可达比/神龛覆盖）。

---

## 3. 早期 Spike 放行方案

> 架构评审放行条件：CONCERN-B / CONCERN-C 的 Spike **必须排最前**，S0 出口前**必须有数据**（无论通过与否）。

### 3.1 SPIKE-1 输入延迟实测（CONCERN-B / G2）
- **风险**：唯一可能推翻 architecture.md §3 时间基准决策（60Hz tick + 插值）的风险。
- **设备**：240fps 高速摄像（或 `Elgato 4K60 Pro` + OBS 240fps 录制）正对屏幕。
- **方法**：
  1. 用 `tools/spike/input_latency/harness.gd` 显示明确视觉触发（按键 → 画面角色起跳/攻击）。
  2. 键鼠：物理按键（机械开关信号）与屏幕像素变化用同一时间轴对齐（摄像同时拍键盘 LED + 屏幕）。
  3. 手柄：手柄按键 LED + 屏幕同拍。
  4. 每设备 / 每动作取样 ≥30 次；记录「按键边沿 → 画面响应」帧数 → ms（240fps → 每帧 ≈4.17ms）。
- **判定**：键鼠 <50ms、手柄 <80ms（S6 红线）。超标 → 启用 architecture.md §7.5 逃生门（`Input.set_use_accumulated_input(false)`、降低插值、或回退更高频逻辑），并回报修订 §3。
- **产出**：`tools/spike/input_latency/<date>.csv` + `docs/testing/spike-input-latency.md` 结论。
- **归属**：`ENG-S0-01`（见 `production/epics/epic-s0-foundation.md`）。

### 3.2 SPIKE-2 渲染性能基线（CONCERN-C / RISK-ENG-1）
- **目标**：SDFGI + VolumetricFog 同开在 1660S 级 GPU 的真实成本；验证 4.7 行为与 4.3–4.6 一致。
- **场景**（3 固定基准，同 control-checklist §L）：
  - ① `tools/spike/perf_baseline/scene_hub.tscn` —— 中枢岛静立
  - ② `tools/spike/perf_baseline/scene_combat.tscn` —— 3 敌战斗
  - ③ `tools/spike/perf_baseline/scene_boss.tscn` —— Boss 战
  - 冒烟：`scene_smoke.tscn`（SDFGI + VolumetricFog + 1 CompositorEffect + 中等粒子）先于三者跑通。
- **脚本**：`tools/perf_report.gd` —— 进场景跑 N 秒 → 采 CPU/GPU ms、draw call、三角数、粒子实例数 → 写 `tools/spike/perf_baseline/<date>.csv`。
- **基线**：S0 完成即刻记录首份基线（不要等内容堆起来才测）；后续回归 >10% 报警（control-checklist §L）。
- **预算对照**：architecture.md §7.3（CPU≤9ms / GPU≤15ms / draw≤1500 / 三角≤2M / 粒子≤30k）。
- **归属**：`ENG-S0-02`。

---

## 4. S0 出口条件（来自 control-checklist §P，转可执行定义）

| # | control-checklist §P 条目 | 可执行定义 / 验证方式 |
|---|---|---|
| 1 | CI 全绿 | `ci.yml` 全 job 通过（测试 + gdlint + hex/magic lint） |
| 2 | `test_constants_match_gdd` 通过 | 单测断言全部 systems-index §2 常量（硬门禁） |
| 3 | 空/冒烟场景稳定 60fps + 首份基线 | `scene_smoke` 60fps；`perf_baseline/<date>.csv` 已生成 |
| 4 | 8 Autoload 就位且顺序对 | `test_autoload_wiring.gd` 断言 8 单例就绪且顺序 |
| 5 | `Player.tscn` 独立可跑不崩 | `test_player_standalone.gd`（无世界 fallback 地面，跑 60 tick 无错） |
| 6 | **SPIKE-1 有数据** | `input_latency/<date>.csv` 存在 + 结论文档 |
| 7 | **SPIKE-2 有数据** | `perf_baseline/<date>.csv` 存在 |
| 8 | DebugOverlay 可见状态机+池值 | 手动/F3 截图；`test_debug_overlay.gd` 断言面板含状态名与池值字段 |

> 出口 6/7 为**放行闸门**：无论 CONCERN-B/C 是否通过，必须有数据才能进 S3。

---

## 5. GDD §⑦ 验收标准测试清单（落地层）

> GDD §⑦ 跨 8 系统共 **33 条**验收复选框（架构评审 §9 记 24 为早期按系统分组计数；本表按逐条落地覆盖全部 33 条）。每条映射：层 / 测试文件 / 归属 Story。
> 层图例：U=单元 / I=集成(SceneRunner) / T=工具扫描 / M=人工录像。

| AC-ID | 系统 | GDD §⑦ 复选框 | 层 | 测试文件 | 归属 Story |
|---|---|---|---|---|---|
| AC-S3-01 | S3 | 池上限严格 100 不溢出 | U | `test_resonance_pool.gd` | ENG-S3-01 |
| AC-S3-02 | S3 | 恰扣 40 / 30 | U | `test_resonance_pool.gd` | ENG-S3-01 |
| AC-S3-03 | S3 | 池=35 开门可/终结技不可（互斥） | U | `test_resonance_pool.gd` | ENG-S3-02 |
| AC-S3-04 | S3 | 节点 5s cd 内不二次增益 | U | `test_resonance_node_cd.gd` | ENG-S3-03 |
| AC-S1-01 | S1 | 任意两动词取消延迟 ≤8 帧 | I | `test_cancel_window.gd` | ENG-S1-02 |
| AC-S1-02 | S1 | 连段中断率 <5%（20 人） | M | `playtest-combat.md` | ENG-S1-06 |
| AC-S1-03 | S1 | 完美格 → 慢动作 + 硬直 ≥1s | I | `test_parry_stagger.gd` | ENG-S1-04 |
| AC-S1-04 | S1 | 共鸣不足终结技不可 + HUD 灰显 | I | `test_finisher_lockout.gd` | ENG-S1-05 |
| AC-S1-05 | S1 | 闪 iframes 期间 0 伤害 | I | `test_iframes_zero_damage.gd` | ENG-S1-03 |
| AC-S2-01 | S2 | 单岛可达高点数/体积比 ≥0.6 | T | `tools/level_scan.gd` | ENG-S2-06 |
| AC-S2-02 | S2 | ≥1 纯空中路线绕敌 | T | `tools/level_scan.gd` | ENG-S2-06 |
| AC-S2-03 | S2 | 跃→闪→斩 ≤8 帧 | I | `test_leap_dash_cancel.gd` | ENG-S2-03 |
| AC-S2-04 | S2 | 越界坠落 100% 神龛复活无卡死 | I | `test_fall_respawn.gd` | ENG-S2-05 |
| AC-S4-01 | S4 | 所有攻击 100% THREAT telegraph + 音效 | I | `test_telegraph_threat.gd` | ENG-S4-02 |
| AC-S4-02 | S4 | 完美格 100% 破防硬直 ≥1s | I | `test_parry_stagger.gd` | ENG-S4-04 |
| AC-S4-03 | S4 | Sentinel 弱点 ≈ 非弱点 x2 (±5%) | U | `test_sentinel_weakpoint.gd` | ENG-S4-03 |
| AC-S4-04 | S4 | Boss 阶段切换无即死 | I | `test_boss_phase_switch.gd` | ENG-S4-05 |
| AC-S5-01 | S5 | 每岛可达高点数/体积比 ≥0.6 | T | `tools/level_scan.gd` | ENG-S5-06 |
| AC-S5-02 | S5 | 每岛 ≥1 纯空中路线绕敌 | T | `tools/level_scan.gd` | ENG-S5-06 |
| AC-S5-03 | S5 | 0 逻辑死路 | T | `tools/level_scan.gd` | ENG-S5-06 |
| AC-S5-04 | S5 | 神龛覆盖每岛 + 复活落点有效 | T | `tools/level_scan.gd` | ENG-S5-06 |
| AC-S6-01 | S6 | HUD 仅 5 类元素 | I | `test_hud_elements.gd` | ENG-S6-01 |
| AC-S6-02 | S6 | 共鸣三态色（≥40/≥30/<30） | I | `test_hud_resonance_states.gd` | ENG-S6-02 |
| AC-S6-03 | S6 | 威胁标记 100% 对应 telegraph | I | `test_hud_threat_marker.gd` | ENG-S6-03 |
| AC-S6-04 | S6 | 键鼠 + 手柄均可核心循环 | I/M | `test_dual_device_core_loop.gd` | ENG-S6-04 |
| AC-S7-01 | S7 | 所有节点可触发且 +10 池正确 | I | `test_echo_node_trigger.gd` | ENG-S7-01 |
| AC-S7-02 | S7 | 残响收集计入发现进度 | I | `test_echo_collection.gd` | ENG-S7-02 |
| AC-S7-03 | S7 | 5s cd 内不重复增益 | I | `test_echo_node_cd.gd` | ENG-S7-03 |
| AC-S7-04 | S7 | 战斗中触发不卡输入 | I | `test_echo_no_input_lock.gd` | ENG-S7-04 |
| AC-S8-01 | S8 | 存档/读档 100% 还原 | U | `test_save_roundtrip.gd` | ENG-S8-01 |
| AC-S8-02 | S8 | 死亡 100% 神龛复活保留收集 | I | `test_respawn.gd` | ENG-S8-02 |
| AC-S8-03 | S8 | 技能树效果应用 S1/S2/S3 | I | `test_skilltree_apply.gd` | ENG-S8-05 |
| AC-S8-04 | S8 | 写盘失败不崩溃 | U | `test_save_failure.gd` | ENG-S8-03 |

**覆盖统计**：33/33（100%）。自动化可达 30 条（U+I+T），3 条为人工/录像层（AC-S1-02 中断率、AC-S6-04 双设备主观、AC-S2/S5 部分需内容就绪后工具层复核）。无 FAIL 缺口。

---

## 6. Sprint 1 草案 = S0 地基 + S3 共鸣池垂直切片

> 目标：**可玩核心循环最小验证**——玩家按共鸣节点（占位）→ 池增长 → 池≥40 放终结技（占位敌人）扣池；验证「单一共享池驱动解谜+战斗」的 P4 支柱在架构层成立。

### 6.1 Sprint 1 Story 顺序（依赖闭环）
1. **ENG-S0-01** SPIKE-1 输入延迟（放行闸门，并行）
2. **ENG-S0-02** SPIKE-2 性能基线（放行闸门，并行）
3. **ENG-S0-03** 工程初始化 + project.godot
4. **ENG-S0-04** 目录结构 + VCS
5. **ENG-S0-05** 8 Autoload 单例（含 ResonancePool / GameConstants / EventBus）
6. **ENG-S0-07** 资源管线基类（game_constants.tres / color_tokens.tres）
7. **ENG-S0-09** 输入系统（InputMap 双套 + 缓冲 + 仲裁）
8. **ENG-S0-06** 核心基类 + Player.tscn 骨架 + CameraRig（cancel_window 集成测试跑通）
9. **ENG-S0-11** 测试脚手架 + CI（gdUnit4 + ci.yml + 常量一致性测试）
10. **ENG-S0-10** 存档骨架（为 S3 后续存档铺垫，本 Sprint 仅骨架）
11. **ENG-S0-12** DebugOverlay + 性能接入
12. **ENG-S3-01** 池核心数学与上限（单测）
13. **ENG-S3-02** 互斥消耗（单测）
14. **ENG-S3-03** 节点共鸣 +10 与 5s cd（单测）
15. **ENG-S3-04** 扣费/增益入口 + EventBus 广播（集成）
16. **ENG-S1-05**（轻量占位）终结技扣费验证——用占位敌人/节点触发 `try_spend(40)` 验证 P4 互斥端到端

> 注：ENG-S0-08（渲染管线）为 🟡，可在 Sprint 1 末尾或 Sprint 2 开头补；SPIKE-3/4/5 属后续 Sprint。

### 6.2 Sprint 1 退出标准
- [ ] SPIKE-1/2 有数据（csv + 结论），无论通过与否。
- [ ] CI 全绿；`test_constants_match_gdd` 通过。
- [ ] `test_cancel_window.gd` 第 8 帧可取消 / 第 9 帧不可（确定性）。
- [ ] S3 四条单测（AC-S3-01..04）全绿。
- [ ] **垂直切片可玩**：占位场景中，节点共鸣 +10（cd 5s）→ 池≥40 时终结技扣 40 → HUD（占位）三态正确，验证 P4 互斥端到端。
- [ ] 空/冒烟场景稳定 60fps + 首份性能基线已记录。

### 6.3 风险与依赖
- SPIKE-1 若超标 → 触发 §3 时间基准逃生门（架构评审最高风险，已排最前）。
- S3 单测依赖 `ResonancePool.reset_for_test()`（ENG-S0-05）与 gdUnit4（ENG-S0-11）先就位——故 S0 脚手架必须在 S3 前完成。
- CONCERN-A 语义色：Sprint 1 内 `color_tokens.tres` 暂用 systems-index 值，待主理人裁决后单字段替换。

---

## 7. 待主理人裁决（不阻塞，但需跟踪）
- **CONCERN-A** 语义色 hex 冲突（RESONANCE_GLOW / teal / amber）—— 裁决后改 `color_tokens.tres` 单字段。
- **G5** Steam Deck 是否列 Should（影响画质档下限与 UI 缩放）。
- **G8** lock-on 摄像机是否做（影响 CameraRig 与 Boss 可读性，建议早决）。
- **G6/G7** 共鸣潮汐周期 / 慢动作音频处理（交林绘澄 / 阮和鸣）。
