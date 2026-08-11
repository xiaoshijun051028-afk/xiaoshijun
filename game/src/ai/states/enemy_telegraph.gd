class_name EnemyTelegraphState
extends EnemyState
## 敌人预警（ENG-S4-02）。持续 telegraph_frames 后自动转 Attack。
## 进入时发 enemy_telegraph_started（消费方据此播 THREAT=#A62C6B 脉冲 + 音效，
## 颜色由消费方引用 ColorTokens.THREAT，不在信号里传，守"禁止硬编码色"铁律）。
## 退出时发 enemy_telegraph_cleared（脉冲收束、音效收尾）。
## 全覆盖预警语言：AC-S4-01「所有攻击 100% 有 THREAT 色 telegraph + 音效」。
var telegraph_frames: int = 48


func _enter() -> void:
	super._enter()
	duration_frames = telegraph_frames
	# 告警语言统一：telegraph 100% 覆盖 THREAT 语义色（epic-s4 §故事2 / AC-S4-01）。
	# 颜色不在信号携带——消费方（VFX/音效，S6/AUD）读 ColorTokens.THREAT。
	var owner := _owner_enemy()
	if owner != null:
		EventBus.enemy_telegraph_started.emit(owner, telegraph_frames)


func _exit() -> void:
	var owner := _owner_enemy()
	if owner != null:
		EventBus.enemy_telegraph_cleared.emit(owner)
	super._exit()


## telegraph 态的「敌人」宿主 = 持有本状态机的 EnemyCombat（machine 的 parent）。
## StateMachine._set_current 在调 _enter 前已注入 machine 引用，故此处可用。
func _owner_enemy() -> Node3D:
	var sm := machine as EnemyStateMachine
	if sm != null and sm.get_parent() is Node3D:
		return sm.get_parent() as Node3D
	return null


func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if is_finished():
		(machine as StateMachine).try_transition(&"Attack")
