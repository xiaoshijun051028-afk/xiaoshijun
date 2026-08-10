# 史诗与故事索引 · 星陨之境 (Aetherfall) Phase 4 预制作

> 版本 v1.0 ｜ 作者 程基岩 ｜ 引擎 Godot 4.7.1-stable
> 依据：`design/gdd/systems-index.md` §1 依赖 DAG、`docs/architecture/architecture.md`、`adr-001..005.md`、`control-checklist.md`
> 下游：Sprint 计划（`docs/testing/test-plan.md` §8）、CI、测试落地
> 用法：**每个 Story 实现前必须先落对应测试（先写测试）；Story 完成 = GDD §⑦ 复选框能指向一个测试文件路径。**

## 1. 依赖 DAG（对齐 GDD，S0 为工程底座）

```
S0(地基) → S3(共鸣池) → S1(战斗) → S2(移动) → S4(敌人) → S5(世界) → S8(元进度) → S6(UX) → S7(叙事)
```

> **顺序张力说明（架构评审 CONCERN-C）**：`systems-index` §1 标注 S2 依赖 S5(锚点)。本索引以 **S0 建立「锚点数据契约 + 占位锚点源」** 解耦，使 S2 可先于 S5 实现 locomotion；S5 后续填充真实锚点（见 `ENG-S2-04` / `ENG-S5-02`）。此张力已在 `architecture-review.md` CONCERN-C 登记，S0 完成后立即建性能基线验证。

## 2. 史诗清单

| Epic | 系统 | 依赖 | 文件 | 故事数 | 出口条件 |
|---|---|---|---|---|---|
| **E0** | S0 地基 | — | `epic-s0-foundation.md` | 12 | S0 出口（control-checklist §P）全满足 |
| **E3** | S3 共鸣池 | S0 | `epic-s3-resonance.md` | 4 | S3 四条 GDD 验收单测全绿 |
| **E1** | S1 战斗 | S0, S3 | `epic-s1-combat.md` | 5 | 取消≤8帧集成测试绿；手感 spike 过 |
| **E2** | S2 移动 | S0, S5(契约) | `epic-s2-movement.md` | 4 | 跃→闪→斩≤8帧；越界复活100% |
| **E4** | S4 敌人 | S0, S1, S3 | `epic-s4-enemy-ai.md` | 5 | telegraph 100%覆盖；弱点x2 |
| **E5** | S5 世界 | S0, S2, S3, S8 | `epic-s5-world.md` | 6 | 0死路；可达比≥0.6 |
| **E8** | S8 元进度 | S5, S1 | `epic-s8-meta.md` | 5 | 存档还原100%；写盘失败不崩 |
| **E6** | S6 UX | S1, S3, S4 | `epic-s6-ux.md` | 5 | 三态色正确；双设备通关 |
| **E7** | S7 叙事 | S3, S5 | `epic-s7-narrative.md` | 4 | 节点+10正确；战斗中不卡输入 |

## 3. 验收标准覆盖

全部 GDD §⑦ 验收复选框（跨 8 系统共 **33 条**；架构评审 §9 记为 24 为早期按系统分组计数，本索引按逐条落地覆盖全部 33 条）逐条映射到 Story 与测试路径，见 `docs/testing/test-plan.md` §7 与 `architecture.md` §11.2。

## 4. Story 编号约定

- ID：`ENG-<SYS>-<NN>`（如 `ENG-S3-01`）。
- 分支：`feat/eng-<sys>-<nn>`（如 `feat/eng-s3-01`）。
- 估算：S/M/L（≤1天 / 1–3天 / >3天），Solo 下仅作排期参考。
- 测试路径字段：`tests/unit|integration|tools/...` 对应落地测试文件。

## 5. 放行闸门（架构评审前置条件）

- 🔴 **SPIKE-1 输入延迟实测（CONCERN-B）** 与 **SPIKE-2 渲染性能基线（CONCERN-C）** 必须排在 S0 最前、且 S0 出口前必须有数据（无论通过与否）。这是唯一可能推翻 `architecture.md` §3 时间基准决策的风险。
- 所有 🔴 Autoload 准入（GameConstants / EventBus / ResonancePool / SaveManager / InputManager / DebugOverlay）为其它史诗的承重墙。
