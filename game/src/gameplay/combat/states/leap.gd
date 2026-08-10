class_name LeapState
extends CombatState
## Leap · 跃（架构 §4.4 / S2 移动动词，与 S1 共享同一套取消窗，systems-index §3「→ S2」）。
##
## ⚠ S2 不另立状态机：grounded / airborne / grappling 是**标志位**，不是状态
## （EventBus.player_state_entered 闭集约定 3）。本态只描述「跃这个动作」本身。
##
## 取消窗与斩一致，AC-S2-03「跃→闪→斩 ≤8 帧」才有意义：三个动词若各用各的窗宽，
## 玩家学到的节奏无法迁移，P1「流动即正义」就退化成逐招背板。

const CANCEL_OPEN_FRAME: int = 1

## 跃总帧数（v1 占位，[GAP-VERB-1]）。
const TOTAL_FRAMES: int = 24


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = CANCEL_OPEN_FRAME
	duration_frames = TOTAL_FRAMES
	neutral = false
