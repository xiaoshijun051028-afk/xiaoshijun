class_name StateMachine
extends Node
## 节点化 FSM（ADR-003 / architecture §4.4）。持有 current_state；try_transition() 是唯一转移入口。
##
## 纪律（architecture §5.1 / ADR-003 §4）：
##   - 转移裁决第 5 步 emit EventBus.player_state_entered(state_name)（仅玩家 FSM；
##     敌人状态走 enemy_* 系列，见 broadcasts_player_state 开关）。
##   - hitstun 期间拒绝非受击类转移（architecture §5.3 流 B / GameConstants.HITSTUN_MAX_FRAMES）。
##   - 取消窗由 State.is_cancellable() 单点判定，本类不重复实现窗口宽度。
##
## 纯逻辑载体：tick 由宿主（Player）每物理帧调用 physics_tick() 驱动。

signal state_changed(old_name: StringName, new_name: StringName)

## 当前状态节点。
var current_state: State = null

## 当前状态名（PascalCase，== 状态节点 node.name，架构 §4.4 闭集）。
var current_state_name: StringName = &""

## 是否向 EventBus 广播 player_state_entered（玩家 FSM = true；敌人 FSM = false，S4 置 false）。
var broadcasts_player_state: bool = true

## 进入 hitstun 的剩余 tick。>0 时拒绝非受击类转移，防卡死。
var _hitstun_frames_left: int = 0


func _ready() -> void:
	set_physics_process(false)   # tick 由宿主每物理帧显式驱动


## 注册并立即进入某状态（启动用）。state 必须是本节点的子节点。
func enter_initial(state: State) -> void:
	_set_current(state)


## 唯一转移入口。to_name 必须对应一个子节点 State。返回是否成功转移。
func try_transition(to_name: StringName) -> bool:
	var target := get_node_or_null(NodePath(String(to_name))) as State
	if target == null:
		push_error("StateMachine.try_transition: 未知状态 %s" % to_name)
		return false
	if not can_enter(target):
		return false
	_set_current(target)
	return true


## 进入条件校验。基类拒绝 hitstun 期间的任意转移（Hitstun 自身除外）。
func can_enter(_target: State) -> bool:
	if _hitstun_frames_left > 0:
		return false
	return true


## 每物理 tick 驱动当前状态 + hitstun 倒计时。
func physics_tick(delta: float) -> void:
	if _hitstun_frames_left > 0:
		_hitstun_frames_left -= 1
	if current_state != null:
		current_state.physics_tick(delta)


## 进入 hitstun（由战斗判定调用）。帧数来自 GameConstants.HITSTUN_MAX_FRAMES。
func enter_hitstun(frames: int) -> void:
	_hitstun_frames_left = frames
	try_transition(&"Hitstun")


func _set_current(state: State) -> void:
	var old := current_state_name
	if current_state != null and current_state != state:
		current_state._exit()
	current_state = state
	current_state_name = StringName(state.name)
	state.machine = self
	state._enter()
	state_changed.emit(old, current_state_name)
	if broadcasts_player_state:
		EventBus.player_state_entered.emit(current_state_name)
