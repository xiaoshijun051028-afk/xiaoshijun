class_name EnemyCombat
extends Node3D
## 敌人战斗控制器（ENG-S4-01）。装配敌人 FSM（复用 S0 StateMachine，状态集 6 态），
## 持有 hp（来自 EnemyDefinition）与受击 / 破防 / 死亡接口。tick 由宿主每物理帧调用 physics_tick()。
##
## 纪律：本类**不做 AI 决策**（何时起手 telegraph 由 S4 AI 控制器；本故事只搭 FSM 骨架）。
## 完美格破防的联动点 = apply_stagger()（ENG-S4-04 监听 enemy_staggered 后调用）。

const STATE_IDLE: StringName = &"Idle"
const STATE_TELEGRAPH: StringName = &"Telegraph"
const STATE_ATTACK: StringName = &"Attack"
const STATE_RECOVER: StringName = &"Recover"
const STATE_STAGGER: StringName = &"Stagger"
const STATE_DEAD: StringName = &"Dead"

## 敌人 FSM。装配完成前为 null。
var state_machine: EnemyStateMachine = null

## 静态定义（数据驱动 hp / telegraph / dmg / 移速 / 弱点）。
var definition: EnemyDefinition = null

## 生命值（ENG-S4-01 骨架）。伤害结算唯一权威。
var max_hp: int = 100
var hp: int = 100

var _initialized: bool = false


func _ready() -> void:
	initialize()
	set_physics_process(false)


## 装配状态树并进入 Idle。def 缺省时用空 EnemyDefinition（默认值，供测试 / 占位）。
func initialize(def: EnemyDefinition = null) -> void:
	if _initialized:
		return
	_initialized = true
	definition = def if def != null else EnemyDefinition.new()
	max_hp = definition.max_hp
	hp = definition.max_hp

	state_machine = EnemyStateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)

	_add_state(EnemyIdleState.new(), STATE_IDLE)
	_add_state(EnemyTelegraphState.new(), STATE_TELEGRAPH)
	_add_state(EnemyAttackState.new(), STATE_ATTACK)
	_add_state(EnemyRecoverState.new(), STATE_RECOVER)
	_add_state(EnemyStaggerState.new(), STATE_STAGGER)
	_add_state(EnemyDeadState.new(), STATE_DEAD)

	# 数据驱动：把定义里的 telegraph 帧灌进 Telegraph 态（ENG-S4-02 会继续灌其余字段）。
	var ts := state_machine.get_state(STATE_TELEGRAPH) as EnemyTelegraphState
	if ts != null:
		ts.telegraph_frames = definition.telegraph_frames

	state_machine.enter_initial(state_machine.get_state(STATE_IDLE))


## 宿主每物理帧调用一次。整数帧推进的唯一驱动点。
func physics_tick(delta: float) -> void:
	if state_machine != null:
		state_machine.physics_tick(delta)


func current_state_name() -> StringName:
	return state_machine.current_state_name if state_machine != null else &""


## 受击扣血（ENG-S4-01 骨架）。hp 不为负；归零转 Dead 并发 enemy_died。
## hit_weakpoint=true 时按定义弱点倍率放大（ENG-S4-03）；倍率来自 EnemyDefinition.weakpoint_multiplier，非字面量。
## 击杀 +15（adr-002）属后续击杀结算，不在本函数。
func take_damage(amount: int, hit_weakpoint: bool = false) -> int:
	if amount <= 0 or hp <= 0:
		return 0
	var dealt := amount
	if hit_weakpoint and definition != null and definition.weakpoint_multiplier > 0.0:
		dealt = int(roundf(dealt * definition.weakpoint_multiplier))
	var old := hp
	hp = max(0, hp - dealt)
	if hp <= 0:
		state_machine.try_transition(STATE_DEAD)
		EventBus.enemy_died.emit(self)
	return old - hp


## 完美格破防联动点（ENG-S4-04）：进入 Stagger 硬直（默认 ENEMY_STAGGER_FRAMES）。
## 返回是否成功进入（邻接表保证仅从非 Dead 态可入）。
func apply_stagger(frames: int = GameConstants.ENEMY_STAGGER_FRAMES) -> bool:
	return state_machine.try_transition(STATE_STAGGER)


func _add_state(state: EnemyState, state_name: StringName) -> void:
	state.name = String(state_name)
	state_machine.add_child(state)
