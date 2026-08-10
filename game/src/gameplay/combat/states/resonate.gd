class_name ResonateState
extends CombatState
## Resonate · 共鸣终结技（架构 §4.4 / ADR-002 / ADR-003 §4 第 3 步）。
##
## 三条硬纪律：
##   1. **不可取消**（`cancel_open_at_frame = -1`）：终结技一旦起手必须打完，靠
##      `duration_frames` 自然收束回 Idle，而不是靠取消窗放行。取消窗是「接续」语言，
##      不是「逃课」语言——若终结技可被取消，FINISHER_COST=40 的代价就白付了。
##   2. **不进慢动作**（AUD-1 / `GameConstants.FINISHER_USES_SLOWMO = false`）：全作时间膨胀
##      语义唯一归属完美格挡。本文件刻意**不出现** `Engine.time_scale`，也不发 time_dilation_*。
##   3. **扣池经 ResonancePool.try_spend() 唯一入口**（ADR-002 决策 1），本类只调用、不改池。
##
## 进入门槛在 `can_enter_state()`（ADR-003 §4 第 3 步明文点名本态）：池不足则连转移都不发生，
## 于是「起手了却扣费失败」这种半途状态在结构上不可能出现。
## HUD 灰显与 resonance_spend_rejected 的表现侧属 ENG-S1-05，本故事不涉。

## 终结技总帧数（v1 占位，[GAP-VERB-1]）。
const TOTAL_FRAMES: int = 48

## 本次进入是否成功扣池。理论上恒为 true（can_enter_state 已挡），留作调试可观测。
var spend_succeeded: bool = false


## ADR-003 §4 第 3 步：目标态自检 —— 池 < FINISHER_COST 时终结技态不可进入（AC-S1-04）。
func can_enter_state() -> bool:
	return ResonancePool.can_afford(GameConstants.FINISHER_COST)


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = -1     # 不可取消
	duration_frames = TOTAL_FRAMES
	neutral = false
	spend_succeeded = ResonancePool.try_spend(
		GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER
	)


func _exit() -> void:
	spend_succeeded = false
