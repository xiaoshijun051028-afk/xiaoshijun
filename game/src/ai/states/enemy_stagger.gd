class_name EnemyStaggerState
extends EnemyState
## 破防硬直（ENG-S4-01 骨架；由完美格触发，ENG-S4-04 联动）。
## 持续 ENEMY_STAGGER_FRAMES(72≈1.2s) 后自动回落 Idle。期间仅 Idle/Dead 合法（邻接表保证禁新 telegraph）。
func _enter() -> void:
	super._enter()
	duration_frames = GameConstants.ENEMY_STAGGER_FRAMES


func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if is_finished():
		(machine as StateMachine).try_transition(&"Idle")
