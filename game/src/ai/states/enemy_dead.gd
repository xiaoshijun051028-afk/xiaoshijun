class_name EnemyDeadState
extends EnemyState
## 敌人死亡（ENG-S4-01）。终态，持续直到被移除。无合法转移（邻接表为空）。
func _enter() -> void:
	super._enter()
	duration_frames = -1   # 终态
