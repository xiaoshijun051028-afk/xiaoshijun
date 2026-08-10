class_name EnemyIdleState
extends EnemyState
## 敌人待机（ENG-S4-01）。中立态，持续直到 AI 发起 Telegraph 或受击进入 Stagger/Dead。
func _enter() -> void:
	super._enter()
	duration_frames = -1   # 持续直到外部触发转移
