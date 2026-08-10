class_name ParryState
extends CombatState
## Parry · 格（架构 §4.4 / ADR-003 §3）。
##
## ⚠ 两个窗口是**两件事**，各自独立计数，绝不复用同一个计数器：
##   - `PARRY_WINDOW(6)` → armed 判定窗：这一刻挡不挡得下（ENG-S1-04 / AC-S1-03 消费）。
##   - `CANCEL_WINDOW(8)` → 接续窗：挡完能不能立刻接斩反击（本故事）。
## 若混为一谈，日后调「格挡好不好触发」会连带改掉「格后反击的顺不顺手」，
## 两个手感维度被焊死，调参就只能二选一。

## 见 SlashState.CANCEL_OPEN_FRAME 的同一理由。第 1–8 帧可接斩反击（epic 出口第 4 条）。
const CANCEL_OPEN_FRAME: int = 1

## 格总帧数（v1 占位，[GAP-VERB-1]）。> PARRY_WINDOW，即「挡空了要吃收招」。
const TOTAL_FRAMES: int = 20

## 剩余判定帧。>0 即处于可挡下攻击的 armed 窗内（ENG-S1-04 的唯一查询口）。
var parry_armed_left: int = 0


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = CANCEL_OPEN_FRAME
	duration_frames = TOTAL_FRAMES
	neutral = false
	parry_armed_left = GameConstants.PARRY_WINDOW


func _exit() -> void:
	parry_armed_left = 0


## 是否处于格挡判定窗内（与取消窗无关，见类注释）。
func is_armed() -> bool:
	return parry_armed_left > 0


func physics_tick(delta: float) -> void:
	if parry_armed_left > 0:
		parry_armed_left -= 1
	super.physics_tick(delta)
