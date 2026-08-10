# Sprint 1 计划 · 星陨之境 (Aetherfall)

> 版本 v1.0 ｜ 主理人汇编：游承峰 ｜ 日期 2026-08-08 ｜ 评审强度 Solo
> 汇编来源：`design/ux/ux-spec.md`（文策渊）、`design/art/asset-spec.md`（林绘澄）、`production/epics/*.md` + `docs/testing/test-plan.md`（程基岩）
> 上游门控：Phase 3 架构评审 PASS ｜ Phase 4 预制作 PASS（见 `design/phase4-assembly.md`）

---

## 1. Sprint 目标（一句话）

**用最小代价证明支柱 P4「共鸣统一」在架构层成立**：玩家触发共鸣节点 → 池增长 → 池量决定「开门」与「终结技」互斥可用性，端到端跑通。

这是一次**功能性垂直切片**，不是美术切片。视觉全部用 blockout 占位，最终 stylized 资产按 `asset-spec.md` 另案生产。

### 为什么先切 P4 而不是先切战斗手感
P4 是四大支柱里**唯一横跨解谜与战斗**的机制，也是唯一一个"设计上说得通、但工程上可能塌"的假设：单一共享池要同时服务两套子系统且天然互斥。若它站不住，S1/S5/S7/S8 全要重设计。**先证伪成本最高的假设**——这是本 Sprint 的编排逻辑。

---

## 2. 范围

### 2.1 In Scope（16 Story）

| # | Story ID | 名称 | 估算 | 优先级 | Epic |
|---|---|---|---|---|---|
| 1 | ENG-S0-01 | SPIKE-1 输入延迟实测 | M | 🔴 放行闸门 | E0 |
| 2 | ENG-S0-02 | SPIKE-2 渲染性能基线 | M | 🔴 放行闸门 | E0 |
| 3 | ENG-S0-03 | 工程初始化 + project.godot | S | 🔴 | E0 |
| 4 | ENG-S0-04 | 目录结构 + 版本控制 | S | 🔴 | E0 |
| 5 | ENG-S0-05 | 8 Autoload 单例接线 | M | 🔴 | E0 |
| 6 | ENG-S0-07 | 资源管线基类（数据驱动） | M | 🔴 | E0 |
| 7 | ENG-S0-09 | 输入系统 | M | 🔴 | E0 |
| 8 | ENG-S0-06 | 核心基类 + Player.tscn + CameraRig | M | 🔴 | E0 |
| 9 | ENG-S0-11 | 测试脚手架 + CI | M | 🔴 | E0 |
| 10 | ENG-S0-10 | 存档骨架 | M | 🔴 | E0 |
| 11 | ENG-S0-12 | DebugOverlay + 性能接入 | M | 🔴 | E0 |
| 12 | ENG-S3-01 | 池核心数学与上限钳制 | S | 🔴 | E3 |
| 13 | ENG-S3-02 | 互斥消耗（P4 核心） | S | 🔴 | E3 |
| 14 | ENG-S3-03 | 节点共鸣 +10 与 5s cd | S | 🔴 | E3 |
| 15 | ENG-S3-04 | 扣费/增益入口 + EventBus 广播 | S | 🟡 | E3 |
| 16 | ENG-S1-05（轻量占位） | 终结技扣费端到端验证 | S | 🔴 | E1 |

**估算分布**：S×6 ｜ M×10 ｜ L×0（估算口径来自程基岩，主理人不改写工程判断）

### 2.2 条件性纳入
- **ENG-S0-08 渲染管线骨架**（L ｜ 🟡）：Sprint 1 末尾有余量则做，否则顺延 Sprint 2 开头。**不列入退出标准**，避免为赶美术骨架牺牲地基质量。

### 2.3 Out of Scope（明确排除，防范围蔓延）
- 任何最终美术资产（模型/材质/VFX/Shader 成品）
- S2 移动、S4 敌人 AI、S5 世界、S6 完整 HUD、S7 叙事、S8 元进度的正式实现
- lock-on 摄像机功能实现（**G8 已拍板要做**，但排 Sprint 2；本 Sprint 仅在 `CameraRig` 与 InputMap 预留 `verb_lockon` 动作与接口位）
- Steam Deck 适配（**G5 已拍板：v1 不支持，架构预留**）

---

## 3. 执行顺序与并行策略

```
并行起跑 ──┬─ ENG-S0-01 SPIKE-1（输入延迟）  ← 放行闸门，最高风险
           └─ ENG-S0-02 SPIKE-2（性能基线）  ← 放行闸门

串行主链 ── S0-03 工程初始化
            └→ S0-04 目录/VCS
               └→ S0-05 8 Autoload      ← ResonancePool / GameConstants / EventBus 就位
                  └→ S0-07 资源管线      ← game_constants.tres / color_tokens.tres
                     └→ S0-09 输入系统
                        └→ S0-06 核心基类 + Player.tscn + CameraRig
                           └→ S0-11 测试脚手架 + CI   ← 此后一切"先写测试"
                              ├→ S0-10 存档骨架
                              └→ S0-12 DebugOverlay + 性能接入

S3 段（依赖 S0-05 + S0-11 就位）
   S3-01 池数学 → S3-02 互斥 → S3-03 节点 cd → S3-04 EventBus 广播
                                                  └→ S1-05 占位：终结技扣费端到端
```

**两个 SPIKE 必须最先起跑且并行**：它们是架构评审的放行闸门，且 SPIKE-1 的结论可能推翻 §3 时间基准决策——越晚发现返工越贵。

---

## 4. 退出标准

### 4.1 S0 出口（8 条，来自 `control-checklist §P` / `test-plan.md §4`）
- [ ] CI 全绿（测试 + gdlint + hex/magic-number lint 全通过）
- [ ] `test_constants_match_gdd` 通过（硬门禁：断言全部 systems-index §2 常量）
- [ ] 空/冒烟场景稳定 60fps，且 `perf_baseline/<date>.csv` 已生成
- [ ] 8 个 Autoload 就位**且顺序正确**（`test_autoload_wiring.gd`）
- [ ] `Player.tscn` 独立可跑不崩（无世界时 fallback 地面，跑 60 tick 无错）
- [ ] **SPIKE-1 有数据**（`input_latency/<date>.csv` + 结论文档）—— 无论通过与否
- [ ] **SPIKE-2 有数据**（`perf_baseline/<date>.csv`）—— 无论通过与否
- [ ] DebugOverlay（F3）可见状态机状态名与共鸣池值

### 4.2 Sprint 1 专有出口
- [ ] `test_cancel_window.gd`：第 8 帧可取消 / 第 9 帧不可（确定性，守 `CANCEL_WINDOW=8f`）
- [ ] S3 四条 GDD 验收单测全绿：**AC-S3-01 ~ AC-S3-04**
- [ ] **垂直切片可玩**：占位场景中「节点共鸣 +10（5s cd）→ 池 ≥40 → 终结技扣 40」端到端跑通，占位 HUD 三态正确 —— **即 P4 互斥成立**

### 4.3 本 Sprint 覆盖的 GDD 验收（`test-plan.md §5`）

| AC-ID | 验收内容 | 层 | 测试文件 |
|---|---|---|---|
| AC-S3-01 | 池上限严格 100 不溢出 | U | `test_resonance_pool.gd` |
| AC-S3-02 | 恰扣 40 / 30 | U | `test_resonance_pool.gd` |
| AC-S3-03 | 池=35 开门可 / 终结技不可（**互斥**） | U | `test_resonance_pool.gd` |
| AC-S3-04 | 节点 5s cd 内不二次增益 | U | `test_resonance_node_cd.gd` |
| AC-S1-04（部分） | 共鸣不足终结技不可 + HUD 灰显 | I | `test_finisher_lockout.gd` |

> 全项目 33 条验收中本 Sprint 闭合 4 条 + 1 条部分。**AC-S3-03 是 P4 支柱的唯一硬证据**，它绿了这个 Sprint 才算成功。

---

## 5. 工程纪律（不可协商）

- **先写测试**：验证驱动开发，测试先于实现。
- **单一真相源**：所有常量走 `GameConstants`，语义色走 `ColorTokens`（源 `design/color-tokens.md` v1.0）。**禁止 hex 字面量与魔法数字**，由 `tools/lint_hex_literals.gd` / `lint_magic_numbers.gd` 在 CI 拦截。
- **`ResonancePool` 无 setter**：`_current` 私有，唯一入口 `try_spend(cost, reason)` / `add()`。这条不是代码风格——它是**用架构强制 P4 互斥**，任何绕过入口的写法都要在评审打回。
- **整数帧计时**：物理 tick 60Hz ≡ GDD 1 帧。5s cd = 300 tick，不用秒。确定性、与刷新率解耦。
- **常量不落盘**：`test_save_no_constants.gd` 断言存档中不含任何 `GameConstants` 常量（保护 ADR-002）。
- **CI 中 `--import` 必须先于测试**，否则测试全红。
- 全项目强制静态类型；`_process` 内禁改游戏状态与被插值节点 transform。

---

## 6. Phase 4 决策记录（本 Sprint 生效）

| 编号 | 议题 | 裁决 | 落地位置 |
|---|---|---|---|
| G8 | lock-on 摄像机 | **做**（用户拍板）；本 Sprint 仅预留接口，实现排 Sprint 2 | `ux-spec.md`；`InputMap.verb_lockon` |
| G5 | Steam Deck | **v1 不支持，架构预留**（用户拍板）：画质 Low 档与 UI 缩放接口按 Deck 规格预留，后续开启为配置工作而非重构 | `epic-s0-foundation.md` ENG-S0-08 |
| G6 | 共鸣潮汐周期 | **90–120s**（原 6–8min 过慢难感知），参数化常量，林绘澄可在区间内按氛围微调 | `GameConstants` |
| G7 | 慢动作音频处理 | **已派阮和鸣**（T4-AUDIO）出技术判断 | 待回传 |
| — | `CANCEL_WINDOW` | 默认 **8 帧**守 P1（中断率 <5%）；「辅助模式」放宽至 10 帧**纳入 v1 但默认 OFF** | `GameConstants` + 可访问性 F7 |
| CONCERN-A | 语义色 hex 冲突 | **已关闭**：`design/color-tokens.md` v1.0 为唯一真相源，退役 `#2BB6A8`/`#F4B740` | 全链已同步 |
| CONCERN-UX-1 | S6 低血闪误用 THREAT | **已修**：改 `DAMAGE_WARN #E5484D`；`THREAT` 仍仅敌/混沌 | `ux-hud.md` |

---

## 7. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| **CONCERN-B 输入延迟**：账面 ~40–50ms 贴 S6 <50ms 红线 | 🔴 高 | SPIKE-1 排最前，240fps 摄像实测键鼠/手柄各 ≥30 次；超标即启 `architecture.md §7.5` 逃生门。**这是唯一可能推翻时间基准决策的风险** |
| **CONCERN-C 性能基线**：SDFGI + VolumetricFog 同开真实成本未知 | 🟡 中 | SPIKE-2 建冒烟场景 + 3 固定基准场景，S0 出口前记录首份基线；后续回归 >10% 自动报警 |
| S3 单测依赖 S0 脚手架 | 🟡 中 | 顺序已锁：`reset_for_test()`（S0-05）与 gdUnit4（S0-11）必须先于 S3 段 |
| 音频架构未定却要接 `AudioDirector` 骨架 | 🟡 中 | 已拉阮和鸣入场（T4-AUDIO），其结论直接修订 ENG-S0-05 第 6 项；**若其结论晚于 S0-05 开工，先留空骨架不接总线细节** |
| Godot 4.7.1 相对 4.3–4.6 的行为差异 | 🟢 低 | SPIKE-2 验收项含"验证 4.7 行为与 4.3–4.6 一致" |

---

## 8. 音频挂接点（阮和鸣入场后回填）

`AudioDirector` 位列 Autoload 第 6（ENG-S0-05），依赖前 5 个单例、不可反向依赖。本 Sprint 待其交付回填的接口：
- 总线结构（Master/Music/SFX/UI/Ambience）与各总线 dB 目标
- 共鸣池三态的听觉化方案（**P4 的音频落地**：不看 HUD 也能听出能否开门/放终结技）
- 敌人 telegraph 听觉预警（**可访问性冗余通道**：色盲玩家看不出 THREAT 品红，必须靠声音）
- G7 慢动作音频处理的实现路径
- 需新增的 EventBus 信号（若有，经主理人转程基岩评估）

---

## 9. Sprint 收尾

Sprint 结束时按 SOP 走：**工程实现 → 质量门（严守真出 QA 计划 + 烟雾测试）→ 设计评审（文策渊做范围检查）→ 主理人回顾**。
质量门给明确 PASS / CONCERNS / FAIL 判定；CONCERNS 及以上必须解决或经用户明确豁免，方可进 Sprint 2。
