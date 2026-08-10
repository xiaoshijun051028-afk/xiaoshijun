class_name EnemyAttackState
extends EnemyState
## 敌人攻击（ENG-S4-01 骨架）。持续 attack_frames 后转 Recover。
## 实际伤害结算（弱点倍率 / 击杀 +15）属 ENG-S4-02/03。
var attack_frames: int = 12


func _enter() -> void:
	super._enter()
	duration_frames = attack_frames


func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if is_finished():
		(machine as StateMachine).try_transition(&"Recover")
