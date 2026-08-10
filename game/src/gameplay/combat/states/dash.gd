class_name DashState
extends CombatState
## Dash · 闪（架构 §4.4 / ADR-003 §3）。
##
## 进入即置 `iframes_left = GameConstants.DASH_IFRAMES(10)`，每 tick -1 —— 整数帧倒计时，
## 不用秒、不随刷新率漂移，这让 AC-S1-05「iframes 期间 0 伤害」是确定性断言而非概率观测。
## 伤害免疫的**消费**在 ENG-S1-03；本故事只保证计数器推进确定，避免那一步再引入第二套计时基准。

## 见 SlashState.CANCEL_OPEN_FRAME 的同一理由：第 0 帧不开窗，第 1–8 帧为取消窗。
const CANCEL_OPEN_FRAME: int = 1

## 闪总帧数（v1 占位）。刻意 ≥ DASH_IFRAMES(10)，否则无敌帧会外溢到动作之外，
## 变成「闪结束后还无敌」这种无法从画面读出的状态（美学 Challenge 要求可读）。
const TOTAL_FRAMES: int = 18

## 剩余无敌帧。>0 即无敌（ADR-003 §3）。
var iframes_left: int = 0


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = CANCEL_OPEN_FRAME
	duration_frames = TOTAL_FRAMES
	neutral = false
	iframes_left = GameConstants.DASH_IFRAMES


func _exit() -> void:
	iframes_left = 0


## 是否处于闪的无敌帧内（ENG-S1-03 / AC-S1-05 的唯一查询口）。
func is_invulnerable() -> bool:
	return iframes_left > 0


func physics_tick(delta: float) -> void:
	# 先扣无敌帧再交给基类：基类可能在本帧把状态转走，转走后这个计数器就不该再动。
	if iframes_left > 0:
		iframes_left -= 1
	super.physics_tick(delta)
