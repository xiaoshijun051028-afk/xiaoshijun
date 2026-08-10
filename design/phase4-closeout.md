# 星陨之境 / Aetherfall — Phase 4 预制作收口（Handoff）

日期：2026-08-10 ｜ 主理人：游承峰

## 0. 状态

Phase 4 预制作 **PASS（带已知风险，均已路由）**。全项目设计/架构/UX/资产/测试/音频文档已落盘（共 **39** 个 .md）。首个冲刺计划已出：`production/sprint-01-plan.md`。

## 1. 本轮新增交付

- **音频域补全（阮和鸣 / ruan-heming）**
  - `design/audio/audio-direction.md`（543 行 / 50.6KB）
  - `design/audio/audio-event-list.md`（223 行 / 22KB）
  - 覆盖：自适应音乐 5 态机（探索/战斗/Boss/残响/神龛）、6 动词音效调色板、共鸣池三态听觉化（P4 承重）、9 总线混音（−16 LUFS Integrated）、Standard 可访问性听觉冗余通道、AudioDirector 接线策略。
- **CONCERN-A 架构层收口（程基岩 / cheng-jiyan）**
  - `architecture.md` / `architecture-review.md` / `control-checklist.md` / `adr-002/003/005` 旧 hex 与"待裁决"全部闭环，统一指向 `design/color-tokens.md` v1.0 唯一权威。grep 自检：活值零命中。
- **G8 lock-on 决议回灌（程基岩）**
  - `adr-003` / `adr-005` 记为「实现 lock-on 摄像机」，并给出 Dash 方向解算技术判断——**目标相对极坐标解**（侧向环行 / 前后直线 / 斜向螺旋），理由见 `adr-003`。

## 2. 关键裁决结论

- **G7 慢动作音频（阮和鸣）**：慢动作期间**不做全局变调/变速**，改用 `SFX`+`Ambience` 低通下潜 + `Music` duck −3dB + 满保真「特写层」（绕开低通）；`Music`/`UI`/`VO` 完全免疫。实现：`_ready()` 预挂 `AudioEffectLowPassFilter`，包络用 `create_tween().set_ignore_time_scale()`。
- **重要纠正**：`Engine.time_scale` **不影响** `AudioServer`（与派单初始假设相反）。后果有二：
  - 好：AudioDirector 不随 time_scale 变调是引擎默认行为，零代码成本（架构 §5.4 原判断正确）。
  - 险：`ux-spec` 用 `Engine.time_scale=0` 暂停时**音频不会停** → 暂停菜单背后战斗音效继续播（见 AUD-6，真实 bug 风险，须显式处理）。

## 3. 需新增 EventBus 信号（6 条，待程基岩评估落 `architecture.md §5.2`）

| 信号（过去式） | 参数 | 驱动 |
|---|---|---|
| `time_dilation_started` | `scale: float, duration_frames: int` | G7 |
| `time_dilation_ended` | — | G7 |
| `game_paused` | — | AUD-6（time_scale=0 不停音频） |
| `game_resumed` | — | AUD-6 |
| `combat_state_changed` | `in_combat: bool` | 脱战无任何现有信号，音乐无法回切 Explore |
| `echo_finished` | `echo_id: StringName` | `echo_triggered` 只有开始没有结束 |

全部过去式、只陈述事实、均有 ≥2 系统消费（VFX/相机/HUD 同样受益）。

## 4. 已知风险与缓解（CONCERN-AUD-N 登记表）

| ID | 风险 | 路由 | 阻塞 |
|---|---|---|---|
| AUD-1 | GDD `combat.md §②` 无「终结技触发慢动作」，派单前提有误；音频已做可插拔 | 文策渊定夺 | Sprint 2 手感前 |
| AUD-2 | 完美格慢动作只给 0.3s，缺 `time_scale` 比值 | 文策渊补 `systems-index §2` | Sprint 2 手感前 |
| AUD-3 | AudioDirector 依赖序写 `2`，但需 `_ready` 读 `ResonancePool.current` 定共鸣三态床层 | 程基岩改 `2`→`2,3` | **阻塞 S0-05** |
| AUD-4 | 音效字幕（closed caption）超出 `accessibility-tier` v1.0 Standard 档承诺（听障侧等价缺口） | 严守真拍板 | 不阻塞 |
| AUD-5 | `ux-spec §4.2` 仅 3 条音量，音频需 6 条（含 VO/Ambience 独立） | 文策渊扩 `ux-spec` | Sprint 1 后 |
| AUD-6 | `Engine.time_scale=0` 不停音频 → 暂停菜单漏音 | 程基岩 §5.4 补显式处理 | **阻塞 S0-05** |
| AUD-7 | §5.2 无逐动词信号，6 动词只能挂 `player_state_entered(state_name)`，需确认枚举取值才能写死分派表 | 程基岩确认枚举 | **阻塞 S0-05** |

## 5. 命名冲突（已路由）

`FRIENDLY_AMBER`（代码/部分文档）vs `FRIENDLY_GOLD`（color-tokens 权威）＝ 同值 `#F2C15E`。
路由林绘澄：在 `color-tokens.md` 将 `FRIENDLY_AMBER` 列为 `FRIENDLY_GOLD` 的显式别名（沿用 `INTERACT` 模式），其余文件不改。

## 6. 下一步

进入 **Phase 5（制作）**：按 Sprint 1 实现 S0 地基 + S3 共鸣池垂直切片（Godot 4 工程脚手架 + 单测 + 占位场景）。
AUD-3/6/7 与 6 条新增信号由程基岩在 S0-05 开工前闭环；AUD-1/2/5 由文策渊在 Sprint 2 手感调校前闭环；AUD-4 由严守真在打磨阶段拍板。
待主理人拍板进 Phase 5。

## 7. 最终收口状态（2026-08-10）

全部阻塞项已清零，Phase 4 预制作 **PASS**。

| 项 | 状态 | 落点 |
|---|---|---|
| CONCERN-A 架构层收口 | ✅ RESOLVED | architecture/review/checklist/adr-002/003/005 → color-tokens v1.0 唯一权威 |
| G8 lock-on 决议回灌 | ✅ | adr-003/adr-005；Dash 方向＝目标相对极坐标解 |
| 音频方向 + 事件表 | ✅ | design/audio/audio-direction.md + audio-event-list.md |
| G7 慢动作音频 | ✅ RESOLVED | 不改音高，LP+duck+特写层；§5.4/§12.3 |
| 6 条新增 EventBus 信号 | ✅ | architecture §5.2（共 27 条） |
| AUD-3 AudioDirector 依赖 2→2,3 | ✅ | architecture §4.3 |
| AUD-6 暂停漏音 | ✅ | architecture §5.4.1（game_paused/resumed） |
| AUD-7 逐动词枚举 | ✅ | architecture §5.2（9 状态闭集，含 SlashHeavy） |
| AUD-1 终结技慢动作 | ✅ 否（不进） | combat.md §② / systems-index §2 |
| AUD-2 完美格慢动作常量 | ✅ | PARRY_SLOWMO_FRAMES=18, SCALE=0.3（墙钟真实时间） |
| AUD-5 音量 3→6 | ✅ | ux-spec §4.2 |
| 命名别名 FRIENDLY_AMBER / UI_BASE | ✅ | color-tokens v1.1 立为 GOLD/UI_BG 别名 |
| 事件表 Slash1..4 bug | ✅ 修复 | audio-event-list §2.1 → &Slash + combo 分派 |

### 仍挂起（非阻塞，已登记）
- **AUD-4**：音效字幕是否提升为 Standard 档 —— 路由严守真，打磨阶段拍板。
- **adr-003 §4.4 节点树**仍漏 SlashHeavy（§1 已补）；§110「8 个」计数陈旧 —— 文档自洽微调，Sprint 1 顺手收。
- **audio-event-list §3「6 条新增信号」标记已过期**（已落库）；§2 部分事件仍标 `L2+ 需新增` —— 文档陈旧清理，非阻塞。
- **mono downmix（audio-direction §6.4）** 在 ux-spec 无设置落点 —— 可访问性设置项缺口，Sprint 1 后补。
