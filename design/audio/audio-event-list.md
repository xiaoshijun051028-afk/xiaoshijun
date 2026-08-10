# 星陨之境 Aetherfall · 音频事件清单 Audio Event List

**版本** v1.1（2026-08-10）　**作者** 阮和鸣（音频总监）　**状态** 待主理人评审
**上游** `design/audio/audio-direction.md`（听觉方向，本表为其逐事件落地）
**权威依赖** `docs/architecture/architecture.md` §5.2（EventBus 定义 + `state_name` 闭集）、§3（时间基准）、`docs/architecture/adr-003.md` §1（FSM 状态节点树）、`design/gdd/*`

> **v1.1 变更（T4-AUDIO-fix，2026-08-10）**：修正 §2.1 斩击接线。v1.0 把 `Slash1`~`Slash4` 当作四个独立状态名传给 `player_state_entered`，**该假设不成立**——`ADR-003` §1 与 `architecture.md` §5.2 均明确「4 段连段由 `combo:int` 驱动，非 4 个状态」。现改为订阅 `&"Slash"` + 用 `combo` 做段号分派（见 §2.1 注①）。§4 覆盖率表 CONCERN-AUD-7 → **RESOLVED**。其余信号映射、帧时序、总线、可访问性冗余角色**一律未动**。

---

## 1. 阅读约定

### 1.1 时间一律整数帧
物理 tick 60Hz，**1 tick ≡ GDD 1 帧**。本表「触发帧时机」列**只用整数帧**，`F0` = 该信号发出的那一帧。
唯一例外：**表现层包络**（滤镜/淡入淡出）用真实毫秒，因其不参与玩法判定（理由见 audio-direction §8.4⑥）。

### 1.2 信号来源的三层（对齐 architecture §5.1）
| 标记 | 含义 |
|---|---|
| **L2** | `EventBus` 全局信号——**必须是 §5.2 已存在的信号**，本表逐条给真名 |
| **L2+** | **需新增**的 EventBus 信号，见 §3（未获程基岩批准前不得实现） |
| **L1** | 节点局部信号 / `AnimationPlayer` Method Call Track 直调 `AudioDirector.play_event()`——**帧级精确音效走这里**，不污染全局总线 |
| **L3** | 直接读 Autoload 属性（取"当前值"，不产生事件） |

> **为什么 6 动词的挥砍/命中走 L1 而非 L2**：§5.2 没有逐动词信号，且把每一帧的挥刀细节塞进全局总线会污染 EventBus 并增加派发开销。L2 只负责"状态级"决策（进入哪个动作态），L1 负责"这一帧出声"。

### 1.3 优先级（对齐 audio-direction §5.4）
| 级 | 含义 |
|---|---|
| **P0** | **Tier-0 永不被裁 / 永不被抢占**。含可访问性命脉、生死反馈 |
| **P1** | 战斗核心反馈，池满时可抢占 P2 |
| **P2** | 环境/装饰，池紧张时优先让位 |

### 1.4 总线
`Master` / `Music` / `SFX`(母) / `SFX_Combat` / `SFX_World` / `SFX_Resonance` / `Ambience` / `UI` / `VO`（+ `Reverb` send）

### 1.5 「可访问性冗余角色」列
标 ★ 者为**某个视觉信息的唯一/主要听觉替代通道**，删除即造成可访问性缺口（accessibility-tier Standard 档 F1–F8）。

---

## 2. 事件表

### 2.1 六动词 · 玩家动作（S1）

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_VRB_SLASH_SWING_1..4` | `player_state_entered(&"Slash")` **+** `combo_advanced(count)` 定段（**见注①**） | L2 | `&"Slash"` 进入 `F0` 派发**首段**；第 2–4 段在 `combo_advanced(count)` 当帧 `F0` 派发（同一 `Slash` 状态内推进，**不产生新的状态进入事件**）；**破空起音帧仍由动画轨 L1 精确触发** | `SFX_Combat` | P1 | 3D | 是（被下一段连段打断） | — |
| `AUD_VRB_SLASH_CANCEL` | — | L1 | 取消窗口 `CANCEL_WINDOW=8f` 内成功取消的**当帧** | `SFX_Combat` | P1 | 3D | 是 | ★ 取消成功的听觉确认（P1 流动即正义的手感锚点） |
| `AUD_VRB_SLASH_HEAVY_CHARGE` | `player_state_entered(&"SlashHeavy")` | L2 | `F0` 起循环蓄力层，音高随蓄力上行；**退出边界**见注② | `SFX_Combat` | P1 | 3D | 是 | ★ 蓄力进度的听觉冗余（无需盯蓄力条） |
| `AUD_VRB_SLASH_HEAVY_RELEASE` | — | L1 | 释放帧 `F0` | `SFX_Combat` | P1 | 3D | 否 | — |
| `AUD_VRB_HIT_IMPACT` | `Hitbox.hit_landed` | L1 | 命中帧 `F0`，与 hit-stop `4–6f` 同帧起 | `SFX_Combat` | **P0** | 3D | 否 | ★ 命中确认（"崩"瞬态即 hit-stop 的听觉表达，见方向 §3） |
| `AUD_VRB_DASH` | `player_state_entered(&"Dash")` | L2 | `F0` 起音；`DASH_IFRAMES=10f` 期间叠"相位"尾音，`F10` 收束 | `SFX_Combat` | P1 | 3D | 是 | ★ **无敌帧起止的听觉边界**（尾音收束 = i-frame 结束） |
| `AUD_VRB_DASH_PERFECT` | — | L1 | 完美闪判定成立的当帧 `F0` | `SFX_Resonance` | **P0** | 2D 特写 | 否 | ★ 完美闪确认 |
| `AUD_VRB_GRAPPLE_FIRE` | `player_state_entered(&"Grapple")` | L2 | `F0` | `SFX_World` | P1 | 3D | 是 | — |
| `AUD_VRB_GRAPPLE_ATTACH` | `Grapple.attached` | L1 | 命中锚点当帧 | `SFX_World` | P1 | 3D | 否 | ★ 抓钩是否挂上的听觉确认 |
| `AUD_VRB_GRAPPLE_SWING_LOOP` | — | L1 | 摆荡期间循环；**开多普勒**（`DOPPLER_TRACKING_PHYSICS_STEP`） | `SFX_World` | P2 | 3D | 是 | — |
| `AUD_VRB_GRAPPLE_RELEASE` | `Grapple.released` | L1 | 脱手当帧 | `SFX_World` | P1 | 3D | 否 | — |
| `AUD_VRB_LEAP_JUMP` | `player_state_entered(&"Leap")` | L2 | `F0` | `SFX_World` | P1 | 3D | 是 | — |
| `AUD_VRB_LEAP_WIND_LOOP` | — | L1 | 滞空中循环，强度随下落速度；**开多普勒** | `SFX_World` | P2 | 3D | 是 | ★ 下落速度/高度的听觉冗余 |
| `AUD_VRB_LEAP_LAND` | — | L1 | 落地接触帧 `F0`；按落差分轻/中/重三档 | `SFX_World` | P1 | 3D | 否 | — |
| `AUD_VRB_PARRY_GUARD` | `player_state_entered(&"Parry")` | L2 | `F0` 起，`PARRY_WINDOW=6f` 窗口内持续一个极轻"张紧"层 | `SFX_Combat` | P1 | 3D | 是 | ★ **格挡窗口开启的听觉边界** |
| `AUD_VRB_PARRY_PERFECT` | `perfect_parry_landed(target)` | **L2** | `F0`（与慢动作 18f、敌人 Stagger 72f 同帧起） | `SFX_Resonance`（**绕开 SFX 低通**） | **P0** | 2D 特写 + 3D 定位层 | 否 | ★ 完美格挡确认（概念文档「完美格'叮'」） |
| `AUD_VRB_RESONATE_CHANNEL` | `player_state_entered(&"Resonate")` | L2 | `F0` 起引导层，谐波逐渐上行 | `SFX_Resonance` | P1 | 3D | 是 | — |
| `AUD_VRB_FINISHER` | `finisher_executed(damage)` | **L2** | `F0` 巨型谐波脉冲；低频体量 + 击退 whoosh | `SFX_Resonance` | **P0** | 3D（近场偏 2D 化） | 否 | ★ 终结技已释放 + 共鸣池已耗尽 40 的听觉确认 |
| `AUD_CMB_COMBO_TICK` | `combo_advanced(count)` | **L2** | `F0`；音高随 `count` 阶梯上行（4 段封顶）。**与 `AUD_VRB_SLASH_SWING_n` 同帧、不同层**——前者是计数反馈（2D），后者是挥砍体（3D），勿合并 | `SFX_Combat` | P2 | 2D | 是 | ★ 连段计数的听觉冗余（不看 HUD 也知道到第几段） |

#### 注① · 斩击 4 段连段的正确接线（**v1.1 修正，勿回退**）

**`state_name` 是闭集，取值必为 9 个之一**（`architecture.md` §5.2）：
`&"Idle"` `&"Slash"` `&"SlashHeavy"` `&"Dash"` `&"Grapple"` `&"Leap"` `&"Parry"` `&"Resonate"` `&"Hitstun"`

> **不存在 `&"Slash1"`..`&"Slash4"`。** 轻击 4 段连段（`combat.md` §②）**共用同一个 `Slash` 状态**，段号由 `combo:int`（`combat.md` §③，取值 `0–4`）驱动——`ADR-003` §1 节点树注释白纸黑字：「`Slash (Node, State)　# 4 段连段由 combo:int 驱动，非 4 个状态`」。
> 段号的 L2 来源 = **`combo_advanced(count)`**；`architecture.md` §5.2 另给出 L3 备选（读 `StateMachine.combo`），但 AudioDirector 直读非 Autoload 的玩家子节点会引入场景耦合，**本表选 L2 路线**。

```gdscript
# AudioDirector · 斩击接线（对齐 architecture.md §5.2 闭集 + ADR-003 §1）
const SLASH_SWING := {
    1: &"AUD_VRB_SLASH_SWING_1", 2: &"AUD_VRB_SLASH_SWING_2",
    3: &"AUD_VRB_SLASH_SWING_3", 4: &"AUD_VRB_SLASH_SWING_4",
}
var _combo: int = 0
var _last_swing_frame: int = -1

func _ready() -> void:
    EventBus.player_state_entered.connect(_on_player_state_entered)
    EventBus.combo_advanced.connect(_on_combo_advanced)

func _on_player_state_entered(state_name: StringName) -> void:
    match state_name:
        &"Slash":                       # ← 唯一的斩状态；首段在此起音
            _play_slash_swing(maxi(_combo, 1))
        &"SlashHeavy":                  # 重击蓄力：可中断的持续态（combat.md §②）
            play_event(&"AUD_VRB_SLASH_HEAVY_CHARGE")
        &"Dash":     play_event(&"AUD_VRB_DASH")
        &"Grapple":  play_event(&"AUD_VRB_GRAPPLE_FIRE")
        &"Leap":     play_event(&"AUD_VRB_LEAP_JUMP")
        &"Parry":    play_event(&"AUD_VRB_PARRY_GUARD")
        &"Resonate": play_event(&"AUD_VRB_RESONATE_CHANNEL")
    if state_name != &"Slash" and state_name != &"SlashHeavy":
        _combo = 0                      # 离开斩系 → 连段归零（combo 不持久，combat.md §③）
        _stop_charge_layers()           # 注② 蓄力层退出边界

func _on_combo_advanced(count: int) -> void:
    _combo = count
    _play_slash_swing(count)            # 第 2–4 段：同一 Slash 状态内推进
    play_event(&"AUD_CMB_COMBO_TICK", {"pitch_step": count})

func _play_slash_swing(count: int) -> void:
    var f := Engine.get_physics_frames()
    if f == _last_swing_frame:
        return                          # 同帧去重：见下「两条待程基岩确认」第 2 条
    _last_swing_frame = f
    play_event(SLASH_SWING[clampi(count, 1, 4)])
```

**两条待程基岩确认（不阻塞 Sprint 1 接线，但影响首段是否重复出声）**
1. **`Slash → Slash` 自转移是否重发 `player_state_entered`？** `ADR-003` §4 第 4–5 步为 `exit() → current_state = next → next.enter() → emit`，未说明 `next == current` 时的行为。若**不重发**（本表按此假设写），第 2–4 段完全由 `combo_advanced` 驱动，上述代码正确；若**重发**，`_last_swing_frame` 同帧去重仍能兜住，不会双响。
2. **同帧发射顺序**：`player_state_entered(&"Slash")` 与 `combo_advanced(1)` 在首段是否同帧、孰先孰后？两种顺序下 `maxi(_combo, 1)` + 同帧去重均收敛到「首段只响一次 `SWING_1`」，故**接线不依赖顺序**；此处仅请求确认，无需为音频调整发射顺序。

#### 注② · 重击蓄力层的退出边界

`SlashHeavy` 是**第 9 个状态**（`architecture.md` §5.2 AUD-7 裁决新增，理由正是音频侧需要循环蓄力层的进入/退出边界）。`AUD_VRB_SLASH_HEAVY_CHARGE` 为**循环层**，必须有确定的收束点，否则蓄力音会挂死：

- **正常释放** → `AUD_VRB_SLASH_HEAVY_RELEASE`（L1，动画轨释放帧）同帧停循环层；
- **被取消 / 被打断**（`CANCEL_WINDOW=8f` 内接其它动词、或进 `&"Hitstun"`）→ 离开 `&"SlashHeavy"` 的当帧 60ms 内淡出。

> ⚠️ **实现风险（已回报主理人）**：`ADR-003` §1 与 §4.4 的节点树**漏列 `SlashHeavy`**，`architecture.md` §5.2 已注明「以本表为准，ADR-003 §1 与 §4.4 待同步」。音频侧按 9 状态闭集接线；**若 ADR-003 同步时否决 `SlashHeavy`**，则 `AUD_VRB_SLASH_HEAVY_CHARGE` 需退回 L1 动画轨方案（失去可中断蓄力的进入/退出边界，★ 蓄力进度可访问性冗余降级）。

### 2.2 敌人（S4）—— 含**最关键的可访问性通道**

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_ENM_TELEGRAPH_WARN` | `enemy_telegraph_started(enemy, frames)` | **L2** | **`F0` 立即出声**（不得延迟）。`frames` = Normal `36–72f` / Hard `24–48f` | `SFX_Combat` | **P0**（Tier-0 永不裁、永不被抢占） | **3D**（必须可定位） | **否** | ★★★ **色盲玩家看不见 `THREAT` 视觉预警时的唯一冗余通道**。必须**可辨识**（不同敌人类型不同动机）且**可定位**（方位） |
| `AUD_ENM_TELEGRAPH_IMMINENT` | 同上（由 `frames` 推算） | L2 派生 | 攻击落下前 **`F-8`**（即 `frames-8` 帧处）追加一记高频"临界"点 | `SFX_Combat` | **P0** | 3D | 否 | ★★ 与 `PARRY_WINDOW=6f` 呼应，给出"该按格挡了"的听觉节拍点 |
| `AUD_ENM_TELEGRAPH_CLEAR` | `enemy_telegraph_cleared(enemy)` | **L2** | `F0`，预警层 60ms 内收束 | `SFX_Combat` | P1 | 3D | 是 | ★ 威胁解除的听觉确认（防"预警音卡死"造成误判） |
| `AUD_ENM_STAGGER` | `enemy_staggered(enemy, frames)` | **L2** | `F0`；`frames`（完美格挡时为 `72f`）内叠一层"失衡"环境层 | `SFX_Combat` | P1 | 3D | 是 | ★★ **破防窗口开启/剩余时长的听觉冗余**——玩家凭听感知道还能打多久 |
| `AUD_ENM_HIT` | `Hitbox.hit_landed`（敌方受击侧） | L1 | 受击帧 `F0`；按敌人材质分层（石/晶/腐化） | `SFX_Combat` | P1 | 3D | 否 | — |
| `AUD_ENM_DEATH` | `enemy_died(enemy)` | **L2** | `F0`；尾部叠共鸣 `+15` 的吸收音（与 `AUD_RES_*` 同帧但不同层） | `SFX_Combat` | P1 | 3D | 否 | ★ 击杀确认 + 共鸣进账的听觉冗余 |
| `AUD_ENM_SPAWN` | — | L1 | 敌人激活帧 | `SFX_World` | P2 | 3D | 是 | ★ 视野外敌人出现的预告 |
| `AUD_BOSS_PHASE_STINGER` | `boss_phase_changed(phase)` | **L2** | `F0`；音乐层解锁 + 一记 stinger | `Music` + `SFX_Combat` | **P0** | 2D | 否 | ★★ Boss 阶段推进的听觉冗余（Boss 血条颜色/分段看不清时） |

> **`AUD_ENM_TELEGRAPH_WARN` 的三条硬性实现约束**（缺一即可访问性失效）：
> 1. **永不被池抢占**：`pool_sfx_3d` 满时也必须有实例（预留 4 个 Tier-0 专用槽）。
> 2. **占用 2–5kHz 保留频段**（方向 §1），战斗峰值 20+ 源时靠**频谱分区**而非音量抢出可听性。
> 3. **慢动作期间不得被低通削掉**：§8 的下潜落在 `SFX` 母线；预警音走 `SFX_Combat` 但需**旁通低通**（实现上可将预警音专用子总线直挂 `Master`，见 §4 备注）。

### 2.3 玩家状态与生存（S1/S8）

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_PLR_DAMAGED` | `player_hp_changed(new, old)` where `new < old` | **L2** | `F0`；Hitstun 上限 `30f` 内不重复叠加 | `SFX_Combat` | **P0** | 2D | 否 | ★ 受击确认（`DAMAGE_WARN` 语义的听觉等价，**非 THREAT**） |
| `AUD_PLR_LOW_HP_LOOP` | `player_hp_changed` 跨入低血阈值 | **L2** | 跨阈当帧 `F0` 起循环心跳；离开阈值即淡出 | `UI` | **P0** | 2D | 是 | ★★ 低血视觉脉冲（`DAMAGE_WARN`）的听觉冗余 |
| `AUD_PLR_HEAL` | `player_hp_changed` where `new > old` | **L2** | `F0` | `UI` | P1 | 2D | 是 | ★ 回复确认 |
| `AUD_PLR_DEATH` | `player_hp_changed` where `new == 0` | **L2** | `F0`；全总线 duck，仅留死亡层 | `SFX_Resonance` | **P0** | 2D | 否 | ★ 死亡确认 |
| `AUD_PLR_RESPAWN` | `player_respawned(shrine_id)` | **L2** | `F0`；音乐切 Shrine 态 | `UI` + `Music` | P1 | 2D | 否 | ★ 重生确认 |

### 2.4 共鸣池听觉化（S3）—— **支柱 P4 的音频落地**

> 全部为 **2D 非定位**（共鸣池是玩家自身状态，不该有方位）。详细设计见 audio-direction §4。

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_RES_BED_L0` | `resonance_changed` + `_ready()` 的 **L3** `ResonancePool.current` | L2/L3 | 常驻循环；音量/明亮度对 `current` **平滑插值**（非逐帧跳变） | `SFX_Resonance` | P1 | 2D | 是 | ★★ 共鸣池连续量的听觉冗余 |
| `AUD_RES_BED_L1_READY` | `resonance_changed` 令 `current ≥ 30` | **L2** | 跨线帧 `F0` 起淡入（120ms） | `SFX_Resonance` | P1 | 2D | 是 | ★★★ **「可开门」三态之一**（HUD 共鸣条状态色的听觉替代） |
| `AUD_RES_BED_L2_FULL` | `resonance_changed` 令 `current ≥ 40` | **L2** | 跨线帧 `F0` 起淡入（120ms） | `SFX_Resonance` | P1 | 2D | 是 | ★★★ **「可终结技」三态之一** |
| `AUD_RES_CROSS_30_UP` | `resonance_changed`：`old<30 且 new≥30` | **L2** | `F0` 单发 ping（**滞回**：跌到 ≤27 才复位） | `SFX_Resonance` | **P0** | 2D | 否 | ★★★ 「开门解锁」离散确认 |
| `AUD_RES_CROSS_30_DOWN` | `resonance_changed`：`old≥30 且 new<30` | **L2** | `F0` 单发下沉音 | `SFX_Resonance` | P1 | 2D | 否 | ★★ 「开门能力失去」 |
| `AUD_RES_CROSS_40_UP` | `resonance_changed`：`old<40 且 new≥40` | **L2** | `F0` 单发、更亮的落定和弦（滞回：≤37 复位） | `SFX_Resonance` | **P0** | 2D | 否 | ★★★ 「终结技解锁」离散确认 |
| `AUD_RES_CROSS_40_DOWN` | `resonance_changed`：`old≥40 且 new<40` | **L2** | `F0` 单发青白顶层抽离音 | `SFX_Resonance` | P1 | 2D | 否 | ★★ 「终结技能力失去」 |
| `AUD_RES_GAIN_TICK` | `resonance_changed`（小额：命中 +1 / 脱战 +2/s） | **L2** | `F0`，**极轻**；**不跨线不响 ping**（防刷屏，见方向 §4.5） | `SFX_Resonance` | P2 | 2D | 是 | — |
| `AUD_RES_NODE_ABSORB` | `resonance_node_consumed(node_id)` | **L2** | `F0`；世界节点 `+10`（cd 5s），吸收 swell | `SFX_Resonance` | P1 | **3D**（节点在世界中） | 否 | ★ 节点已消耗（防重复交互） |
| `AUD_RES_OUTFLOW_GATE` | `gate_opened(gate_id)` | **L2** | `F0`；扣 `GATE_COST=30` 的**外流音**——L2 顶层被当场抽走 | `SFX_Resonance` | **P0** | 2D | 否 | ★★★ **P4 互斥张力的核心听觉表达**：「我把终结技的能量花在门上了」 |
| `AUD_RES_OUTFLOW_FINISHER` | `finisher_executed(damage)` | **L2** | `F0`；扣 `FINISHER_COST=40` 后床层回落 L0/L1 | `SFX_Resonance` | **P0** | 2D | 否 | ★★★ **P4 互斥张力**：「能量倾泻，门暂时开不了」 |
| `AUD_RES_REJECT` | `resonance_spend_rejected(cost, reason)` | **L2** | `F0`；发闷、失谐的"共鸣不足"音 | `UI` | **P0** | 2D | 否 | ★★★ HUD「灰显 + 共鸣不足提示」的听觉冗余 |

### 2.5 世界 / 神龛（S5 / S8）

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_WLD_ISLAND_ENTER` | `island_entered(island_id)` | **L2** | `F0`；环境床交叉淡变 + 音乐切 Explore 态 | `Ambience` + `Music` | P1 | 2D | 是 | ★ 区域切换确认 |
| `AUD_WLD_AMBIENCE_LOOP` | — | L1 | 常驻，按 `Area3D` 混响分区切换 | `Ambience` | P2 | 3D/2D 混合 | 是 | — |
| `AUD_GATE_OPEN` | `gate_opened(gate_id)` | **L2** | `F0`；解锁和弦 + 机械/结晶开启层（与 `AUD_RES_OUTFLOW_GATE` **同帧、不同层**） | `SFX_World` | P1 | **3D** | 否 | ★ 门已开启（远处开门也能听见） |
| `AUD_SHR_ACTIVATE` | `shrine_activated(shrine_id)` | **L2** | `F0`；音乐切 Shrine 安全区态 | `SFX_World` + `Music` | P1 | 3D | 否 | ★ 存档点已激活 |
| `AUD_WLD_INTERACT_HINT` | — | L1 | 进入可交互距离 | `SFX_World` | P2 | 3D | 是 | ★ `FRIENDLY_GOLD` 可交互描边的听觉冗余 |

### 2.6 残响叙事（S7）

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_ECH_TRIGGER` | `echo_triggered(echo_id)` | **L2** | `F0`；音乐降至 L0 极简垫，VO 起 | `VO` + `Music` | P1 | 2D | 否（战斗中不打断玩法） | ★ 残响开始 |
| `AUD_ECH_VO_LINE` | — | L1 | VO 逐句；侧链 duck `Music`/`Ambience` | `VO` | P1 | 2D | 是（新残响打断旧残响） | ★ 需配 VO 字幕（accessibility F 项） |
| `AUD_ECH_END` | `echo_finished(echo_id)` | **L2+ 需新增** | `F0`；音乐恢复原状态 | `Music` | P1 | 2D | — | — |
| `AUD_ECH_COLLECT` | `echo_collected(echo_id, total)` | **L2** | `F0`；收集确认音，音高随 `total` 上行 | `UI` | P1 | 2D | 否 | ★ 收集进度的听觉冗余 |

### 2.7 系统 / 音乐 / 时间膨胀

| 事件 ID | 触发信号 | 层 | 触发帧时机 | 总线 | 优先级 | 3D/2D | 可打断 | 可访问性冗余角色 |
|---|---|---|---|---|---|---|---|---|
| `AUD_SYS_SAVE_OK` | `save_completed(true)` | **L2** | `F0` | `UI` | P2 | 2D | 是 | ★ 存档成功 |
| `AUD_SYS_SAVE_FAIL` | `save_completed(false)` | **L2** | `F0` | `UI` | **P0** | 2D | 否 | ★★ 存档失败（必须有听觉+字幕，否则玩家无感知） |
| `AUD_SYS_SETTINGS_APPLY` | `settings_changed(key)` | **L2** | `F0`；重读 6 条总线音量 / mono / 字幕开关 | — | — | — | — | — |
| `AUD_SYS_PAUSE` | `game_paused()` | **L2+ 需新增** | `F0`；`SFX`/`Ambience` 80ms 淡出，`Music` duck −12dB，`UI` 保持 | 全局 | **P0** | — | — | ★ 见方向 §8.5（`time_scale=0` **不会**自动停音频） |
| `AUD_SYS_RESUME` | `game_resumed()` | **L2+ 需新增** | `F0`；反向淡入 120ms | 全局 | **P0** | — | — | — |
| `AUD_MUS_STATE_COMBAT` | `combat_state_changed(in_combat)` | **L2+ 需新增** | `F0`；`AudioStreamInteractive` 切 Combat/Explore 片段 | `Music` | P1 | 2D | — | ★ 进战/脱战的听觉冗余 |
| `AUD_TIM_DIP` | `time_dilation_started(scale, duration_frames)` | **L2+ 需新增** | `F0`；`SFX` 低通 20500→1800Hz（40ms 真实时间）、`Ambience`→1200Hz、`Music` duck −3dB | `SFX` + `Ambience` + `Music` | **P0** | — | — | — |
| `AUD_TIM_RESTORE` | `time_dilation_ended()` | **L2+ 需新增** | `F0`；回升 20500Hz（120ms 真实时间） | 同上 | **P0** | — | — | — |

---

## 3. 需新增 EventBus 信号（交程基岩评估）

> 共 **6 条**。全部**过去式命名**、全部只**陈述已发生的事实**（不用于请求动作），符合 architecture §5.1 红线与 §5.2 命名约定。
> **在获批前，AudioDirector 不实现对应订阅**；表 §2 中标 `L2+` 的事件全部依赖本节。

```gdscript
# --- 时间膨胀（G7 收口所需）---
signal time_dilation_started(scale: float, duration_frames: int)
signal time_dilation_ended()

# --- 系统流程 ---
signal game_paused()
signal game_resumed()

# --- 战斗状态（音乐状态机所需）---
signal combat_state_changed(in_combat: bool)

# --- S7 残响 ---
signal echo_finished(echo_id: StringName)
```

| 信号 | 参数 | 建议发出方 | 为什么**不能**从现有 21 条信号推导 |
|---|---|---|---|
| `time_dilation_started` | `scale: float`（时间缩放比）、`duration_frames: int`（整数帧，完美格挡为 `18`） | 设置 `Engine.time_scale` 的战斗 FSM（完美格挡分支），**同帧发出** | `perfect_parry_landed` 只说"格挡成功"，不携带 `scale` 与时长；且将来终结技若加慢动作会是**第二个来源**，音频侧需要统一挂点，不能绑死在格挡信号上 |
| `time_dilation_ended` | — | 同上，恢复 `time_scale = 1.0` 的同帧 | 音频侧无法自行判定慢动作何时结束：`duration_frames` 是名义值，若中途被打断（敌人死亡/玩家受击）会提前结束，靠倒计时会**滤镜卡在下潜态** |
| `game_paused` | — | 暂停菜单控制器（设置 `Engine.time_scale = 0` 的同帧） | **关键**：Godot 中 `Engine.time_scale` **不影响音频**，暂停时音效与环境床会继续播放。现有 21 条信号无任何暂停事件，音频无从得知 |
| `game_resumed` | — | 同上 | 同上 |
| `combat_state_changed` | `in_combat: bool` | 战斗状态仲裁者（同一处已在为共鸣"脱战 +2/秒"计时） | **进战**可勉强用 `enemy_telegraph_started` 近似，**脱战无任何信号**。音乐 5 态机（方向 §2）无法从 Explore↔Combat 正确回切；且"脱战"这一事实已被共鸣系统计算，只是没广播 |
| `echo_finished` | `echo_id: StringName` | `EchoDirector`（S7） | `echo_triggered` 只有开始没有结束。音乐在残响期间降至 L0 极简垫，**不知何时恢复**就会一直压着 |

> **命名复核**：`*_started` / `*_ended` / `*_paused` / `*_resumed` / `*_changed` / `*_finished` 均为过去式或状态完成式，与既有 `resonance_changed` / `enemy_telegraph_started` / `save_completed` 风格一致。
> **红线自检**：6 条均**不携带"请谁去做什么"的语义**——音频只是众多监听者之一，VFX / 相机 / HUD 同样受益（尤其 `game_paused` 与 `combat_state_changed`），满足"≥2 系统消费"的新增门槛。

---

## 4. 覆盖率对照：§5.2 现有 21 条信号

| # | 信号 | 音频是否消费 | 用途 |
|---|---|---|---|
| 1 | `resonance_changed` | ✅ | 共鸣床三层 + 4 个跨线 ping（§2.4） |
| 2 | `resonance_spend_rejected` | ✅ | `AUD_RES_REJECT`（P0 可访问性） |
| 3 | `resonance_node_consumed` | ✅ | `AUD_RES_NODE_ABSORB` |
| 4 | `player_hp_changed` | ✅ | 受击 / 低血 / 回复 / 死亡（4 个事件按 new-old 关系分派） |
| 5 | `player_state_entered` | ✅ | **6 动词动作音的唯一 L2 挂点**。状态名 = `architecture.md` §5.2 的 **9 个闭集值**，分派表已写死。**CONCERN-AUD-7 → RESOLVED**（v1.1）：**改用 `&"Slash"` + `combo` 分派**——原 `Slash1..4` 四状态假设不成立（`ADR-003` §1「4 段连段由 `combo:int` 驱动，非 4 个状态」），详见 §2.1 注① |
| 6 | `combo_advanced` | ✅ | `AUD_CMB_COMBO_TICK` **+ 斩击 4 段段号分派**（`AUD_VRB_SLASH_SWING_1..4` 的第 2–4 段派发源，见 §2.1 注①） |
| 7 | `perfect_parry_landed` | ✅ | `AUD_VRB_PARRY_PERFECT` 特写层 |
| 8 | `finisher_executed` | ✅ | `AUD_VRB_FINISHER` + `AUD_RES_OUTFLOW_FINISHER` |
| 9 | `enemy_telegraph_started` | ✅ | **★★★ 可访问性命脉**（§2.2） |
| 10 | `enemy_telegraph_cleared` | ✅ | 预警收束 |
| 11 | `enemy_staggered` | ✅ | 破防窗口听觉化 |
| 12 | `enemy_died` | ✅ | 死亡 + 共鸣 +15 吸收 |
| 13 | `boss_phase_changed` | ✅ | 音乐 Boss 层解锁 + stinger |
| 14 | `gate_opened` | ✅ | `AUD_GATE_OPEN` + `AUD_RES_OUTFLOW_GATE`（P4 互斥） |
| 15 | `shrine_activated` | ✅ | 音乐 Shrine 态 |
| 16 | `player_respawned` | ✅ | 重生音 + 音乐复位 |
| 17 | `island_entered` | ✅ | 环境床交叉 + 音乐 Explore |
| 18 | `echo_triggered` | ✅ | 残响 VO + 音乐让位 |
| 19 | `echo_collected` | ✅ | 收集确认 |
| 20 | `save_completed` | ✅ | 成功/失败双分支 |
| 21 | `settings_changed` | ✅ | 重读音量/mono/字幕 |

**结论：21/21 全部被音频消费，无一冗余；另需新增 6 条（§3）。**

---

## 5. 实现备注

1. **Tier-0 预留槽**：`pool_sfx_3d`(48) 中**预留 4 槽**专供 `AUD_ENM_TELEGRAPH_WARN`，池满时也不得挪用（方向 §7.2）。
2. **预警音旁通低通**：`AUD_ENM_TELEGRAPH_WARN` 走 `SFX_Combat`，但慢动作下潜挂在 `SFX` 母线上会把它一起削掉。**实现建议**：把预警音单独路由到一条 `SFX_Alert` 子总线并**直挂 `Master`**（不经 `SFX`），或在下潜期间对预警音源单独提升 cutoff。请程基岩按实现便利二选一，**但"慢动作中预警音必须保持可辨识"是不可让步的验收项**。
3. **同帧多事件的层叠**：`gate_opened` 会同帧触发 `AUD_GATE_OPEN`(3D 世界音) 与 `AUD_RES_OUTFLOW_GATE`(2D 共鸣音)——**这是刻意的双层设计**，不是重复播放，勿在实现时合并。
4. **滞回常数**：`≥30` 触发 / `≤27` 复位；`≥40` 触发 / `≤37` 复位。建议随 `GATE_COST`/`FINISHER_COST` 一并进 `GameConstants`。
5. **字幕挂钩**：所有标 ★★ 及以上的事件应同时产出一条音效字幕（CONCERN-AUD-4 待批准后落地）。
6. **斩击段号不得反推**：`AUD_VRB_SLASH_SWING_1..4` 的段号**只能**来自 `combo_advanced(count)`，**禁止**在 AudioDirector 内自建计数器（如"每进一次 Slash 就 +1"）。理由：取消窗内接其它动词、`Hitstun` 打断、终结技接续都会改写 `combo`，自建计数必然与 FSM 权威值漂移，且漂移在 4 段封顶处不可见（听感"卡在第 4 段"）。`combo` 的唯一权威 = FSM（`combat.md` §③ `combo(0–4)`）。

---

**关联文档**：`design/audio/audio-direction.md`（听觉方向与 G7 收口）
**待办**：§3 六条新增信号获批 → 回填 ENG-S0-05 第 6 项 → Sprint 1 接线
