class_name EnemyTelegraphState
extends EnemyState
## 敌人预警（ENG-S4-01 骨架）。持续 telegraph_frames 后自动转 Attack。
## THREAT 色脉冲 + 音效属 ENG-S4-02（telegraph 100% 覆盖预警语言）。
var telegraph_frames: int = 48


func _enter() -> void:
	super._enter()
	duration_frames = telegraph_frames


func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if is_finished():
		(machine as StateMachine).try_transition(&"Attack")
