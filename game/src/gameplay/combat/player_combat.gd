class_name PlayerCombat
extends Node
## S1 玩家战斗控制器（ENG-S1-02）。装配架构 §4.4 的状态节点树，并把「已裁决的单一意图」
## 路由进**唯一**转移入口 `CombatStateMachine.try_transition()`。
##
## 三条纪律：
##   1. **不做输入优先级仲裁**（格 > 闪 > 斩 在 InputManager，architecture §4.4 末段）。
##      本类只消费单一意图。FSM 不该知道「玩家同时按了三个键」，它只处理「玩家想做什么」。
##   2. **不自己跑 _physics_process**：tick 由宿主 Player 每物理帧调用 `physics_tick()`，
##      保证战斗推进与物理帧严格同拍、且顺序可控（architecture §3.2 第 2 条）。
##   3. **不持有任何窗口宽度**：CANCEL_WINDOW 只有 `State.is_cancellable()` 一个读取点。
##
## 状态名闭集与 EventBus.player_state_entered 的 9 态约定 1:1（当前装配 8 态，
## SlashHeavy 属 ENG-S1-03 重击，届时按同一模式追加即可，无需改本类结构）。

const STATE_IDLE: StringName = &"Idle"
const STATE_SLASH: StringName = &"Slash"
const STATE_DASH: StringName = &"Dash"
const STATE_GRAPPLE: StringName = &"Grapple"
const STATE_LEAP: StringName = &"Leap"
const STATE_PARRY: StringName = &"Parry"
const STATE_RESONATE: StringName = &"Resonate"
const STATE_HITSTUN: StringName = &"Hitstun"

## 战斗 FSM。装配完成前为 null。
var state_machine: CombatStateMachine = null

var _initialized: bool = false


func _ready() -> void:
	initialize()
	# tick 由宿主驱动，本节点不自转（同 StateMachine._ready 的约定）。
	set_physics_process(false)


## 装配状态树并进入 Idle。幂等 —— 测试可脱离场景树直接调用，
## 不必为了跑一条取消窗断言去实例化整个 Player 场景。
func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	state_machine = CombatStateMachine.new()
	state_machine.name = "StateMachine"
	state_machine.broadcasts_player_state = true   # 玩家 FSM：广播；敌人 FSM 置 false
	add_child(state_machine)

	_add_state(IdleState.new(), STATE_IDLE)
	_add_state(SlashState.new(), STATE_SLASH)
	_add_state(DashState.new(), STATE_DASH)
	_add_state(GrappleState.new(), STATE_GRAPPLE)
	_add_state(LeapState.new(), STATE_LEAP)
	_add_state(ParryState.new(), STATE_PARRY)
	_add_state(ResonateState.new(), STATE_RESONATE)
	_add_state(HitstunState.new(), STATE_HITSTUN)

	state_machine.enter_initial(state_machine.get_state(STATE_IDLE))


## 宿主每物理帧调用一次。整数帧推进的唯一驱动点。
func physics_tick(delta: float) -> void:
	if state_machine != null:
		state_machine.physics_tick(delta)


## 当前状态名（闭集）。HUD / DebugOverlay 的只读查询口。
func current_state_name() -> StringName:
	return state_machine.current_state_name if state_machine != null else &""


# =========================================================================
# 输入路由 —— 全部经同一个 try_transition()，返回是否被裁决接受
# =========================================================================

func input_slash() -> bool:
	return _request(STATE_SLASH)


func input_dash() -> bool:
	return _request(STATE_DASH)


func input_grapple() -> bool:
	return _request(STATE_GRAPPLE)


func input_leap() -> bool:
	return _request(STATE_LEAP)


func input_parry() -> bool:
	return _request(STATE_PARRY)


func input_resonate() -> bool:
	return _request(STATE_RESONATE)


## 受击：进入硬直（frames 上限由 HitstunState 钳到 HITSTUN_MAX_FRAMES）。
## 由命中结算调用（ENG-S1-03）。
func take_hit(frames: int) -> void:
	if state_machine != null:
		state_machine.enter_hitstun(frames)


func _add_state(state: CombatState, state_name: StringName) -> void:
	state.name = String(state_name)
	state_machine.add_child(state)


func _request(state_name: StringName) -> bool:
	if state_machine == null:
		return false
	return state_machine.try_transition(state_name)
