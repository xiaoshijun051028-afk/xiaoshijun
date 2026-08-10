class_name EnemyStateMachine
extends StateMachine
## 敌人 FSM（ENG-S4-01 / ADR-003 复用 S0 基类 StateMachine）。
##
## 状态集（epic-s4 §故事1 闭集）：Idle / Telegraph / Attack / Recover / Stagger / Dead。
## - broadcasts_player_state = false：敌人状态走 enemy_* 信号，绝不广播 player_state_entered。
## - 合法转移图由 _LEGAL 邻接表定义（死态 Dead 不可再转移）。
## - Stagger 期间禁新 Telegraph（架构 §4.5「硬直中禁新 telegraph」），由邻接表天然保证
##   （Stagger 的合法目标只有 Idle / Dead）。
## - 状态迁移写环形日志 _ring（架构 §11.4 src/ai/** 可调试）。

const STATE_IDLE: StringName = &"Idle"
const STATE_TELEGRAPH: StringName = &"Telegraph"
const STATE_ATTACK: StringName = &"Attack"
const STATE_RECOVER: StringName = &"Recover"
const STATE_STAGGER: StringName = &"Stagger"
const STATE_DEAD: StringName = &"Dead"

## 合法转移邻接表（闭集）。Dead 为终态。
const _LEGAL: Dictionary = {
	STATE_IDLE: [STATE_TELEGRAPH, STATE_STAGGER, STATE_DEAD],
	STATE_TELEGRAPH: [STATE_ATTACK, STATE_STAGGER, STATE_DEAD],
	STATE_ATTACK: [STATE_RECOVER, STATE_STAGGER, STATE_DEAD],
	STATE_RECOVER: [STATE_IDLE, STATE_STAGGER, STATE_DEAD],
	STATE_STAGGER: [STATE_IDLE, STATE_DEAD],
	STATE_DEAD: [],
}

## 状态迁移环形日志。元素 = {from, to, tick}。
var _ring: Array[Dictionary] = []
const RING_CAP: int = 32


func _ready() -> void:
	broadcasts_player_state = false
	super._ready()


## 取状态节点（S0 StateMachine 无此方法，CombatStateMachine 有；敌人 FSM 同样需要，
## 用于 enter_initial 装配）。
func get_state(name: StringName) -> State:
	return get_node_or_null(NodePath(String(name))) as State


## 进入条件：先过基类 hitstun 规则，再过本 FSM 合法转移图。
func can_enter(target: State) -> bool:
	if not super.can_enter(target):
		return false
	var to := StringName(target.name)
	if not _LEGAL.has(current_state_name):
		return false
	return to in _LEGAL[current_state_name]


func _set_current(state: State) -> void:
	var old := current_state_name
	super._set_current(state)
	_ring.append({"from": old, "to": StringName(state.name), "tick": 0})
	if _ring.size() > RING_CAP:
		_ring.remove_at(0)


## 环形日志只读查询口（调试 / 测试）。
func recent_transitions() -> Array[Dictionary]:
	return _ring
