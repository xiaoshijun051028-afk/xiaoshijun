# UX 规格文档 · 星陨之境 (Aetherfall)
> 文档类型：UX 规格（预制作可执行）｜ 任务 T4-DESIGN（P0）｜ 评审 Solo
> 上游：概念 v0.2、GDD ×10（重点 S1/S6/S7）、systems-index §2、美术圣经 v0.1（§2.3/§5/§7/§9）、可访问性分级 v1.0（Standard）、主架构 v1.0（§3/§5/§8/§9）、ColorTokens v1.0（林绘澄定稿，CONCERN-A 已收口）
> 下游：Phase 4 预制作、HUD/输入/设置实现、程基岩 InputMap/EventBus 落地
> 锁定决策：lock-on = **做**（G8，用户拍板）；语义色冲突由 ColorTokens 定稿，systems-index 将同步。

---

## 0. 范围与上游对齐
- 本规格是 HUD、输入、相机锁定、菜单/设置、可访问性的**唯一 UX 事实依据**。所有数值引用 systems-index §2 / GameConstants，不在此硬编码。
- 语义色一律取自 **ColorTokens**（单一来源），禁止 hex 字面量；`THREAT=#A62C6B` 仅敌/混沌专属（可访问性 §0 铁律）。
- 可访问性基线 = **Standard**（v1），覆盖 F1–F8；下文每项均标对应特性。
- 输入层完全对齐架构 §8：`InputMap` 动作名固定、`InputManager` 裁决优先级与设备仲裁、输入缓冲 ≤6 帧。

---

## 1. 输入映射总表

### 1.1 动作命名（与架构 InputMap 对齐，全项目唯一命名源）
- 玩法动词：`verb_slash` / `verb_dash` / `verb_grapple` / `verb_leap` / `verb_parry` / `verb_resonate`
- 新增锁定：`verb_lockon`
- 移动：`move_forward/back/left/right`；视角：`look`（鼠标 / 右摇杆）
- 系统：`ui_pause` / `ui_interact` / `ui_map` / `debug_overlay`

### 1.2 默认绑定（键鼠 + 手柄）
| 动作 | 键鼠 | 手柄（Xbox） | InputMap 名 | 备注 |
|---|---|---|---|---|
| 斩 Slash | 鼠标左键 | X / RB | `verb_slash` | 4 段连段 |
| 闪 Dash | 鼠标右键（Shift 备选） | A | `verb_dash` | iframes 10f |
| 荡 Grapple | E（瞄准锚点） | RT | `verb_grapple` | 钩索拉向锚点/敌人 |
| 跃 Leap | 空格 | B | `verb_leap` | 垂直起跳 |
| 格 Parry | Q | LT | `verb_parry` | 窗口 6f |
| 共鸣 Resonate | F | Y | `verb_resonate` | 节点/终结技 |
| **共鸣终结技** | F（斩末段时机） | Y（斩末段时机） | `verb_resonate`（情境） | **情境动作**：斩连段末段按共鸣触发，不新增绑定 |
| **Lock-on** | 鼠标中键 | LB（左肩） | `verb_lockon` | 新增；见 §2 |
| 互动 Interact | E（情境，见下） | A（情境，见下） | `ui_interact` | 神龛/残响节点 |
| 移动 | WASD | 左摇杆 | `move_*` | — |
| 视角 | 鼠标 | 右摇杆 | `look` | — |
| 暂停 | Esc | Start | `ui_pause` | 进暂停菜单 |
| 目标/地图 | M | Select | `ui_map` | 目标追踪开关 |

> **E 键情境仲裁**：`E`（键鼠）/ `A`（手柄）在"准星对锚点"时解析为 `verb_grapple`，在"面向神龛/残响节点"且无障碍锚点时解析为 `ui_interact`。两情境互斥，由 `InputManager` 按射线目标裁决（沿用架构 §8.1 优先级裁决模式）。避免新增绑定冲突。

### 1.3 可重映射（呼应可访问性 F6 / 架构 §8.4）
- **全动作可重映射**，KBM 与手柄两套独立映射表。
- 存储 `user://input_map.json`，与存档分离（换档不丢按键）。运行时 `InputMap.action_erase_events()` + `action_add_event()` 应用。
- 冲突检测：同组重复绑定给警告并允许覆盖。
- **可访问性附加项**（Standard）：① 格挡/瞄准可设 toggle（切换而非长按）；② 斩可设"按住自动连段"（连点辅助）；③ 死区/灵敏度独立可调；④ 输入缓冲 ≤6 帧（架构 §7.5）降感知延迟。
- **CANCEL_WINDOW 不在此提供放宽**（见 §5.1），避免破坏 P1 与平衡。

---

## 2. lock-on 摄像机规格（决策：做）

> 依据：G8 已定"做 lock-on"；引用战斗 GDD S1 §②（动词 FSM 不变、取消窗口 8f）；架构 §2.2（CameraRig 与 Player 解耦、§7.4 相机 `_process` 跟随、传送后 `reset_physics_interpolation()`）。

### 2.1 层级定位
lock-on 是**相机/目标锁定层**，由 `CameraRig` + `InputManager` 承载，**不进入战斗 FSM**——因此不消耗取消窗口、不影响 `CANCEL_WINDOW=8f`、不破坏 P1 流动。锁定状态为 `CameraRig` 的 `locked_target: Node3D` 引用。

### 2.2 锁定获取（Acquisition）
- **手动获取**：按 `verb_lockon` → 在相机前向 **±35° 视锥**、**≤22 m** 内选最近敌人锁定；无目标则无操作。
- **切换目标**：锁定中再按 `verb_lockon` 或滚轮/右摇杆点按 → 在视锥内循环至下一敌人。
- **自动获取（可选辅助）**：敌人进入近战范围且未锁定时，可启用"自动锁定最近"（**设置默认 OFF**，保玩家 agency 与 Challenge 美学）。此开关归可访问性/辅助预设（F7）。

### 2.3 锁定丢失（Loss）
- 目标死亡（`enemy_died`）→ 自动释放，或切换至次近敌人。
- 目标超出 **22 m** 持续 >0.5s → 释放。
- 目标脱离视锥/被遮挡持续 >0.5s → 释放（软跟随窗口极短）。
- 玩家再按 `verb_lockon` → 主动释放。
- 切换/释放后 `CameraRig` 调用 `reset_physics_interpolation()` 防拉丝（架构 §7.4）。

### 2.4 软锁 / 硬锁（Soft vs Hard）
- **硬锁（默认）**：相机 yaw 缓动跟随目标（仅水平，玩家保垂直自由）；斩/格对目标做**轻微瞄准辅助**（小幅 yaw 校正，非自动命中，守 Challenge）；闪/荡方向语义见 2.5。
- **软锁（辅助/可访问性）**：相机仅轻微偏向目标、无瞄准吸附；降低旋转幅度以缓解眩晕（呼应 F5）。设置项「锁定强度 = 硬/软」。
- Boss 战默认硬锁（可读性与聚焦）；群怪可用软锁。

### 2.5 对 闪/荡 方向语义的影响
- **闪 Dash**：锁定中若玩家给移动方向 → 朝该方向（相机相对）；若无方向 → **朝目标突进**（gap-closer），直接服务 P1 流动与连段衔接。
- **荡 Grapple**：锁定中且未显式瞄准锚点 → 钩索自动锁定目标敌人（可拉至敌身）；显式锚点优先。
- 斩/格：锁定目标的微弱瞄准辅助提升命中可靠度，但取消窗口、伤害判定不变。

### 2.6 与 telegraph 配合
- 全局威胁标记（S6）不变：所有敌人 telegraph 显 `THREAT=#A62C6B` 边缘脉冲（2 Hz）。
- 锁定目标**额外加中央准星 + THREAT 高亮**，聚焦读招；敌人 telegraph 起手时相机可极轻缓动（仅表现，无 gameplay 慢动作）辅助阅读。
- 此层不新增任何语义色，严守 `THREAT` 仅敌/混沌纪律。

---

## 3. HUD 规格

### 3.1 五类核心元素（防认知过载，S6 §②）
| # | 元素 | 呈现（Diegetic 倾向，美术圣经 §7.1） | 数据来源（EventBus） |
|---|---|---|---|
| 1 | **HP** | 星核球（star-core orb），锚定左下；低血用 `DAMAGE_WARN`（炽红 #E5484D，**非 THREAT**）脉冲，不靠色相单编码 | `player_hp_changed` |
| 2 | **共鸣池** | 刃能环（blade-energy ring）环绕星核球；三态色（§3.2） | `resonance_changed` |
| 3 | **威胁标记** | 全屏边缘 `THREAT` 脉冲（2 Hz）+ 锁定目标中央准星 | `enemy_telegraph_started/cleared`、`boss_phase_changed` |
| 4 | **连段** | 小型计数（0–4），空闲淡出 | `combo_advanced` |
| 5 | **目标** | 右上箭头 + 距离，用 `FRIENDLY_AMBER`（暖金）线索色 | `island_entered` / 世界目标 |

> Boss 血条 = 威胁标记的延伸（底部居中，用 `THREAT`，因 Boss 为敌），**不**计为第 6 核心元素。

### 3.2 共鸣三态色（复用 ColorTokens，架构 §4.6）
- ≥ `FINISHER_COST`(40)：`RESONANCE_GLOW`（青白）——「可终结技」
- ≥ `GATE_COST`(30)：`GATE_READY`（暖金/teal）——「可开门」
- < 30：`INACTIVE`（灰）——不足；池不足终结技时灰显 + 提示（S1 §⑥）

### 3.3 Diegetic 与可读性平衡
- 星核球/刃能环为 diegetic 母题，但**保高可读**：球体/环有清晰数值映射（大小/填充），不纯装饰；低血/低共鸣有强反馈。
- 不做「低血才显 HP」动态 HUD（见 §5.3）——HP 常驻，保可读性与可访问性可见性。

### 3.4 可访问性 Standard 落点
- **F3 字号**：HUD≥18 / 菜单≥20 硬底线；全局放大滑块至 **150%**（Theme + `content_scale_factor`），九宫格锚定 720p–4K。
- **F4 字幕**：默认开、大小/背景可调、易读字体；残响字幕见 §5.3。
- **F5 动效**：镜头抖动 / 暗角 / 故障闪烁**独立强度滑块（可归零）**，经 CompositorEffect 统一乘数（架构 §6.1）。
- **F1 色盲**：切换 `ColorTokens` 第二套 cvd 变体（Protan/Deutan/Tritan），形状编码（菱形+脉冲）保留。
- **F8 语义色纪律**：全 HUD 严守 `THREAT` 仅敌/混沌。
- **状态源断连**（S6 §⑥）：显示最后已知值 + `?`，不崩溃。

---

## 4. 菜单 / 暂停 / 设置规格

### 4.1 暂停菜单（Esc / Start）
`继续` → `设置` → `技能树(S8)` → `地图(ui_map)` → `返回主菜单`。进入暂停 `Engine.time_scale` 暂停玩法（保留 UI 补间）。

### 4.2 设置子树
- **画面**：画质 Low/High/Ultra（架构 §6.4）、垂直同步（Adaptive/Off）、交换链缓冲。
- **音频**：**6 条独立总线音量滑块**（v0.3 扩展，收口 CONCERN-AUD-5；命名与 `audio-direction.md` §5.1 总线树严格对齐，默认 dB 引用 §5.2）：

  | # | 滑块显示名 | 总线 ID | 名义 dB（滑块 100% 位） | 作用范围 |
  |---|---|---|---|---|
  | 1 | 主音量 Master | `Master` | **0 dB** | 全局总输出；挂 `AudioEffectHardLimiter`（ceiling −1 dBTP）安全网 |
  | 2 | 音乐 Music | `Music` | **−8 dB** | 自适应音乐流（§2 五态）；免疫 `Engine.time_scale` |
  | 3 | 音效 SFX | `SFX` | **−3 dB** | 玩法音效母线（听觉主角）；含全部 `SFX_*` 子总线 |
  | 4 | 界面 UI | `UI` | **−6 dB** | 菜单 / HUD 反馈音；免疫 `time_scale`；慢动作特写层亦走此路 |
  | 5 | 环境 Ambience | `Ambience` | **−18 dB** | 风 / 云海 / 区域氛围床 |
  | 6 | 语音 VO | `VO` | **−3 dB**（锚定 ~−16 LUFS） | 残响回声语音（S7）；驱动 Music/Ambience 侧链 duck |

  **滑块行为规则**
  - 范围 **0–100%**，**默认全部 100%**。100% = 上表名义 dB。混音平衡已由 audio-direction §5.2 内建，滑块只做**相对增减**，不要求玩家自己去"调平衡"。
  - 应用式：`AudioServer.set_bus_volume_db(bus, nominal_db + linear_to_db(pct))`；`pct = 0` 时直接静音（写 −80 dB 或 `set_bus_mute`），**不得**调用 `linear_to_db(0)`（= −inf，会污染混音链）。
  - 子总线 `SFX_Combat` / `SFX_World` / `SFX_Resonance` / `Reverb(send)` **不暴露给玩家**（防认知过载，同 §3.1 五元素纪律），随父 `SFX` 联动。
  - 变更走 `EventBus.settings_changed("audio.volume.<bus>")`（§4.3），存 `user://settings.json`，与存档分离。
  - **可访问性落点**：独立 `VO` / `Ambience` 音量是听障、听觉敏感、母语非中文玩家的实质可访问项（audio-direction §6.5）。`Ambience` 可归零而**不影响敌人 telegraph 听觉预警**——预警在 `SFX_Combat`、Tier 0 永不裁（audio-direction §6.1 / §5.4），色盲玩家的冗余通道不会被音量设置误关。
- **可访问性（常驻入口，Standard 要求）**：
  - 色盲模式：关 / Protan / Deutan / Tritan（F1）
  - 高对比模式（F2）
  - 字号放大：100%–150%（F3）
  - 字幕：开/关、大小、背景（F4）
  - 镜头抖动 / 暗角 / 故障强度滑块（可归零）（F5）
  - 难度辅助预设（辅助格挡窗口 / telegraph 延长）（F7）
  - 锁定强度：硬 / 软（§2.4）
- **输入/控制**：
  - 重映射（F6，§1.3）
  - 死区 / 灵敏度
  - 辅助模式（取消窗口放宽至 10f，见 §5.1）
  - 连点辅助 / toggle 选项（§1.3）

### 4.3 一致性
所有设置变更经 `EventBus.settings_changed(key)` 广播（架构 §5.2），HUD/相机/ColorTokens 订阅刷新；设置存 `user://settings.json`，与存档分离。

---

## 5. 开放问题收口

### 5.1 CANCEL_WINDOW 是否给可访问性放宽
- **建议：默认不放宽（保持 8f）**，守住 P1「流动即正义」与 S1 §⑦ 验收「取消延迟 ≤8 帧」、连段中断率 <5%。放宽会直接废掉该验收且改变核心手感。
- **提供可选「辅助模式」开关（默认 OFF）**：开启时 `CANCEL_WINDOW` 放宽至 **10f**，作为运动差异玩家的出口；对应 S1 §⑦ 测试加注「辅助模式开启时窗口放宽至 10f，断言同步放宽」。
- 主路径靠 §1.3 辅助项（toggle 格挡、自动连段、死区）与 F7 难度辅助满足差异，而非放宽取消窗口。
- **已拍板（v0.2）**：「辅助模式」纳入 v1，但**默认 OFF**，归 Standard F7 同族。默认 `CANCEL_WINDOW = 8f` 不放宽（守 P1 中断率 <5% 与 S1 §⑦ 验收）。测试须含**分支覆盖**：默认 8f 与辅助 10f 两条路径均断言；程基岩分支测试标 `assist-mode` tag。

### 5.2 G6 共鸣潮汐周期（初值建议）
- **建议初值：90–120 s（1.5–2 min）循环**，驱动 Key 光色温与天幕染色（架构 §6.2 的 `Curve`+`Gradient`）。
- 架构 §6.2 曾列「6–8 分钟」为过慢、玩家难察觉氛围呼吸；90–120 s 更贴合「可感知的节奏」。参数化于 ColorTokens/Curve，易调。
- **已收口（v0.2）**：`RESONANCE_TIDE_PERIOD_SEC = 90–120` 初值定稿，参数化于 `ColorTokens`/资源（架构 §6.2 已同步），不改代码；与美术氛围节奏后续可在该区间微调。

### 5.3 残响叙事（S7）UX 呈现
- **字幕默认开**（F4 Basic）；残响文本以字幕形式呈现（底部居中、`RichTextLabel` + 背景 `Panel`），**可跳过**（S7 §6：8–20s 可跳过，按任意动词/确认键）。
- **说话者/残响标识**：显示残响名 + 来源节点，便于「发现」进度感知。
- **色盲安全**：残响文本/标识用 `RESONANCE_GLOW` 或 `FRIENDLY_*`，**不**用 `THREAT`。
- **战斗中触发**：半透明叠加、不暂停（S7 §6），保持流动；字体随 F3 缩放。
- **语言缺失**：回退文本不阻断（S7 §6）。
- 残响是否影响结局（S7 开放问题）不影响 UX 渲染层，路由主理人/叙事。

### 5.4 S6 其余开放问题收口
- **动态 HUD（低血才显 HP）**：**不做**。HP 常驻（可读性 + 可访问性可见性优先）；低血用 `DAMAGE_WARN` 脉冲表达。
- **拍照模式（Should）HUD 隐藏**：规则 = 进入拍照模式全 HUD 隐藏，仅保留可选 diegetic 星核球/刃能环；退出恢复。

---

## 6. 一致性勾稽

### 6.1 与架构 InputMap / EventBus
| UX 项 | 架构对应 | 状态 |
|---|---|---|
| 动作名 `verb_*` / `ui_*` | 架构 §8.1/§8.2 | ✔ 沿用；新增 `verb_lockon`/`ui_interact` 已补 |
| HUD 订阅信号 | 架构 §5.2 EventBus（`resonance_changed`/`player_hp_changed`/`combo_advanced`/`enemy_telegraph_*`/`boss_phase_changed`/`echo_*`/`settings_changed`） | ✔ 全部存在 |
| HUD 纯投影 | 架构 §4.6（不持有状态） | ✔ 一致 |
| 输入缓冲 ≤6 帧 / 优先级 格>闪>斩 | 架构 §7.5 / §8.1 | ✔ 一致 |
| ColorTokens 单一来源 | 架构 §9（CONCERN-A 已由林绘澄定稿 v1.0） | ✔ 引用名称，无 hex 字面量 |

### 6.2 与可访问性 Standard（F1–F8）
F1 色盲 / F2 高对比 / F3 字号 / F4 字幕 / F5 动效滑块 / F6 重映射 / F7 难度辅助 / F8 语义色纪律 —— **全部在 §1.3 / §3.4 / §4.2 落点**。Standard 基线满足。

### 6.3 语义色纪律（铁律）
- `THREAT=#A62C6B` 仅敌/混沌（威胁标记、Boss 血条、telegraph）。✅ 全文档未外溢。
- **CONCERN-UX-1（收口 GDD S6 §⑤ 不一致）**：S6 §⑤ 原写「低血 `THREAT` 闪」违反「THREAT 仅敌/混沌」纪律（可访问性 §0、美术圣经 §2.5）。本规格定低血用 `DAMAGE_WARN`（炽红 #E5484D，美术圣经 §2.3「伤害/警告」语义）。**✅ 已回改 GDD S6 §⑤ 一行**（低血 `DAMAGE_WARN(#E5484D)` 闪），与本规格一致（不破 P1/P4，纯色彩纪律修正）。
- 共鸣三态 / 线索 / UI 底均走 ColorTokens，色盲变体覆盖。

### 6.4 与战斗 S1 / 世界 S5
- lock-on 不进 FSM、不动 `CANCEL_WINDOW`（§2.1）——守 P1。
- 终结技 = `verb_resonate` 情境触发（§1.2）——与 S1 §② 一致。
- 神龛/残响 `ui_interact` 情境绑定（§1.2）——与 S5/S7 节点一致。

---

## 7. 待主理人 / 跨职能拍板项
1. **CANCEL_WINDOW 辅助模式**（§5.1）→ ✅ 已拍板：纳入 v1 默认 OFF，默认 8f 不放宽。
2. **G6 共鸣潮汐周期**（§5.2）→ ✅ 已收口：`RESONANCE_TIDE_PERIOD_SEC = 90–120s`（架构 §6.2 同步）。
3. **CONCERN-UX-1**：GDD S6 §⑤ 低血色 → ✅ 已回改为 `DAMAGE_WARN`，见 S6 §⑤。
4. **自动锁定（§2.2）**默认 OFF 是否合理 → 主理人/测试反馈。
5. **CONCERN-AUD-5 音量滑块 3→6**（§4.2）→ ✅ 已收口：扩为 Master/Music/SFX/UI/Ambience/VO 六条独立总线音量，命名与 audio-direction §5.1 对齐、默认 dB 引用 §5.2。
6. **CONCERN-AUD-6（知会）**：§4.1 暂停用 `Engine.time_scale = 0`，但 Godot 4 中 `time_scale` **不影响音频**——暂停时战斗音效会继续播（真实 bug 风险）。UX 侧结论：暂停菜单必须有"背景音已压低"的听感。落地方案见 audio-direction §8.5（新增 `game_paused`/`game_resumed` 显式 duck），**归程基岩**，本规格不改 §4.1 交互流程。

---

> 本规格可直接交付程基岩做 InputMap/EventBus/HUD 实现、林绘澄做 ColorTokens 消费、严守真做可访问性 Standard 落地。
