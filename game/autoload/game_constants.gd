## Autoload #1 · 常量单一真相源（Single Source of Truth）。
##
## 全部数值来自 design/gdd/systems-index.md §2。**禁止在任何其他文件硬编码这些值。**
## 改动流程：先改 GDD → 再改此处 → CI 的 test_constants_match_gdd.gd 才会绿。
## 该测试是**架构承重墙**：它把「文档一致性」变成可执行门禁。
##
## 本文件零逻辑、零状态、零 _process（architecture.md §4.3「禁止：任何逻辑」）。
## 语义色**不在此定义**，一律引用 ColorTokens 的 Token 名（见 §5）。
extends Node

## 常量权威来源。测试断言此字符串，防止有人另立真相源。
const SOURCE_OF_TRUTH: String = "design/gdd/systems-index.md#2"

## 语义色权威来源（与常量源分离，architecture.md §9）。
const COLOR_SOURCE_OF_TRUTH: String = "design/color-tokens.md#1"

# =========================================================================
# 1. 时间基准（systems-index §2「帧基准」/ architecture.md §3）
#    1 物理 tick ≡ GDD 的 1 帧。**一切时序用整数帧，不写秒。**
# =========================================================================

## 物理 tick 率，固定 60Hz 不可玩家修改（architecture.md §3.2 第 1 条）。
const TICKS_PER_SECOND: int = 60

# =========================================================================
# 2. 战斗窗口（systems-index §2）—— 全部整数帧，确定性可断言
# =========================================================================

## 斩/闪/荡/跃/格 之间可取消接续的窗口，8 帧 ≈133ms（支柱 P1「流动即正义」）。
const CANCEL_WINDOW: int = 8

## 格挡命中判定窗口，6 帧 ≈100ms。
const PARRY_WINDOW: int = 6

## 闪的无敌帧，10 帧 ≈167ms。
const DASH_IFRAMES: int = 10
## 玩家最大生命（ENG-S1-03 / AC-S1-05）。v1 占位，后续随平衡调参。
const PLAYER_MAX_HP: int = 100

## S8 技能树可把 CANCEL_WINDOW 最多减到 5 帧（architecture.md §4.2）。
## 注意方向：技能树是**减**窗口（更难但更快），不是放宽。
const CANCEL_WINDOW_MIN: int = 5

## 「辅助模式」可放宽到 10 帧。**v1 纳入但默认 OFF**（sprint-01-plan §6 决策表）。
## 默认关闭由设置项承载，不改本常量。
const CANCEL_WINDOW_ASSIST: int = 10

# =========================================================================
# 3. 时间膨胀 / hit-stop（systems-index §2「时间膨胀（慢动作）常量组」v0.3）
# =========================================================================

## 完美格挡后时间膨胀的持续时长 = 18 帧。
##
## ⚠ **计时基准 = 墙钟真实时间（300ms），不是游戏 tick。**
## 实现必须用 `get_tree().create_timer(0.3, true, false, true)`（第 4 参
## ignore_time_scale = true）或 Time.get_ticks_msec() 计时；配套 Tween 须
## set_ignore_time_scale(true)。
## 若误按游戏 tick 计，真实时长会变成 18 / 0.3 = 1.0s，吞掉 72 帧破防窗口的
## 大半，并使取消窗口在真实观感上被放宽约 3.3×，违反 ux-spec §5.1。
const PARRY_SLOWMO_FRAMES: int = 18

## 同上，以毫秒表达的**墙钟**时长。与 PARRY_SLOWMO_FRAMES 是同一事实的两种表达，
## 提供它是为了让实现方不必在调用处做 18/60 换算（换算处最容易写错基准）。
const PARRY_SLOWMO_MSEC: int = 300

## Engine.time_scale 目标值（无量纲，1.0 = 常速）。
##
## ⚠ **数值巧合提示**（systems-index §2 明文警告）：`300 ms` 与 `SCALE = 0.3`
## 的两个「0.3」**毫无关联** —— 前者是时长、后者是无量纲缩放比。
## **代码中禁止复用同一个 0.3 字面量**，两者必须是两个独立命名常量。
const PARRY_SLOWMO_SCALE: float = 0.3

## hit-stop 下限，60ms ≈ 4 帧。用 FSM frozen_frames 实现，**不动全局 time_scale**
## （architecture.md §5.4），故不属于时间膨胀，与上组常量互不相乘。
const HITSTOP_FRAMES_MIN: int = 4

## hit-stop 上限，90ms ≈ 6 帧。
const HITSTOP_FRAMES_MAX: int = 6

## ⚠ **FINISHER_SLOWMO 不存在 —— 已定夺 = 否，非遗漏**（systems-index §2 / AUD-1）。
## 共鸣终结技全程 Engine.time_scale = 1.0；全作时间膨胀语义**唯一归属完美格挡**。
## 请勿新增 FINISHER_SLOWMO_FRAMES / FINISHER_SLOWMO_SCALE。
## test_constants_match_gdd.gd 会**断言这两个名字不存在**，把该设计决策焊死在 CI 里。
const FINISHER_USES_SLOWMO: bool = false

# =========================================================================
# 4. 共鸣池 RESONANCE_POOL（systems-index §2 / GDD S3 resonance.md）
#    ★ 支柱 P4「共鸣统一」的全部数值，AC-S3-01..04 直接断言本组
# =========================================================================

## 池上限，严格 100，溢出部分丢弃不保留（AC-S3-01）。
const RESONANCE_MAX: int = 100

## 新档初始值 50。
const RESONANCE_INITIAL: int = 50

## 解谜闸门消耗（S5→S3）。
const GATE_COST: int = 30

## 战斗终结技消耗（S1→S3）。**GATE_COST 与 FINISHER_COST 共享同一池 → 天然互斥。**
const FINISHER_COST: int = 40

## 近战命中 +1/次。
const GAIN_HIT: int = 1

## 完美格挡 +5。
const GAIN_PERFECT_PARRY: int = 5

## 击杀 +15。
const GAIN_KILL: int = 15

## 世界共鸣节点 +10/次（S5/S7）。
const GAIN_NODE: int = 10

## 脱战被动 +2/秒。
const GAIN_OUT_OF_COMBAT_PER_SEC: int = 2

# --- 节点与脱战的帧化计时（GDD 以秒表述，工程一律转整数帧）---

## 共鸣节点冷却 5s = 300 tick（AC-S3-04）。防刷池。
const NODE_COOLDOWN_FRAMES: int = 300

## 脱战判定阈值 3s = 180 tick：连续 180 tick 无敌人接触视为脱战，开始被动回充。
const OUT_OF_COMBAT_FRAMES: int = 180

# --- Should 级技能树调节（GDD S3 §⑤「调节（Should 技能树）」）---

## 技能树升级后节点增益 +15（v1 Should，非默认路径）。
const GAIN_NODE_UPGRADED: int = 15

## 技能树升级后脱战被动 +3/秒（v1 Should）。
const GAIN_OUT_OF_COMBAT_PER_SEC_UPGRADED: int = 3

# =========================================================================
# 5. 语义色 —— **此处不存取值**，只登记 Token 名
#    取值权威 = ColorTokens（src/core/color_tokens.gd ← design/color-tokens.md）
#    游戏代码写 `ColorTokens.THREAT`，禁止写 hex，禁止在本文件复制颜色。
# =========================================================================

## HUD 共鸣三态所用的 Token 名（S6 §⑤：≥FINISHER_COST / ≥GATE_COST / 其余）。
## 存 Token 名而非 Color，是为了让「阈值逻辑」与「色彩取值」保持两个独立真相源，
## 任何一侧改动都不会静默污染另一侧。
const TOKEN_RESONANCE_FULL: StringName = &"RESONANCE_GLOW"
const TOKEN_RESONANCE_GATE_READY: StringName = &"GATE_READY"
const TOKEN_RESONANCE_INACTIVE: StringName = &"INACTIVE"

## 敌人 telegraph / 危险标记（铁律：仅敌/混沌）。
const TOKEN_THREAT: StringName = &"THREAT"

## 受击 / 低血闪 / 危险区（非敌语义，守 THREAT 铁律）。
const TOKEN_DAMAGE_WARN: StringName = &"DAMAGE_WARN"

## 可交互 / 线索 / 暖光。本名 FRIENDLY_GOLD（FRIENDLY_AMBER 为合法代码侧别名）。
const TOKEN_FRIENDLY_GOLD: StringName = &"FRIENDLY_GOLD"

## UI 底。本名 UI_BG（UI_BASE 为合法代码侧别名）。
const TOKEN_UI_BG: StringName = &"UI_BG"

## 玩家 / 友方主色。
const TOKEN_PLAYER_ALLY_MAIN: StringName = &"PLAYER_ALLY_MAIN"

# =========================================================================
# 6. 输入（architecture.md §7.5 / §8 / ux-spec §1）
# =========================================================================

## 输入缓冲上限 6 帧：按下动词若当前不可取消，缓存意图 ≤6 帧，一进取消窗立即释放。
const INPUT_BUFFER_FRAMES: int = 6

## 摇杆死区，防漂移把设备图标抢回手柄（architecture.md §8.3）。
const STICK_DEADZONE: float = 0.2

# =========================================================================
# 7. 战斗/敌人派生帧常量
#    ⚠ 来源**不是** systems-index §2，而是 architecture.md §5.3 流 B / §4.5。
#    故 test_constants_match_gdd.gd 的硬断言**不覆盖本组**（避免误报为 GDD 漂移）；
#    另由 test_derived_constants.gd 断言并注明各自出处。
# =========================================================================

## 玩家 hitstun 上限 30 帧（0.5s），防卡死（architecture.md §5.3 流 B）。
const HITSTUN_MAX_FRAMES: int = 30

## 完美格后敌人破防硬直 72 帧（1.2s），满足 AC-S1-03 / AC-S4-02「≥1s」。
const ENEMY_STAGGER_FRAMES: int = 72

## 敌人 telegraph 时长 Normal 0.6–1.2s → 36–72 帧（architecture.md §4.5）。
## 实际取值数据驱动，存 EnemyDefinition.tres；此处仅为校验区间。
const TELEGRAPH_FRAMES_NORMAL_MIN: int = 36
const TELEGRAPH_FRAMES_NORMAL_MAX: int = 72

## Hard 0.4–0.8s → 24–48 帧。[GAP] G3：24 帧下限是否跌破心流带，Phase 4 A/B 调参。
const TELEGRAPH_FRAMES_HARD_MIN: int = 24
const TELEGRAPH_FRAMES_HARD_MAX: int = 48

# =========================================================================
# 8. 共鸣潮汐（G6 已收口：90–120s，参数化，林绘澄可在区间内微调）
#    architecture.md §6.2 / sprint-01-plan §6 决策表 G6
# =========================================================================

## 潮汐周期下限 90s = 5400 帧。
const RESONANCE_TIDE_PERIOD_FRAMES_MIN: int = 5400

## 潮汐周期上限 120s = 7200 帧。
const RESONANCE_TIDE_PERIOD_FRAMES_MAX: int = 7200

## [GAP-TIDE-1] 区间中点 105s = 6300 帧，作为**工程默认值**先行落地。
## G6 只裁决了区间（90–120s）未指定单值；林绘澄按氛围微调后单行替换此处。
const RESONANCE_TIDE_PERIOD_FRAMES_DEFAULT: int = 6300

# =========================================================================
# 9. 性能预算（architecture.md §7.3）—— DebugOverlay 红字告警阈值消费本组
# =========================================================================

const BUDGET_FPS_TARGET: int = 60
const BUDGET_FRAME_MS: float = 16.67
const BUDGET_CPU_MS: float = 9.0
const BUDGET_GPU_MS: float = 15.0
const BUDGET_DRAW_CALLS: int = 1500
const BUDGET_TRIANGLES: int = 2000000
const BUDGET_PARTICLES: int = 30000
const BUDGET_AREA_LIGHTS: int = 8
const BUDGET_SKINNED_CHARACTERS: int = 12

## 音频预算（audio-direction.md §7.5，建议补入 architecture §7.3）。
const BUDGET_AUDIO_VOICES: int = 64

# =========================================================================
# 10. 输入延迟红线（S6 / architecture.md §7.5 / SPIKE-1 判定线）
# =========================================================================

## 键鼠端到端延迟红线 50ms。
const LATENCY_BUDGET_KBM_MS: int = 50

## 手柄端到端延迟红线 80ms。
const LATENCY_BUDGET_GAMEPAD_MS: int = 80


## 帧 → 毫秒（仅供工具/日志展示，**禁止**用于玩法判定）。
## 玩法一律用整数帧比较，不做浮点换算（architecture.md §3.2 第 6 条）。
static func frames_to_msec(frames: int) -> float:
	return float(frames) * 1000.0 / float(TICKS_PER_SECOND)


## 秒 → 帧（仅供从 GDD 秒值导入数据资源时使用，运行时热路径禁用）。
static func seconds_to_frames(seconds: float) -> int:
	return int(round(seconds * float(TICKS_PER_SECOND)))
