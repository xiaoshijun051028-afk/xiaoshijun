# Phase 4 预制作汇编 · 星陨之境 (Aetherfall)

> 主理人：游承峰 ｜ 版本 v1.0 ｜ 日期 2026-08-08 ｜ 评审：Solo
> 上游：Phase 1 概念 / Phase 2 系统设计 / Phase 3 技术搭建 全部 PASS 过门

## 0. 结论

**Phase 4 预制作 PASS（收尾中）**。三大预制作交付（UX 规格 / 资产规格 / Epic·Story·测试）全部落盘且交叉一致；CONCERN-A 色彩冲突已闭环（color-tokens 为唯一真相源，systems-index §2 已同步）；仅剩 A/B/G1 文案级二次漂移清理（已派发，非阻塞）。可进 Phase 5 制作。

## 1. Phase 4 交付清单

| 交付 | 路径 | 负责人 |
|---|---|---|
| UX 规格（7 章：输入映射 / lock-on / HUD / 设置 / 开放项收口） | `design/ux/ux-spec.md` | 文策渊 |
| 资产规格（清单 / 预算 LOD / 管线 / 一致性） | `design/art/asset-spec.md` | 林绘澄 |
| 权威色彩 ColorTokens（最终 hex 单源） | `design/color-tokens.md` | 林绘澄 |
| 系统索引（§2 语义色已同步） | `design/gdd/systems-index.md` | 文策渊 |
| Epic / Story 拆分（10 Epic，33 验收全映射） | `production/epics/*.md` | 程基岩 |
| 测试框架脚手架（gdUnit4 / CI / Spike / S0 出口 / 33 验收 / Sprint1） | `docs/testing/test-plan.md` | 程基岩 |

## 2. 主理人拍板决策（Phase 4 内）

- **G8 lock-on 摄像机 = 做**（用户拍板）：获取/丢失规则、软硬锁、对闪/荡方向语义影响已在 UX 规格落地，明确不进战斗 FSM、不动 `CANCEL_WINDOW=8f`（守 P1）。
- **CANCEL_WINDOW**：默认 8f 守 P1（中断率<5%）；「辅助模式」放宽到 10f **纳入 v1 但默认 OFF**（呼应可访问性 F7，不破默认手感）。
- **G6 共鸣潮汐周期 = 90–120s**（原 6–8min 过慢难感知），参数化常量暴露，林绘澄可在区间内按氛围微调。
- **CONCERN-A 收口**：`design/color-tokens.md` 为语义色唯一真相源；`systems-index §2` 已同步为 Token 名 + 定稿 hex（退役 `#2BB6A8`/`#F4B740`）。
- **色彩纪律漏（CONCERN-UX-1）**：S6 §⑤ 低血闪由 `THREAT` 改为 `DAMAGE_WARN(#E5484D)`，并正式命名 Token；`THREAT=#A62C6B` 仍仅敌/混沌。

## 3. 跨文档一致性

- ✅ CONCERN-A 闭：color-tokens 权威 ↔ systems-index §2 ↔ 美术圣经 §2 ↔ 可访问性，全链一致。
- 🔧 残留 A/B/G1 清理中（非阻塞，已派发）：`accessibility-tier.md §0` 旧 hex（林绘澄改 Token 名）；`architecture.md §9` 冲突表 + `color_tokens.gd` 桩注释 + `§12.3 G1`（程基岩清为定稿值、标已收口）。
- ✅ 帧常量 / 共鸣池 / 接口契约 / 单例 全链一致（Phase 3 已建 `GameConstants` + 单测 + lint 可执行门禁）。

## 4. 已知风险与待决

- 🔬 **CONCERN-B 输入延迟**（账面 ~40-50ms 贴 S6 <50ms 红线）→ Sprint 1 **SPIKE-1** 240fps 摄像实测，是唯一可能推翻 §3 时间基准决策的风险，排 S0 最前、出口前必须有数据。
- 🔬 **CONCERN-C 性能基线**（SDFGI+VolumetricFog 同开真实成本）→ Sprint 1 **SPIKE-2** 冒烟+3 基准场景基线，S0 完成即刻记录。
- ✅ **G5 Steam Deck 已裁决**（用户拍板）：v1 **不支持，但架构预留**——画质 Low 档与 UI 缩放接口按 Deck 规格预留，后续开启为配置工作而非重构。
- ✅ **音频域已补位**（用户拍板）：音频总监阮和鸣已入场（T4-AUDIO），产出音频方向 + 事件表 + G7 慢动作音频判断，直接对接 Sprint 1 的 `AudioDirector` 单例骨架。

## 5. Sprint 1 垂直切片方案

- **目标**：可玩核心循环最小验证——节点共鸣 +10 → 池≥40 放终结技（占位敌）→ 验证 **P4「单一共享池驱动解谜+战斗」互斥端到端**。
- **范围**：S0 地基（12 Story，含 SPIKE-1/2 放行闸门）+ S3 共鸣池（4 Story）。
- **顺序 / 退出标准**：详见 `docs/testing/test-plan.md §6`（16 步 Story + 退出清单，含 P4 互斥端到端、CI 全绿、`test_cancel_window` 第 8 帧可取消、冒烟场景稳定 60fps + 首份性能基线）。
- **纪律**：先写测试；GDD §⑦ 33 条验收 100% 可映射（30 自动 + 3 人工）。

## 6. 下一步

进入 **Phase 5（制作）**：按 Sprint 1 实现 S0 地基 + S3 共鸣池垂直切片（Godot 4 工程脚手架 + 单测 + 占位场景）。本切片为**功能性验证**，视觉用 blockout；最终 stylized 3D 资产（模型/材质/VFX/Shader）按林绘澄 `asset-spec.md` 另案美术生产。每个 Sprint 循：工程实现 → 质量门（QA 计划 + 烟雾测试）→ 设计评审 → 主理人收尾。

**详细冲刺计划见 `production/sprint-01-plan.md`**（16 Story、执行顺序与并行策略、三级退出标准、工程纪律、决策记录、风险表、音频挂接点）。
