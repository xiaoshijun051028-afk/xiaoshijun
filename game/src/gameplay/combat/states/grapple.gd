class_name GrappleState
extends CombatState
## Grapple · 荡（架构 §4.4 / S2 移动动词，共享同一套取消窗）。
##
## 位移与锚点判定属 S2（ENG-S2-*），本故事只落地「它是一个受同一取消窗约束的动词态」，
## 这样 S2 接手时无需再决定一次取消语义——6 动词共用一套取消/预警语言（概念文档）。

const CANCEL_OPEN_FRAME: int = 1

## 荡总帧数（v1 占位，[GAP-VERB-1]）。比斩/跃长，反映「荡是一段持续位移」。
const TOTAL_FRAMES: int = 30


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = CANCEL_OPEN_FRAME
	duration_frames = TOTAL_FRAMES
	neutral = false
