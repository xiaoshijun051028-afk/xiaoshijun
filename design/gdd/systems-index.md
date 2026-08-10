# 系统设计索引 · 星陨之境 (Aetherfall)
> 版本 v0.2 ｜ Phase 2 系统设计 ｜ 评审 Solo ｜ 范围 = v1 Must（Should 项已标注）
> 上游：概念文档 v0.2（design/concept/game-concept.md）
> 下游：Phase 3 工程实现、Phase 4 预制作的事实依据

## 1. 系统清单与依赖排序
v1 Must 范围共 8 个核心系统。下表给出实现优先级（自底向上）与依赖关系。

| # | 系统 | 文件 | 依赖（须先就绪） | 被依赖（消费者） |
|---|---|---|---|---|
| S3 | 共鸣能量池 Resonance | resonance.md | —（根资源） | S1, S5, S7, S8 |
| S1 | 核心战斗 Combat | combat.md | S3（终结技） | S4, S6 |
| S2 | 移动与垂直穿越 Movement | movement.md | S5（锚点） | S1（取消手感）, S6 |
| S4 | 敌人 AI Enemy AI | enemy-ai.md | S1（动词/预警）, S3（共鸣伤害） | S6 |
| S5 | 世界与关卡 World | world-level.md | S2（锚点）, S3（闸门）, S8（神龛位） | S7 |
| S8 | 元进度·神龛 Meta | meta-progression.md | S5（神龛节点）, S1（技能树效果） | S6 |
| S6 | UX / HUD | ux-hud.md | S1, S3, S4（状态源） | — |
| S7 | 叙事·残响回声 Narrative | narrative.md | S3（触发）, S5（节点） | — |

**实现顺序建议**：S3 → S1 → S2 → S4 → S5 → S8 → S6 → S7。
理由：资源（共鸣池）与动词（战斗）是其他一切的地基；世界壳层与神龛承载内容；HUD / Narrative 最后收口，避免反复改接口。

## 2. 共享常量（Single Source of Truth）
所有 GDD 引用以下常量，禁止各自硬编码；改一处须全量同步。

- 帧基准：60 fps（1 帧 ≈ 16.67 ms）。
- `CANCEL_WINDOW` = 8 帧（≈133 ms）：斩/闪/荡/跃/格 之间可取消接续的窗口（支柱 P1）。
- `PARRY_WINDOW` = 6 帧（≈100 ms）：格挡命中判定窗口。
- `DASH_IFRAMES` = 10 帧（≈167 ms）：闪的无敌帧。
- **时间膨胀（慢动作）常量组**（v0.3 新增，T5-DESIGN-b / combat.md §⑧ D-AUD-2）：
  - `PARRY_SLOWMO_FRAMES` = 18 帧（= 300 ms）：完美格挡后时间膨胀的持续时长。
  - `PARRY_SLOWMO_SCALE` = 0.3（无量纲，`Engine.time_scale` 目标值；1.0 = 常速）。
  - ⚠ **计时基准 = 墙钟真实时间**：这 18 帧按**真实时间**计（300 ms），**不是**游戏 tick。实现须用 `get_tree().create_timer(0.3, true, false, true)`（第 4 参 `ignore_time_scale = true`）或 `Time.get_ticks_msec()` 计时；配套 Tween 须 `set_ignore_time_scale()`（同 audio-direction §8.4③）。**若误按游戏 tick 计**，真实时长会变成 `18 / 0.3 = 1.0 s`，吞掉 72 帧破防窗口的大半，并使取消窗口在真实观感上被放宽约 3.3×，违反 ux-spec §5.1「默认不放宽 `CANCEL_WINDOW`」的已拍板决策。
  - ⚠ **数值巧合提示**：`300 ms` 与 `SCALE = 0.3` 两个 "0.3" **毫无关联**（前者是时长、后者是无量纲缩放比）。这正是本表**一律用整数帧表达时长**的原因——代码中禁止复用同一个 `0.3` 字面量，两者须是两个独立命名常量。
  - `CANCEL_WINDOW` / `PARRY_WINDOW` / `DASH_IFRAMES` **恒按游戏帧判定，不因慢动作放宽**；膨胀期内约 5.4 游戏帧流逝，8 帧窗口真实观感上限约 340 ms（有界，不视为对 ux-spec §5.1 的破坏）。
  - **`FINISHER_SLOWMO` 不存在 —— 已定夺 = 否，非遗漏（AUD-1 / D-AUD-1）。** 共鸣终结技全程 `Engine.time_scale = 1.0`，冲击由「全屏谐波脉冲 + 高伤 + 击退 4 m + hit-stop」承载；**全作时间膨胀语义唯一归属完美格挡**（稀缺性设计）。**请勿再新增 `FINISHER_SLOWMO_FRAMES` / `FINISHER_SLOWMO_SCALE`**；若要推翻须同时复核 P1（连段流动）、P4（开门↔终结技取舍中立、防主导策略）与可访问性 F5，完整理由见 `combat.md §⑧ D-AUD-1`。音频侧（audio-direction §8.2）的可插拔层保持**未触发**，无需改动。
  - 关联：hit-stop（60–90 ms ≈ 4–6 帧）用架构 §5.4 的 FSM `frozen_frames` 实现，**不属于时间膨胀**，与本组常量互不相乘（叠加规则见 combat.md §⑥）。
- 语义色（单一来源 `ColorTokens` v1.0；对齐概念文档 v0.2 / 美术圣经 v0.1；禁止 hex 字面量）：
  - 威胁/混沌 `THREAT = #A62C6B`（混沌品红）——**仅限敌人/混沌专属**（可访问性 §0 铁律），用于预警、Boss 脉冲、危险标记、敌人 telegraph。
  - 友好/自然（三色叠加，非单一 Token）：
    - `FRIENDLY_TEAL = #5FD2C8`（青绿，植被/自然主导）
    - `FRIENDLY_AMBER = #F2C15E`（暖琥珀，点缀）
    - `FRIENDLY_CORAL = #FF8A65`（暖珊瑚，柔光/有机）
  - 伤害/警告 `DAMAGE_WARN = #E5484D`（炽红）——低血闪、受击预警、非敌语义的危险提示。
  - 共鸣 `RESONANCE_GLOW = #9FF7E8`（青白，emissive）——与威胁品红严格区分，避免误读。
  - 附属：`GATE_READY`（可开门态）、`INACTIVE`（灰，未就绪）、`UI_BASE = #1A2233`（界面底）。
- 共鸣池 `RESONANCE_POOL`：
  - 上限 `MAX = 100`；初始 `50`。
  - 获取：命中近战 +1/次；完美格 +5；击杀 +15；世界共鸣节点 +10/次；脱战被动 +2/秒。
  - 消耗（互斥）：解谜闸门 `GATE_COST = 30`；战斗终结技 `FINISHER_COST = 40`。
  - 单一共享池 → 开门与终结技天然互斥（防主导策略，支柱 P4）。

## 3. 跨系统接口契约（关键）
- S1→S3：终结技触发扣 `FINISHER_COST`；池不足则终结技不可用（HUD 灰显）。
- S5→S3：谜题闸门触发扣 `GATE_COST`；不够则闸门不解锁并提示。
- S1↔S4：敌人攻击进入 `telegraph` 阶段显 `THREAT` 色；玩家在 `PARRY_WINDOW` 内格挡 → 触发破防硬直。
- S3→S7：玩家在共鸣节点按共鸣 → 节点发光并触发残响叙事。
- S5→S8：神龛为唯一存档/复活点；技能树效果在神龛应用。
- S1/S3/S4→S6：HUD 读取 hp / 共鸣池 / 威胁标记 / 连段数。

## 4. 一致性评审
见 `consistency-review.md`（自检动词、共鸣池、语义色、取消窗口一致性，并给 PASS / CONCERNS / FAIL）。
