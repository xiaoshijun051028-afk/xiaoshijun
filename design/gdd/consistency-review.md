# 跨 GDD 一致性 & 设计理论评审
> 范围：v1 Must 8 系统 ｜ 版本 v0.2 ｜ 评审 Solo
> 关联：systems-index.md（共享常量）、其余 8 篇 GDD

## 1. 一致性自检（跨 GDD）
| 维度 | 检查项 | 结果 |
|---|---|---|
| 动词命名 | 6 动词（斩/闪/荡/跃/格/共鸣）在 S1/S2 一致 | PASS |
| 取消窗口 | `CANCEL_WINDOW=8f` 在 S1/S2/systems-index 一致 | PASS |
| 无敌帧 | `DASH_IFRAMES=10f` 在 S1/S2 一致 | PASS |
| 格挡窗口 | `PARRY_WINDOW=6f` 在 S1/S4 一致 | PASS |
| 共鸣池 | MAX100/初始50/增益/消耗(闸门30,终结技40) 在 S1/S3/S5/S7 一致 | PASS |
| 语义色 | `THREAT=#A62C6B` 仅敌/混沌，`RESONANCE_GLOW` 青白，在 S4/S6/systems-index 一致；与概念 v0.2 对齐 | PASS |
| 神龛 | S5/S8 神龛位/复活一致 | PASS |
| 锚点密度 | P2 ≥0.6 在 S2/S5 一致 | PASS |

> 未发现数值/命名冲突；所有共享量均指向 systems-index §2 单一来源。

## 2. 设计理论评审
- **支柱映射**
  - P1 流动：S1 取消窗口 8f + S2 共享动词 → 支撑。**PASS**
  - P2 垂直：S2 轻重力+锚点，S5 密度 → 支撑。**PASS**
  - P3 精美即叙事：S7 残响 + S5 视觉节点 → 支撑。**PASS**
  - P4 共鸣统一：S3 单池互斥 → 支撑。**PASS**
- **SDT（自我决定论）**：自主（S5 多路线 / S8 配装）、胜任（S1 取消窗口奖励精通 / S4 读招）、关联（S7 残响）——全覆盖。**PASS**
- **心流（Flow）**：S4 telegraph 随岛递进（难度梯度），无数值碾压 gating（S8 无 grind）→ 平衡带可守。**PASS（Hard 参数待调）**
- **防主导策略**：S3 互斥消耗 → 无单线最优。**PASS**
- **防认知过载**：S6 HUD 仅 5 元素 + 统一预警语言 → **PASS**
- **防经济失衡**：S8 无货币，技能点来自里程碑 → **PASS**
- **防支柱漂移**：Fellowship/Submission 明确不做（概念 §2），各系统未越界 → **PASS**

## 3. 结论
**总体评级：PASS（带 2 项 CONCERN）**

- **CONCERN-1**：Hard 模式 telegraph 下限 0.4s 对低技能玩家可能跌破心流带，需在预制作做难度曲线 A/B 测试（S4/S5）。
- **CONCERN-2**：S2「荡中攻击」与 S8「洗点」为开放问题，若 Phase 3 要实现需先回概念文档补范围判定（当前 MoSCoW 未覆盖，不宜擅自纳入 v1）。

未出现 FAIL 项。GDD 可作为 Phase 3 工程与 Phase 4 预制作事实依据。
