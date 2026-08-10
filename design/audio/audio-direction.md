# 音频方向文档 · 星陨之境 (Aetherfall)

> **文档类型**：音频方向（Audio Direction · 预制作可执行）
> **任务 ID**：T4-AUDIO（重派）｜ 优先级 P0
> **作者**：阮和鸣（audio-director）
> **引擎 / 平台**：Godot **4.7.1-stable** / Forward+ / D3D12 ｜ PC · Steam（Steam Deck 架构预留、v1 不承诺）
> **评审强度**：Solo（精炼但可落地工程）
> **版本**：v1.0
>
> **上游事实依据**：
> - 概念 `design/concept/game-concept.md` v0.2（四大支柱 / 6 动词 / MDA）
> - `design/gdd/systems-index.md` §2（**常量单一真相源**，帧数以此为准）
> - GDD：`combat.md` / `resonance.md` / `enemy-ai.md` / `narrative.md` / `ux-hud.md`
> - `design/art-bible.md` v0.1（情绪基调、语义色绑定）
> - `design/color-tokens.md` v1.0（**语义色唯一真相源**）
> - `design/accessibility/accessibility-tier.md` v1.0（v1 = **Standard** 档）
> - `docs/architecture/architecture.md` v1.0 §3/§4/§5/§6/§7（时间基准、Autoload、EventBus、混音/时间处理、性能预算）
> - `design/ux/ux-spec.md`（设置菜单、音频音量项）
>
> **下游**：`design/audio/audio-event-list.md`（音频事件清单）、程基岩 `AudioDirector` 单例实现（ENG-S0-05 第 6 项）、Phase 5 音频资产制作。
>
> **纪律声明**：本文不重定义任何 GDD 数值；所有时序以**整数帧**表达（1 物理 tick ≡ GDD 1 帧，60 Hz，架构 §3）；语义色一律引用 **Token 名**（`THREAT` / `RESONANCE_GLOW` / `DAMAGE_WARN`），**禁止 hex 字面量**。发现上游矛盾/缺信息一律标 `CONCERN-AUD-N` 回传主理人，不自行编造。

---

## 0. 核心听觉命题（一句话锚点）

> **"在坠落的星河里，玩家用耳朵就能听见自己的流动、听见世界的美、听见共鸣池的涨落与那份'开门还是终结'的取舍张力。"**

音频服务四大支柱的听觉转译：

| 支柱 | 听觉转译 | 关键手段 |
|---|---|---|
| **P1 流动即正义** | 6 动词音效"起音瞬态锐利、尾音留白"，连段可听地叠加不糊 | 每动词独占频段+包络形状；低延迟；命中顿帧靠瞬态强化（§3） |
| **P2 垂直即世界** | "高度感"与"失重感"——风声、空间混响随高度变化，位移动词带多普勒 | AudioStreamPlayer3D + doppler + 高度驱动混响（§7） |
| **P3 精美即叙事** | 壮美、空灵、带一丝苍凉的希望感；音乐替叙事承重 | 东方奇幻 × 日式精美音色，宽动态电影感（§1） |
| **P4 共鸣统一** | **单一共享池的涨落与互斥张力"听得出"**——开门与终结技此消彼长 | 共鸣听觉床三层 + 阈值提示音 + 互斥流失音（§4，**重点**） |

---

## 1. 音频基调与参考

### 1.1 情绪基调（对齐美术圣经 §1）
美术圣经把世界气质定为 **"壮美、空灵、带一丝苍凉的希望感"**——"战斗要爽，世界要美"。音频与之同调，形成两条并行的听觉线：
- **世界线（美）**：空灵、宽阔、克制的电影感；云端之上的宁静 vs 混沌侵蚀区的压迫，靠频谱明暗与混响空间感对比拉开。
- **战斗线（爽）**：锐利、紧凑、高冲击；瞬态优先、低频有"崩"感、整体明快但不刺耳。

二者由**统一的"共鸣"听觉母题**收束（青白/星辉音色，见 §4），正如视觉上"星辉青（共鸣）+ 暖金（希望）"收束整个色彩语言。

### 1.2 频段取向（Spectral Direction）
整体"**明快但克制**"（对齐美术 §3.3"阈值偏高避免整体发灰"的听觉等价物——不靠一味推高来制造能量）：

| 频段 | 归属 | 纪律 |
|---|---|---|
| **低频 20–120 Hz** | 命中"崩"、跃落地冲击波、终结技谐波、Boss 体量 | 只给"该重的东西"；探索/UI 不占低频，避免糊 |
| **低中 120–500 Hz** | 音乐体量、环境床、角色脚步/布料 | 战斗时侧链让路给命中（§5） |
| **中频 500 Hz–2 kHz** | 可读性核心：动词区分、语音清晰度 | 保持干净，不过度压缩 |
| **高中 2–5 kHz** | **敌人 telegraph 预警专属带（预留）** + 星刃切割泛音 | 预警音锁定此带，战斗中永远能"穿"出来（§6 可访问性关键） |
| **高频 5–16 kHz** | 共鸣青白 shimmer、结晶/玻璃质感、极光空气感 | 世界"空灵"的来源；克制用量防齿音疲劳 |

**混沌造物频谱签名**：失谐（detune）、金属不谐、颗粒化 glitch 噪声——听觉上对应视觉的"品红脉冲 + 抖动故障"，让"被造而非被生"的威胁感来自"非自然的不稳定"（美术 §5.2）。

### 1.3 混响空间感（Reverb / Space）
以 **Area3D 混响分区 + 混响发送总线** 实现"走到哪里、听到哪里"（实现见 §7.3）：

| 空间 | 混响特征 | 对应美术锚点 |
|---|---|---|
| **云端浮岛（户外）** | 大而通透、长尾但低密度、含轻微"空气/风"漫反射 | "云端之上的宁静"、体积光穿刺的开阔 |
| **混沌侵蚀区** | 收窄、变冷、金属早反射、尾音带失谐嗡鸣 | "光线收窄、雾变冷、锈屑飘浮" |
| **封闭遗迹 / 洞窟** | 紧、暗、石质中短混响 | VoxelGI 封闭空间（架构 §6） |
| **神龛安全区** | 温暖、亲密、柔和短混响 + 希望感 pad 垫底 | 存档点的"安全呼吸" |

### 1.4 音色选择（Timbre Palette）
**东方奇幻 × 日式精美**（对齐美术 §6.3"浮空鸟居 / 木构神社"、参考《原神》《对马岛之魂》《二之国》的听觉等价）：
- **主旋律层**：拨弦（古筝/koto 感）、弓弦；**打击**用太鼓/低频鼓营造战斗体量。
- **共鸣/神龛层**：空灵人声合唱（wordless choir）+ pad + **结晶/玻璃钟**（对应"星辉青共鸣"与"雾晶节点"HazeGlass）。
- **天空层**：极光感合成 shimmer、缓慢下落的"星陨"点状音（呼应天幕星痕）。
- **混沌层**：处理过的金属/工业质感 + 颗粒 glitch + 失谐脉冲。
- **星刃身份音**：恒定的青白 shimmer 底噪，随共鸣池变化（§4），是玩家的"听觉自我标识"（对应视觉"星刃恒发星辉青光"）。

### 1.5 动态范围策略（Dynamic Range）
**电影级宽动态、按情境自适应**：
- 探索 / 神龛：安静、留白、可"呼吸"（瞬时响度低，见 §5 LUFS）。
- 战斗 / Boss：整体抬升 + 更强总线压缩，换取"爽快"的冲击与密度。
- **随强度自适应**：战斗强度（连段 / 敌数 / Boss 阶段）越高，混音越"贴脸"（压缩更紧、低频更实），退出战斗回归宽动态。
- 目标：让玩家在"安静的美"与"密集的爽"之间有明显的响度与密度落差，而非全程一个音量。具体响度基准见 §5.6。

---

## 2. 音乐方向：自适应音乐架构

### 2.1 Godot 4.7.1 可用性核实（已验证）
**结论：采用 Godot 原生 `AudioStreamInteractive` + `AudioStreamSynchronized`（+ `AudioStreamPlaylist`）实现自适应音乐，无需第三方中间件（Wwise/FMOD）。**

核实依据（2026 官方来源）：
- 这三个音频流资源在 **Godot 4.3（2024-08-15）正式引入**（godotengine.org/releases/4.3 "Interactive music"）。项目钉定 **4.7.1**（架构 §1.1），版本充裕、可用。
- 归属 `modules/interactive_music/`，**官方标准构建默认包含**（与项目"零非常规第三方依赖"约束一致，架构 §12.1）。
- **实现注意**：`AudioStreamInteractive` 的 GDScript 构造 API 受限，官方推荐**在编辑器 Inspector 里搭建 `.tres` 资源**（配置 Clip Count / 命名 / 过渡时机），脚本侧只 `load()` 播放。这与项目"数据驱动、`.tres` 优先"风格一致（架构 §3.3）。

### 2.2 两种技法分工
- **横向切换（Clip Switching）= `AudioStreamInteractive`**：在 5 个宏观状态间整曲切换（探索↔战斗↔Boss↔残响↔神龛），支持过渡时机（立即 / 曲末 / 下一拍 / 下一小节）。
- **纵向分层（Vertical Layering）= `AudioStreamSynchronized`**：在**同一状态内部**按强度加/减乐器层（如战斗内"基础层→鼓→旋律→合唱"随连段/敌数/共鸣池推进），靠 `set_sync_stream_volume()` + Tween 淡入淡出，多层始终同步无漂移。
- **组合**：每个宏观 clip 内部本身可以是一个分层流（战斗 clip = 4 层同步流）。

### 2.3 五态音乐状态机

| 状态 | 触发（EventBus） | 音乐性格 | 内部纵向分层（AudioStreamSynchronized） |
|---|---|---|---|
| **探索 Explore** | `island_entered` / 脱战 | 空灵、稀疏、希望；拨弦+pad+极光 shimmer | L0 环境垫 / L1 旋律动机（随高度/发现淡入） |
| **战斗 Combat** | `enemy_telegraph_started` 首次 / 进战 | 紧凑、打击驱动、明快高冲击 | L0 律动 / L1 鼓 / L2 弦乐张力 / L3 合唱（随连段·敌数·共鸣池升层） |
| **Boss** | `boss_phase_changed` | 史诗、悲壮、体量最大 | 每阶段一套分层；阶段推进=解锁更高层 |
| **残响叙事 Echo** | `echo_triggered` | 内省、留白、情感；音乐让位给语音 | L0 极简垫（其余层压低，给 VO 让路，§5 侧链） |
| **神龛安全区 Shrine** | `shrine_activated` | 温暖、安全、"呼吸"；希望 pad + 结晶钟 | L0 暖垫 / L1 结晶点缀 |

### 2.4 转场规则（对齐 `AudioStreamInteractive` 过渡常量）

| 转场 | 过渡时机常量 | 理由 |
|---|---|---|
| 探索 → 战斗 | `TRANSITION_FROM_TIME_IMMEDIATE` | 遭遇即张力，瞬时切入 |
| 战斗 → 探索 | `TRANSITION_FROM_TIME_END` / `NEXT_BEAT` | 战斗结束自然收束，不突兀 |
| 战斗 → Boss | `TRANSITION_FROM_TIME_NEXT_BEAT`（或 `FROM_BAR`） | 保持节拍不断裂地升格 |
| 任意 → 神龛 | `NEXT_BEAT` + 快速交叉淡出 | 进安全区柔和过渡 |
| 任意 → 残响 | 不切曲：当前曲**纵向压层** + VO 侧链 duck（§5） | 残响允许战斗中触发不暂停（S7 §6），故不能整曲切换 |
| 残响 结束 | 层恢复 | 回到原状态 |

> **残响特例**：narrative.md §6 明确"战斗中触发残响不暂停、半透明叠加"。因此残响**不做整曲横向切换**，而是在当前音乐上**压低非核心层 + VO 侧链**，播完恢复——避免打断战斗音乐的连续性。

### 2.5 音乐实现要点
- 音乐为**非定位 2D**：`AudioDirector` 持有单个 `AudioStreamPlayer`（非 3D）承载音乐主流。
- 音乐总线**免疫 `Engine.time_scale`**（慢动作不变调，见 §8 G7 收口）——尤其分层流是按拍同步的，变调会破坏节拍对齐。
- 音乐**独立音量**（可访问性 §6.7）。

---

## 3. 音效调色板：6 动词

### 3.1 统一设计原则："起音瞬态 + 尾音留白"
- **起音瞬态（Attack）锐利**：每个动词首个 1–2 帧内给足信息量（transient front-loaded），服务 P1"流动即正义"——玩家在极短取消窗（`CANCEL_WINDOW=8f`）里靠听觉确认"这一下出了"。
- **尾音留白（Tail restraint）**：尾音短、干净、快速衰减，**给下一个动词让出频谱与时间空间**。连段时多个动词瞬态叠加而不互相糊——这是 6 动词"可听地区分"的前提。
- **频段独占 + 包络差异**：每动词占一条主频带 + 一种包络形状，即使同时响也能分辨（对齐概念 §3"6 动词共用一套取消/预警语言"的听觉实现）。

### 3.2 6 动词音色定位表

| 动词 | 主频段 | 包络（起音→尾音） | 音色定位 | 差异化关键 |
|---|---|---|---|---|
| **斩 Slash** | 高中 2–5k（切割）+ 低 60–120（命中"崩"） | 极快起 → 极短尾 | 星刃金属切割 whoosh + 命中脆响；4 段连段**逐段升调/增密**，末段更重（可接终结） | 唯一带"低频崩感"的近战；连段音高阶梯 |
| **闪 Dash** | 中高 + 空气声（airy） | 快起 → 短"相位"尾 | 位移 whoosh + **i-frame 期一层去饱和/耳语滤波层**（听觉对应视觉"去饱和闪"，美术 §8）；**完美闪**额外结晶 ping + 缓时延长 | "空气+相位"质感，无金属崩；有无敌听感 |
| **荡 Grapple** | 中频 + 张力泛音 | 中起 → 持续张力 → 释放 | 钩索"shhk"射出 + 绳张力 whir + **摆荡多普勒**掠过；顶点失重 swoosh | 唯一"持续+多普勒"动词（3D） |
| **跃 Leap** | 低中（起跳）+ 高（滞空）+ 低频（落地） | 柔起 → 滞空 shimmer → **落地低频冲击波** | "星力抬升"发射 + 滞空悬停空气 shimmer + 落地 2–3m 震波"boom" | 唯一"三段式"（起跳/滞空/落地）；落地低频 |
| **格 Parry** | 高中 2–5k（**穿透性**） | 瞬态最尖 → 极短 | **完美格"叮"**（金属结晶铃）—— 全作最尖锐可穿透的防守音 + 敌破防金属"裂" | 最高瞬态、最短尾；防守身份音 |
| **共鸣 Resonate** | **全频谐波**（青白 shimmer 主导） | 涌起 → 谐波脉冲 | 星刃引导谐波 swell + 结晶琶音（`RESONANCE_GLOW` 青白音色）；**终结技**=巨型谐波脉冲+低频体量+击退 whoosh；**开门**=较柔的"解锁"和弦 | 唯一"全频谐波"；是 §4 听觉母题的动作化 |

> **命中顿帧（hit-stop 60–90ms ≈ 4–6 帧）的听觉强化**：hit-stop 不靠时间缩放（架构 §5.4 用 `frozen_frames`，非全局 `time_scale`），音频上**靠命中音自身的瞬态**表达"崩"的凝滞感——命中瞬间一个极短的高密度瞬态即是反馈，无需额外全局处理（详见 §8）。

---

## 4. 共鸣池听觉化（重点 · P4"共鸣统一"的听觉承重）

> **目标（任务硬要求）**：0–100 的池值，让玩家**不看 HUD 也知道能否放终结技 / 能否开门**；三态（不足 / 可开门 ≥30 / 可终结技 ≥40）听觉可辨；并**听得出单一共享池的"开门↔终结技"互斥张力**（支柱 P4 核心）。

数值来源（systems-index §2，单一真相源）：`MAX=100`、初始 `50`、`GATE_COST=30`、`FINISHER_COST=40`；增益 命中+1 / 完美格+5 / 击杀+15 / 节点+10（5s cd）/ 脱战+2 每秒。

### 4.1 双轨设计：连续"听觉床" + 离散"阈值提示"
玩家对池状态的感知 = **连续背景（我大概多少）** + **离散事件（我刚跨过了某条线）** 两条轨叠加。

#### 轨 A · 共鸣听觉床（连续，`AudioStreamSynchronized` 三层）
一条**恒定的星刃青白 hum**（玩家身份音，§1.4），用 3 个同步层表达池量，音量/滤波由 `resonance_changed(new,old)` 事件平滑驱动：

| 层 | 出现条件 | 听感 | 表达 |
|---|---|---|---|
| **L0 基础 hum** | 恒在 | 低、稀、暗 | "星刃在，但能量低" |
| **L1 就绪层（暖谐波）** | 池 **≥30**（可开门）淡入 | 加入一层温暖谐波/结晶泛音，hum 变"饱满" | "可以开门了" |
| **L2 满蓄层（青白顶）** | 池 **≥40**（可终结技）淡入 | 再叠一层明亮青白 shimmer 顶泛音，整体"充能感" | "可以放终结技了" |

三态因此是**三种叠加纹理**（不是单纯变响）：`<30` 暗而稀 / `≥30` 温暖饱满 / `≥40` 明亮充能。玩家在战斗嘈杂中靠"纹理厚度"即可判断，无需读条。层音量随池值在阈值附近平滑过渡（滞回 hysteresis 防抖，见 4.4）。

#### 轨 B · 阈值提示音（离散，穿越即响）
在**跨越阈值的那一刻**给一个明确的短提示（比较 `resonance_changed(new, old)` 的 new/old 是否跨线）：

| 事件 | 触发 | 提示音 | 听感语义 |
|---|---|---|---|
| 升过 30（可开门就绪） | old<30 且 new≥30 | 两音"就绪"动机（暖金/teal 音色） | "开门解锁" |
| 升过 40（可终结技就绪） | old<40 且 new≥40 | 更亮、更"落定"的青白和弦 ping | "终结技解锁" |
| 跌破 40 | old≥40 且 new<40 | 青白顶层"下沉"音 | "终结技没了" |
| 跌破 30 | old≥30 且 new<30 | 暖谐波"熄灭"音 | "开门也没了" |

### 4.2 互斥张力的听觉化（P4 核心 · 最关键）
因为是**单一共享池**，"开门"和"放终结技"天然互斥。要让玩家**听得出这份取舍**：

- **开门时（`gate_opened`，扣 30）**：播一段明显的"**共鸣外流 / outflow**"音——池从 `≥40` 掉到可能 `<40` 时，**L2 满蓄青白顶层会当场被抽走**，玩家清楚听到"我刚把终结技的能量花在这扇门上了"。
- **放终结技时（`finisher_executed`，扣 40）**：巨型谐波脉冲释放后，听觉床**回落到 L0/L1**，"就绪层"也可能熄灭——听到"我把能量都倾泻出去了，门暂时开不了"。
- 因此**同一个"流失"事件同时携带"我失去了另一种可能"的信息**——这正是 P4"防主导策略"的听觉表达：每次消费都能听到机会成本。

> 设计意图：视觉上 HUD 只显示一个数字/一条环（ux-hud §②、ux-spec §3.2 三态色），**听觉承担"机会成本/取舍张力"这一层 HUD 难以传达的信息**，与 P4"用单一动词统合探索与战斗、避免割裂"呼应。

### 4.3 "不能放"的失败反馈（对齐 S1 §⑥）
- 池不足强行终结技 / 开门 → `resonance_spend_rejected(cost, reason)` → 播一个**发闷、失谐的"共鸣不足"音**（与"就绪"提示音形成明确的"成/败"对立）。这同时是 HUD"灰显+提示"的**听觉冗余**（可访问性，§6）。

### 4.4 实现要点与防刷屏
- **数据源**：`resonance_changed(new,old)` 驱动床层音量 + 阈值检测；冷启动在 `AudioDirector._ready()` 主动读一次 `ResonancePool.current` 对齐初值（同 HUD 模式，架构 §4.6）。
- **防刷屏（关键）**：脱战被动 `+2/秒`、命中 `+1/次` 会让 `resonance_changed` 高频触发。**床层用平滑插值**（对连续值），**阈值提示音只在真正跨线时触发一次**（离散）——绝不每次 +1 都响。阈值附近加**滞回**（如 ≥40 触发、跌到 ≤37 才复位），防在临界值反复抖动刷提示音。
- **总线归属**：听觉床与提示音走 `SFX`（或其子总线 `SFX_Resonance`），随 SFX 音量；音色引用 `RESONANCE_GLOW`（青白）身份，与视觉 emissive 脉冲**同步触发**（阈值提示音与 HUD 刃能环三态变色/脉冲对齐，形成视听一致）。
- **2D（非定位）**：这是玩家的"个人状态音"，挂玩家、非位置化。

---

## 5. 混音方针（Mix Strategy）

### 5.1 总线结构（Bus Tree）
> ENG-S0-05 第 6 项现仅要求 `Master/Music/SFX/UI/Ambience` 五总线骨架。下表为**完整目标结构**；标 `[S0 骨架]` 者为 S0 必须先立、标 `[建议新增]` 者见 §9 对 ENG-S0-05 的修订建议。

```text
Master  [S0 骨架]                       # 挂 AudioEffectHardLimiter（安全网，ceiling -1 dBTP）
├── Music     [S0 骨架]                 # 自适应音乐流（§2），免疫 time_scale
├── SFX       [S0 骨架]                 # 玩法音效母线；预挂 AudioEffectLowPassFilter（默认 20kHz 透明，供 §8 慢动作下潜）
│   ├── SFX_Combat     [建议新增]       # 动词/命中/敌人/telegraph（telegraph 见 §6，最高优先级）
│   ├── SFX_World      [建议新增]       # 交互/机关/环境物件 foley
│   └── SFX_Resonance  [建议新增]       # 共鸣听觉床+阈值提示（§4）
├── Ambience  [S0 骨架]                 # 环境床（风、云海、区域氛围）；受慢动作下潜（§8）
├── UI        [S0 骨架]                 # 菜单/HUD 反馈；免疫 time_scale
├── VO        [建议新增]                # 残响回声语音（S7）；驱动侧链 duck 音乐/环境
└── Reverb (send)  [建议新增]           # 混响发送总线，Area3D 分区注入（§7.3）
```

### 5.2 各总线 dB 目标（起始名义值，Phase 5 混音复核）
> 名义推子值为**相对起点**，非最终；最终以 §5.6 LUFS 与实听为准。

| 总线 | 名义推子 | 说明 |
|---|---|---|
| Master | 0 dB | 仅挂限制器安全网，不做主观增益 |
| Music | −8 dB | VO/终结技时被侧链 duck −4～−6 dB |
| SFX（母） | −3 dB | **听觉主角**；战斗命中短时峰值可近 −6 dBFS |
| └ SFX_Combat | 0 dB（相对 SFX） | telegraph/格挡/终结不可裁减（§5.4 优先级） |
| └ SFX_World | −4 dB | foley 让位战斗 |
| └ SFX_Resonance | −5 dB | 存在感清晰但不抢命中 |
| Ambience | −18 dB | 垫底，战斗时进一步 duck |
| UI | −6 dB | 清晰但不刺耳 |
| VO | −3 dB | 锚定 ~ −16 LUFS，最高语音清晰度；驱动侧链 |

### 5.3 侧链闪避（Ducking）
用 **`AudioEffectCompressor` 的 `sidechain` 属性**（Godot 原生：把某条总线的信号设为压缩器的侧链输入）实现自动让路：

| 被压总线 | 侧链源 | 触发场景 | 量 / 时值 |
|---|---|---|---|
| Music、Ambience | **VO** | 残响叙事播放时语音优先 | duck −4～−6 dB，release ~200–300 ms |
| Music、Ambience | **SFX_Combat**（大冲击/终结技） | 终结技/Boss 脉冲瞬间让出空间 | 短促 duck −3～−5 dB，release ~150 ms |
| Ambience | SFX（战斗态） | 进入战斗环境让位 | 缓 duck −3 dB |

### 5.4 战斗高峰优先级裁决（20+ 音源不糊）
密集战斗（架构 §7.3 骨骼角色同屏 ≤12 + 粒子 + 环境）音源会激增，靠三层策略保证"不糊、不裁关键音"：

1. **优先级分级（voice priority）**——池化音源按优先级 tier，超预算时**只裁低优先级**：
   - **Tier 0（永不裁）**：敌人 telegraph 预警（§6 可访问性命脉）、完美格"叮"、终结技、Boss 阶段、`resonance_spend_rejected`。
   - **Tier 1**：玩家动词、命中、敌死。
   - **Tier 2（可裁 / 可合并）**：次要 foley、远处环境物件、重复的小音效。
2. **频谱分区（避免遮蔽）**：靠 §1.2 的频段分配 + 各总线 EQ 轻雕刻，让不同事件占不同频带，密集时靠"分频"而非"叠响"求清晰；telegraph 独占 2–5kHz 带，永远能穿透。
3. **实例裁剪**：
   - 每类音效设**最大并发实例数**（如同一命中音同帧 ≥N 个 → 合并为 1 个稍强的）。
   - `AudioStreamPlayer.max_polyphony` 限制单源复音；`AudioDirector` 维护全局音源池（§7.2）与总并发上限（§7.4）。
   - 3D 音源按距离 + 优先级剔除（远处 Tier 2 先静音回收）。
4. **总线动态**：SFX 母线轻压缩把峰值"抓住"，防瞬时叠加过载；Master 限制器兜底。

### 5.5 慢动作/hit-stop 的混音处理
见 §8（G7 收口）——**慢动作不做全局变调**，仅在 SFX+Ambience 做短促低通下潜 + 轻侧链 + 叠"特写"层；Music/UI/VO 免疫。

### 5.6 响度标准（LUFS 目标 + 理由）
- **整体混音基准：整合响度（Integrated）目标 −16 LUFS；真峰上限 −1 dBTP**（Master 挂 `AudioEffectHardLimiter` 兜底）。
- **按情境浮动（宽动态）**：神龛/探索 短时响度低（momentary ~ −20～−24 LUFS）、战斗/Boss 高（momentary 可达 ~ −12 LUFS），整合值收敛在 −16。
- **对话/残响 VO**：锚定 ~ −16 LUFS 保清晰度（侧链让路，§5.3）。

**为何选 −16 LUFS（理由）**：
1. **平台/听音场景**：PC·Steam 以桌面/耳机近场听音为主，比客厅电视响；EBU R128 的 −23 LUFS、ASWG-R001 游戏建议的 −24（客厅）/ −18（掌机）偏静，桌面近场取更响的 −16 更合体验。
2. **流媒体友好**：贴近 YouTube/Spotify 等 −14 LUFS 归一化线，主播/剪辑上传时不会被大幅压响或推爆，保护作品听感。
3. **保留冲击余量**：−16 整合 + 真峰 −1 dBTP 之间留 ~15 dB 峰值余量，足够动作游戏瞬态"爽快"冲击而不削波（对齐 P1）。
4. **Steam 无强制归一**：需自律定标，−16 是"够响但安全"的工程锚点。
> 可在 Phase 5 用响度表按 ASWG-R001 复核；若主理人倾向更保守客厅体验，−18 LUFS 为退档备选（改 Master 增益一处即可）。

---

## 6. 可访问性（对齐 Standard 档 · v1 基线）

> **总原则**：可访问性分级 v1 = **Standard**（accessibility-tier §3.1）。**语义色纪律是不可降级的设计底线**：音频如需与视觉同步只引用 Token 名（`THREAT`/`RESONANCE_GLOW`/`DAMAGE_WARN`），不写 hex。

### 6.1 【关键】敌人 telegraph 听觉预警——THREAT 的冗余通道
**问题**：色盲玩家看不出敌人/混沌的 `THREAT=#A62C6B` 品红 telegraph（accessibility-tier F1、色盲玩家对品红 telegraph 的读取风险）。**音频必须提供等价的、独立的预警冗余通道**，让不靠视觉也能"读招"。

- **触发与时序**：`enemy_telegraph_started(enemy, frames)` 一发出即在**第 0 帧**播预警音，覆盖整个 telegraph 窗口：
  - **Normal 档：36–72 帧**（0.6–1.2s，enemy-ai §② / §⑤）。
  - **Hard 档：24–48 帧**（0.4–0.8s）。
- **必须"可辨识"**：
  - 预警音**独占 2–5kHz 高中带**（§1.2 预留），战斗再密也能穿透（Tier 0 永不裁，§5.4）。
  - **按攻击类型/敌种区分动机**（如 Brute 重砸=低沉蓄力下坠、Skirmisher 突进=快速上扬咝声、Sentinel 远程=充能滴答、Boss 阶段=全屏谐波警号），让玩家听出"来的是什么招"，而不仅是"有招来"。
  - 与 §4 共鸣提示音、格挡"叮"在音色/频段上刻意区分，避免混淆。
- **必须"可定位"**：
  - 用 `AudioStreamPlayer3D`（§7.1）——预警音**从敌人所在方位发声**，玩家靠声像/距离判断转向哪里防御。
  - 屏幕外/背后威胁尤其依赖此通道；可选启用 HRTF/立体声增强定位（Godot 支持 3D 声像）。
- **低延迟front-loaded**：Hard 档 telegraph 短至 24 帧（0.4s），预警音必须**起音即给足信息**（瞬态前置），不能有慢起淡入吃掉反应时间。
- **telegraph 消解**：`enemy_telegraph_cleared(enemy)` → 预警音收束/停止（被格挡打断则转"破防"音，`enemy_staggered`）。
> **关联 CONCERN-1（心流）**：Hard 下限 24 帧对低技能玩家偏紧（accessibility-tier F7 / consistency CONCERN-1）。听觉预警是**守心流带的辅助**——即便看不清也能靠听觉抢反应，与"辅助预设 telegraph 延长"（F7）叠加使用。

### 6.2 音效字幕（Closed Caption for SFX）
为**关键非语音音效**提供文字标注（听障/静音游玩冗余）：
- 例：`[敌人蓄力·重击]`、`[Boss 阶段切换]`、`[共鸣就绪·可终结技]`、`[共鸣就绪·可开门]`、`[完美格挡]`、`[共鸣不足]`、`[存档失败]`。
- 呈现：屏幕下缘 caption 区（复用 UX-spec §5.3 字幕系统），**带方位指示**（左/右/后）以补 3D 预警的视觉端；随 F3 字号缩放。
> ⚠ **分级注意（见 CONCERN-AUD-4）**：accessibility-tier 把"全量字幕（含环境/战斗语音）/音频可视化"归 **Comprehensive**（F4/新增行），"音效 closed caption"严格说超出 Standard。本项目任务要求在 v1 提供——**建议将"关键 SFX caption"作为 Standard 的增补项纳入**（成本可控：一张事件→文案映射表 + 现有字幕控件），完整音频可视化仍留 Comprehensive。此分级归属需主理人/严守真（可访问性）确认。

### 6.3 对话/残响字幕
残响回声 VO 默认开字幕（F4，accessibility-tier / UX-spec §5.3），大小/背景/易读字体可调、可跳过（S7 §6）。**语言缺失回退文本**（S7 §6）。

### 6.4 单声道混音选项（Mono Downmix）
为单侧听力玩家提供"合并为单声道"设置：全总线声像塌缩为单声道输出（Godot 可在 Master 端做 mono 合并/或用相应输出通道设置）。
> 注意：开启后 §6.1 的**方位定位失效**——因此单声道模式下**必须同时强化 §6.2 字幕的方位文字提示**（左/右/后），保住"威胁来向"这一关键信息。

### 6.5 各总线独立音量
设置提供 **Master / Music / SFX / UI / Ambience / VO** 各自独立音量滑块（0–100%），运行时 `AudioServer.set_bus_volume_db()`。
> UX-spec §4.2 现仅列"主/音乐/音效"三项——**建议扩展为上述 6 条独立总线音量**（见 CONCERN-AUD-5，路由文策渊）。独立 VO/Ambience 音量对听障/听觉敏感/母语非中文玩家尤为重要。

### 6.6 其它听觉冗余（补视觉语义色）
- **共鸣池听觉化（§4）** 本身就是 HUD 共鸣条的听觉冗余（色盲看不清三态色时靠听）。
- **低血警告**：`player_hp_changed` 进入低血阈值 → 低血心跳/警示音（`DAMAGE_WARN` 语义的听觉等价，**非 THREAT**——守"THREAT 仅敌/混沌"铁律），补足低血视觉脉冲。
- **可交互提示音**：神龛/残响节点在可交互距离内给柔和青白提示音（补暖金 `INTERACT`/`FRIENDLY_GOLD` 视觉描边）。

### 6.7 与画质/难度档正交
音频可访问性项（字幕、mono、各总线音量、预警强度）**独立于 Low/High/Ultra 画质档与难度档**（对齐 architecture §6.4 / accessibility-tier §5 正交条款）。

---

## 7. 音频实现策略（Godot 4.7.1 / Forward+ / GDScript 强静态类型）

### 7.1 3D 音源：衰减、多普勒与混响区
| 项 | 决策 | 说明 |
|---|---|---|
| 播放器类型 | `AudioStreamPlayer3D`（世界事件）/ `AudioStreamPlayer`（UI、共鸣池床、音乐） | 见事件表 3D/2D 列 |
| 衰减模型 | `ATTENUATION_INVERSE_DISTANCE`（默认） | 远处衰减快，利于战斗峰值时的清晰度 |
| `unit_size` | 近战 4.0 / 环境 12.0 / Boss 20.0 / 敌人预警 8.0 | 预警音单独调大，保证 §6.1 恒可听 |
| `max_distance` | 近战 30 / 弹道 45 / Boss 80 / 0=无限（音乐、共鸣床） | 超距不取池，省语音数 |
| 多普勒 | `DOPPLER_TRACKING_PHYSICS_STEP`，**仅**用于「荡 Grapple 索线」「跃 Leap 风声」「Sentinel 弹道」 | 物理步跟踪 = 与 60Hz tick 对齐，确定性；近战/UI 关闭多普勒（省算力、避免音高抖动） |
| 混响 | `Area3D` + `reverb_bus_enable` 分区（洞窟／回廊／开阔遗迹／神龛），送 `Reverb` 总线 | 对齐 §1 空间感表，过渡由 Area3D 自带渐变 |
| 听者 | 直接用当前 `Camera3D`（Godot 默认），**不**手动挂 `AudioListener3D` | 锁定视角下听者=相机，与 ux-spec 锁定表现一致 |

### 7.2 音源池化（运行时零 `new()`）
**铁律**：`_physics_process` / tick 内**禁止** `AudioStreamPlayer3D.new()` 或 `add_child()`。全部在 `AudioDirector._ready()` 预分配、复用。

| 池 | 容量（建议） | 用途 |
|---|---|---|
| `pool_sfx_3d` | 48 | 全部世界音效（斩/闪/荡/跃/格/共鸣 + 敌人 + 环境一次性） |
| `pool_sfx_2d` | 12 | UI、非定位反馈、共鸣阈值提示音 |
| `player_music` | 1 | `AudioStreamInteractive` 主实例 |
| `player_res_bed` | 1 | 共鸣池连续床（`AudioStreamSynchronized`，常驻循环） |
| `pool_vo` | 2 | 旁白/角色语音（互斥，后到打断先到） |
| **合计常驻** | **64** | 与 §7.5 语音预算一致 |

**取用规则**：`AudioDirector.play_event(id: StringName, pos: Vector3, priority: int) -> void` → 取空闲实例；池满时按 §5 战斗峰值优先级**抢占「优先级最低且已播过 50%」的实例**；Tier-0（敌人预警、玩家受击、共鸣阈值跨越）**永不被抢占**。

### 7.3 AudioDirector 职责边界与 Autoload 依赖
**位置**：Autoload 第 6 位（`GameConstants→EventBus→ResonancePool→SaveManager→InputManager→AudioDirector→EchoDirector→DebugOverlay`）。

**只做四件事**：
1. **持有总线与音源池**：`_ready()` 建池、挂效果器（`SFX` 预挂 `AudioEffectLowPassFilter` 默认 20kHz 直通、`Master` 挂 `AudioEffectHardLimiter`）。
2. **订阅 EventBus 过去式信号**（§7.4 清单）→ 翻译为播放请求。
3. **持有三套状态机**：音乐 5 态（§2）、共鸣池 3 态（§4）、慢动作滤镜包络（§8）。
4. **读设置并应用**：从 `SaveManager` 取各总线音量 / mono / 字幕开关 / 预警强度，`AudioServer.set_bus_volume_db()`。

**绝不做**：不改游戏状态、不写存档、不发 EventBus 信号（EventBus 无逻辑、AudioDirector 只订阅不广播）、**不依赖 `EchoDirector` / `DebugOverlay`**（第 7、8 位，在其之后初始化）。

> ⚠️ **CONCERN-AUD-3｜Autoload 依赖声明需修订**
> architecture §4.3 现记 AudioDirector 依赖 `2`（EventBus）。但 §4 共鸣池听觉化要求在 `_ready()` 读一次 `ResonancePool.current` 建立**初始三态**（否则开局 50 点时床层错档，玩家一进游戏就听到"不足"层）。这是与 HUD 同款的 L3 属性查询。
> **建议改为依赖 `2,3`**（EventBus + ResonancePool）。ResonancePool 在第 3 位、早于第 6 位，**不破坏既定初始化顺序**。请程基岩确认。

### 7.4 EventBus 订阅清单（全部取自 architecture §5.2 既有信号）
在 `AudioDirector._ready()` 一次性 `connect()`，全程不解绑：

§5.2 现有 **21 条**信号，AudioDirector **全部订阅**（无一冗余）：

- **S3 共鸣**：`resonance_changed(new,old)` / `resonance_spend_rejected(cost,reason)` / `resonance_node_consumed(node_id)`
- **S1 战斗**：`player_hp_changed(new,old)` / `player_state_entered(state_name)` / `combo_advanced(count)` / `perfect_parry_landed(target)` / `finisher_executed(damage)`
- **S4 敌人**：`enemy_telegraph_started(enemy,frames)` / `enemy_telegraph_cleared(enemy)` / `enemy_staggered(enemy,frames)` / `enemy_died(enemy)` / `boss_phase_changed(phase)`
- **S5 世界 / S8 神龛**：`gate_opened(gate_id)` / `shrine_activated(shrine_id)` / `player_respawned(shrine_id)` / `island_entered(island_id)`
- **S7 残响**：`echo_triggered(echo_id)` / `echo_collected(echo_id,total)`
- **系统**：`save_completed(success)` / `settings_changed(key)`

> **关键结构性发现（影响 AudioDirector 接线方式）**：
> §5.2 **没有逐动词的战斗信号**（无 `slash_started`/`dash_started`/`grapple_attached` 等）。6 动词的动作音效**唯一的 L2 挂点是 `player_state_entered(state_name)`**——AudioDirector 按 `state_name` 分派（`Slash1..4` / `Dash` / `Grapple` / `Leap` / `Parry` / `Resonate`）。
> 而**帧级精确**的音效（挥砍破空的起音帧、命中"崩"、落地冲击）**不走 EventBus**，走 **L1 局部信号 / `AnimationPlayer` 的 Method Call Track**，由角色场景直接调 `AudioDirector.play_event()`。理由：L2 是"跨系统事实广播"，把每一帧的挥刀细节塞进全局总线既污染 EventBus 又增加派发开销（对齐 §5.1 三层通信红线）。
> **推论**：`AudioDirector.play_event()` 必须是**公开 API**，供 L1 直调；EventBus 订阅只负责"状态级/系统级"音频决策。

**必须知道当前值而非变化量**的场合走 **L3 权威查询**（不新增信号）：`ResonancePool.current` / `can_afford_finisher()`（§4 三态初始化与滞回判定）。

> 逐条映射（触发帧 / 总线 / 优先级 / 3D-2D / 可打断 / 可访问性角色）见 **`design/audio/audio-event-list.md`**。

### 7.5 性能预算
| 指标 | 预算 | 依据 |
|---|---|---|
| 同发语音数（并发 voice） | **≤ 64**（常驻池上限即硬帽） | 战斗峰值 20+ 源时估算占用 28–36，留约 2× 余量 |
| 音频内存（常驻 + 流缓冲） | **≤ 96 MB** | 音乐/环境 Ogg 流式；一次性音效 WAV 常驻 |
| 音频线程 CPU | **≤ 3%**（PC 基线） | Godot 音频跑**独立线程**，不占 `_physics_process` 的 16.67ms 帧预算 |
| 总线数 | 9（Master / Music / SFX / SFX_Combat / SFX_World / SFX_Resonance / Ambience / UI / VO）+ Reverb send | 效果器只挂 Master / SFX / Reverb，避免逐总线挂效果 |

> ✅ **与 architecture §7.3 不冲突**：§7.3 列的是主线程/渲染帧预算，**当前无音频行**；音频在独立线程，只与总内存竞争，不与帧预算竞争。
> **建议（给程基岩）**：在 architecture §7.3 增补一行「音频：并发语音 ≤64 / 音频内存 ≤96MB / 音频线程 CPU ≤3%」，并在 `DebugOverlay`（F3）增加**当前并发语音数**读数，Sprint 1 起即可监控抢占是否频繁触发。

---

## 8. 缺口 G7 收口：慢动作时的音频处理

> architecture §12.3 **G7「慢动作时的音频处理（§5.4）」交阮和鸣** —— 本节即最终结论，可直接据此实现。

### 8.1 先纠正一条技术前提（已核实）
派单与直觉都假设「`Engine.time_scale` 会顺带影响 AudioServer」。**在 Godot 4.x（含 4.7.1）这是错的**：

> Godot 官方 `Engine.time_scale` 文档明确写：**"这个属性不会影响音频的播放。请使用 `AudioServer.playback_speed_scale` 来调整音频播放的速度。"**

**结论 A（免费得到的性质）**：音频**默认就与 `Engine.time_scale` 解耦**。architecture §5.4 写的「`AudioDirector` 不随 `time_scale` 变调」**无需任何代码去"实现"，它是引擎默认行为**；反过来说，若哪天想让音频跟随时间缩放，必须**显式**调 `AudioServer.playback_speed_scale` 或 `AudioServer.set_bus_pitch_scale()`。

**结论 B（一个必须警惕的副作用）**：正因为解耦，`Engine.time_scale = 0` 的**暂停菜单**（ux-spec §4：进入暂停用 `Engine.time_scale` 暂停玩法）**不会自动停住音效与环境床**——玩家会听到暂停界面背后战斗音效继续播。这是一个**真实的待修 bug 风险**，需靠新增 `game_paused` / `game_resumed` 信号显式处理（见 §8.6 与事件表"需新增信号"）。

### 8.2 慢动作的来源与数值（照抄 GDD/架构，不臆造）
| 来源 | GDD/架构原文 | 时长 | 时间缩放比 |
|---|---|---|---|
| **完美格挡** | combat.md §⑤ / architecture §5.3：「敌人 Stagger 72 帧(1.2s) + **慢动作 0.3s (`Engine.time_scale`)**」 | **0.3s = 18 帧** | ⚠️ **未定义**（CONCERN-AUD-2） |
| **共鸣终结技** | combat.md §② 只写「全屏谐波脉冲，高伤 + 击退 4m」，**通篇未定义慢动作** | — | ⚠️ **不存在**（CONCERN-AUD-1） |
| **命中顿帧 hit-stop** | architecture §5.4：60–90ms ≈ **4–6 帧**，用 FSM `frozen_frames`，**不动全局 `time_scale`** | 4–6 帧 | 不适用（非时间缩放） |

> 派单假设"终结技触发慢动作"，但**上游 GDD 没有这条**。我不替战斗设计拍板，只把音频侧**设计成可插拔**：若后续文策渊补上终结技慢动作，音频侧**零改动**即可生效（同一套 `time_dilation_started` 驱动）。

### 8.3 判断（G7 最终结论）
**慢动作期间不做全局变调/变速；改为在 `SFX` + `Ambience` 上做一次短促「低通下潜 + 轻侧链」，同时叠加一层满保真的"特写层"；`Music` / `UI` / `VO` 完全免疫。**

四点理由：

1. **变调难听且伤辨识度**。把 SFX 拉到 0.3×，刀刃、金属、结晶这类**高频瞬态素材**会变成失真的低吼，且**音高本身是本作的语义载体**（§3 每动词独占频段、§4 共鸣三态靠音高/明亮度区分）。变调 = 把辨识系统一起拖垮。
2. **可访问性硬约束优先**。§6.1 敌人 telegraph 预警音是色盲玩家的**唯一冗余通道**，其识别依赖**固定音色与固定频段（2–5kHz）**。完美格挡后的 18 帧里若发生全局变调，预警音会变形，**可访问性通道当场失效**——这是不可接受的。
3. **低通才是"子弹时间"的通用听感语言**。玩家对慢动作的听觉预期是**"世界闷下去、聚焦拉近"**（水下感/耳鸣感），而非"磁带变慢"。低通 + 让路 + 特写层精确表达这个预期，且**完全不动音高**。
4. **成本与确定性**。低通只是一个总线效果器的 `cutoff_hz` 包络，**零额外语音数、零额外内存**，且与 §7.5 预算无关；而全局 `playback_speed_scale` 会牵动所有正在播的流（包括音乐的分层同步），**破坏 §2 的按拍对齐**。

**唯一保留的"跟随时间"的可能**：作为**可访问性/口味选项**，提供一个默认关闭的「慢动作音效降速」开关（仅作用于 `SFX` 总线，`set_bus_pitch_scale(SFX, ~0.85)`，**绝不含 Music/UI/预警音**）。默认关，避免上面第 2 条风险。

### 8.4 实现路径（Godot 4.7.1，可直接照做）

**① 效果器：哪个、挂哪条总线**
| 总线 | 效果器 | 默认值（透明） | 慢动作值 |
|---|---|---|---|
| `SFX` | `AudioEffectLowPassFilter`（**S0 即预挂**，`idx=0`） | `cutoff_hz = 20500` | `cutoff_hz ≈ 1800`，`resonance ≈ 0.6` |
| `Ambience` | `AudioEffectLowPassFilter`（预挂） | `cutoff_hz = 20500` | `cutoff_hz ≈ 1200` |
| `Music` | 无（不参与） | — | — |
| `UI` / `VO` | 无（不参与） | — | — |

> **必须在 `_ready()` 预挂、运行时只改参数**——运行时 `add_effect()` 会导致音频线程重建效果链，可能爆音。

**② 驱动信号（需新增，见 §9）**
```gdscript
# EventBus 新增（过去式命名，符合 §5.1 红线）
signal time_dilation_started(scale: float, duration_frames: int)
signal time_dilation_ended()
```
由**发起慢动作的一方**（完美格挡逻辑所在的战斗 FSM）在设置 `Engine.time_scale` 的**同一帧**发出。AudioDirector 只订阅、不发起。

**③ 包络：用 `set_ignore_time_scale()` 的 Tween（关键坑）**
包络本身**绝不能被 `time_scale` 拖慢**，否则"下潜"要花 0.3s/scale 的真实时间才走完，慢动作都结束了滤镜还没到位。Godot 4 内置解法：

```gdscript
func _on_time_dilation_started(_scale: float, _duration_frames: int) -> void:
    var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_bus_sfx, 0)
    _dip_tween = create_tween().set_ignore_time_scale()   # ← 关键：忽略 Engine.time_scale
    _dip_tween.tween_method(
        func(v: float) -> void: lp.cutoff_hz = v,
        lp.cutoff_hz, 1800.0, 0.04)                        # 40ms 真实时间下潜
```

- **`Tween.set_ignore_time_scale()`**：Godot 4 内置方法，令补间按真实时间推进。
- 若需延时，用 `get_tree().create_timer(sec, true, false, true)` —— **第 4 个参数 `ignore_time_scale = true`**（漏了它，计时器会在慢动作里一起变慢，永远等不到结束）。
- **回升**：`time_dilation_ended` → 同款 Tween，`1800 → 20500`，**120ms**（回升比下潜慢，避免"啪"地弹回）。
- 备选（不依赖 Tween）：在 `_process()` 里用 `Time.get_ticks_msec()` 手推包络——`Time.get_ticks_msec()` 是真实墙钟，同样不受 `time_scale` 影响。

**④ 侧链让路**：慢动作期间 `Music` 额外 duck **−3 dB**（复用 §5.3 的 `AudioEffectCompressor` 侧链，或直接 `set_bus_volume_db` 走同一条 ignore-time-scale Tween），让特写层站出来。

**⑤ 特写层（Close-up Layer）——满保真、不过低通**
特写层**从 `UI` 或专用 `SFX_Resonance` 总线出**（**绕开被下潜的 `SFX`**），因此始终清亮：
| 时机 | 特写层内容 |
|---|---|
| 完美格挡（`perfect_parry_landed`） | 一记极近距、极干净的**水晶"叮"** + 一道极轻的反向 whoosh（"世界被推开"）；对齐概念文档「完美格'叮' + 慢动作」 |
| 终结技（`finisher_executed`） | 谐波 swell 起音 + 低频体量（若将来加入慢动作，则 swell 起音落在下潜段，脉冲释放落在回升段） |

**⑥ 帧对齐（整数帧，不用秒）**
慢动作 18 帧内的音频节点按**帧**表述：`F0` 下潜起 + 特写层触发 → `F2`（≈40ms 真实）到达最低 cutoff → `F18` 收到 `time_dilation_ended` → 回升 120ms 完成。**滤镜包络本身用真实毫秒**（它是表现层、非玩法判定），**玩法侧一律整数帧**——两者边界清晰，不违反 §3 时间基准。

### 8.5 暂停菜单必须显式处理（结论 B 的落地）
因 `Engine.time_scale = 0` **不停音频**，AudioDirector 需订阅新增的 `game_paused` / `game_resumed`：
- `game_paused` → `SFX` / `Ambience` **淡出至静音（80ms，ignore time scale）**或整体 duck −40 dB；`Music` duck −12 dB 保留（常见做法，维持氛围）；`UI` 保持 0 dB（菜单要有反馈音）。
- `game_resumed` → 反向淡入 120ms。
- **不要**用 `AudioServer.playback_speed_scale = 0` 或暂停总线来实现——会让音效在恢复时从中断处继续，听感突兀。

### 8.6 与 architecture §5.4 的对齐/修订
| architecture §5.4 原文 | 本节结论 | 处理 |
|---|---|---|
| 「hit-stop 用 tick 冻结而非 `time_scale=0`……避免影响 UI 与音频」 | ✅ 一致。hit-stop 的听感由**命中音自身瞬态**表达（§3），音频侧**零处理** | 保留原文 |
| 「`AudioDirector` 不随 `time_scale` 变调（音高扭曲会很难听）」 | ✅ 结论一致，但**理由需更正**：这不是 AudioDirector"做到"的，而是 **Godot 引擎默认行为**（`time_scale` 不影响音频） | 建议改写该句 |
| 「`[GAP]` 慢动作时是否要做音频低通滤镜，交阮和鸣定」 | ✅ **收口：做**。`SFX` 20500→1800Hz、`Ambience` →1200Hz，40ms 下潜 / 120ms 回升，+ Music duck −3dB，+ 特写层 | **G7 可标记 RESOLVED** |
| （§5.4 未提暂停） | ⚠️ **新增风险**：`time_scale=0` 不停音频，暂停时音效会漏播 | 建议 §5.4 补一条，并新增 `game_paused`/`game_resumed` |

---

## 9. 对外修订建议与遗留关注项

> 本节**只是建议**。我不修改他人文档，请主理人分发给对应负责人。

### 9.1 ENG-S0-05 第 6 项 `AudioDirector` —— 建议改写
**现文**（`production/epics/epic-s0-foundation.md:62`）：
> `- [ ] 6 AudioDirector（Master/Music/SFX/UI/Ambience 总线骨架）。`

**建议改为**：
> `- [ ] 6 AudioDirector（依赖 1–3；见 design/audio/audio-direction.md §7）：`
> `  - [ ] 6a 总线树：Master / Music / SFX / SFX_Combat / SFX_World / SFX_Resonance / Ambience / UI / VO + Reverb(send)，dB 目标按 §5.2。`
> `  - [ ] 6b 效果器 _ready() 预挂（运行时禁止 add_effect）：Master→AudioEffectHardLimiter(ceiling −1 dBTP)；SFX→AudioEffectLowPassFilter(cutoff 20500 透明)；Ambience→AudioEffectLowPassFilter(20500)。`
> `  - [ ] 6c 音源池预分配：sfx_3d×48 / sfx_2d×12 / music×1 / res_bed×1 / vo×2 = 64；提供 play_event(id, pos, priority) 公开 API 供 L1 直调；tick 内禁止 .new()。`
> `  - [ ] 6d 订阅 EventBus 全部 21 条信号（§7.4）；_ready() 用 L3 读 ResonancePool.current 初始化共鸣三态。`
> `  - [ ] 6e 慢动作滤镜包络（G7）：订阅 time_dilation_started/ended，Tween 必须 set_ignore_time_scale()。`
> `  - [ ] 6f 暂停音频处理：订阅 game_paused/game_resumed（Engine.time_scale=0 不会停音频，必须显式 duck）。`
> `  - [ ] 6g 从 SaveManager 读 6 条总线音量 + mono + 字幕开关并应用。`

**同时建议**：`epic-s0-foundation.md` Autoload 依赖表把 `AudioDirector` 的依赖由 `2` 改为 `2,3`（见 CONCERN-AUD-3）。
**同时建议**：`production/sprint-01-plan.md` §8「音频挂接点」的三项待回填内容已分别由本文档 §5.2（总线/dB）、§4（共鸣三态听觉化）、§6.1（telegraph 预警）交付，可直接回填并把风险表第 145 行的 🟡 降级。

### 9.2 CONCERN-AUD-N（需上游拍板，我未替其决定）

| ID | 关注项 | 影响 | 建议路由 |
|---|---|---|---|
| **CONCERN-AUD-1** | **派单假设"终结技触发慢动作"，但 GDD combat.md §② 通篇未定义终结技慢动作**（只有"全屏谐波脉冲/高伤/击退 4m"）。 | 音频侧已按"可插拔"设计，**当前不阻塞**；但若战斗设计确实想要，需补 `time_scale` 比与时长（整数帧）。 | 文策渊（战斗）+ 主理人拍板 |
| **CONCERN-AUD-2** | **完美格挡慢动作只给了时长 0.3s，未给 `Engine.time_scale` 比值**（0.3? 0.5? 0.1?）。 | 不影响 G7 结论（低通方案与比值无关），但影响**特写层的听感调校**与 §8.4 包络时长的最终定档。 | 文策渊（战斗）；建议随手补进 `systems-index §2` 常量表 |
| **CONCERN-AUD-3** | architecture §4.3 记 `AudioDirector` 依赖 `2`，但 §4 共鸣听觉化需在 `_ready()` L3 读 `ResonancePool.current`。 | 不改则**开局 50 点时共鸣床层错档**。ResonancePool 在第 3 位、早于第 6 位，改动无风险。 | 程基岩，建议改为 `2,3` |
| **CONCERN-AUD-4** | **SFX 音效字幕（closed caption）超出 accessibility-tier v1.0 的 Standard 档承诺范围**。 | 这是听障玩家获取"敌人起手/共鸣就绪"信息的唯一通道，与 §6.1（给色盲的听觉冗余）互为镜像。不做则听障侧存在等价缺口。 | 严守真（可访问性）+ 主理人：**是否将"关键音效字幕"提升为 Standard 档必做** |
| **CONCERN-AUD-5** | `ux-spec.md §4.2` 设置页仅列 **主/音乐/音效** 三条音量，本方案需要 **6 条**（Master/Music/SFX/UI/Ambience/VO）。 | 独立 VO / Ambience 音量对听障、听觉敏感、母语非中文玩家是实质可访问性项。 | 文策渊（UX）扩展设置页 |
| **CONCERN-AUD-6** | **`Engine.time_scale = 0` 的暂停不会停止音频**（Godot 引擎行为），而 ux-spec §4 的暂停正是用 `time_scale` 实现。 | **真实 bug 风险**：暂停菜单背后战斗音效继续播。需新增 `game_paused`/`game_resumed`。 | 程基岩（架构 §5.4 补一条）+ 文策渊知会 |
| **CONCERN-AUD-7** | §5.2 **无逐动词战斗信号**，6 动词音效只能挂 `player_state_entered(state_name)` + L1/动画轨。 | 不算缺陷（符合三层通信红线），但需程基岩确认 **`state_name` 的枚举取值**（`Slash1..4`/`Dash`/`Grapple`/`Leap`/`Parry`/`Resonate`？）才能写死分派表。 | 程基岩确认状态名清单 |

### 9.3 需新增的 EventBus 信号（汇总）
详细参数与发出方见 **`design/audio/audio-event-list.md` §3**。共 **6 条**，全部过去式、全部为"陈述已发生事实"，不违反 §5.1 红线：
`time_dilation_started` / `time_dilation_ended` / `game_paused` / `game_resumed` / `combat_state_changed` / `echo_finished`

---

**文档版本**：v1.0（2026-08-10）　**作者**：阮和鸣（音频总监）　**状态**：待主理人评审
**下游**：`design/audio/audio-event-list.md`（逐事件映射表）　**收口缺口**：architecture §12.3 **G7 → RESOLVED**
