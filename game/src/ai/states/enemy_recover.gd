class_name EnemyRecoverState
extends EnemyState
## 敌人收招（ENG-S4-01 骨架）。持续 recover_frames 后回落 Idle，等待下一轮 telegraph。
var recover_frames: int = 16


func _enter() -> void:
	super._enter()
	duration_frames = recover_frames


func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if is_finished():
		(machine as StateMachine).try_transition(&"Idle")
