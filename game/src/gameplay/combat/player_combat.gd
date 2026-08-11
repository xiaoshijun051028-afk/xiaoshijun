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

## 生命值（ENG-S1-03）。伤害结算的唯一权威，命中经 take_damage() 改写。
var max_hp: int = GameConstants.PLAYER_MAX_HP
var hp: int = GameConstants.PLAYER_MAX_HP

## 出战角色数值（S9 抽卡注入；未注入时取默认基准，向后兼容 S1 手感）。
## attack_power 供战斗命中结算（后续专项接入）；defense 已接入 take_damage 减伤；
## move_speed / resonance_affinity 持有，供移动与共鸣结算消费。
var attack_power: int = 100
var defense: int = 100
var move_speed: float = 100.0
var resonance_affinity: int = 100

var _initialized: bool = false


func _ready() -> void:
	initialize()
	# tick 由宿主驱动，本节点不自转（同 StateMachine._ready 的约定）。
	set_physics_process(false)
	# S4-04：完美格破防联动。S1 的 _perform_perfect_parry 广播 enemy_staggered，
	# 本处订阅后让对应敌人经其唯一转移入口进入 Stagger（与 S1 共用逻辑，不复制状态机）。
	EventBus.enemy_staggered.connect(_on_enemy_staggered)


func _exit_tree() -> void:
	if EventBus.enemy_staggered.is_connected(_on_enemy_staggered):
		EventBus.enemy_staggered.disconnect(_on_enemy_staggered)


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
	# 池不足：终结技态经 ResonateState.can_enter_state() 被 FSM 拦截，本处显式发拒绝事件，
	# 供 HUD 灰显 / 音频拒绝提示（AC-S1-04 / ENG-S1-05；resonate.gd 注释点名的「表现侧」）。
	if not ResonancePool.can_afford(GameConstants.FINISHER_COST):
		EventBus.resonance_spend_rejected.emit(GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER)
		return false
	return _request(STATE_RESONATE)


## 受击：进入硬直（frames 上限由 HitstunState 钳到 HITSTUN_MAX_FRAMES）。
## 由命中结算调用（ENG-S1-03）。
func take_hit(frames: int) -> void:
	if state_machine != null:
		state_machine.enter_hitstun(frames)


## 受到 `amount` 点伤害（ENG-S1-03 / AC-S1-05）。
## 若当前状态无敌（如闪的 iframes），完全免疫、返回 0；否则扣血并广播 player_hp_changed。
## 返回实际受到的伤害（0 = 被免疫）。hp 不为负。命中来源无关 —— 多敌围攻同样生效。
func take_damage(amount: int) -> int:
	if amount <= 0 or state_machine == null:
		return 0
	var cs := state_machine.current_state as CombatState
	if cs != null and cs.is_invulnerable():
		return 0
	var dealt := maxi(1, amount * 100 / maxi(1, defense))
	var old := hp
	hp = max(0, hp - dealt)
	EventBus.player_hp_changed.emit(hp, old)
	return old - hp


# =========================================================================
# 完美格挡（ENG-S1-04 / AC-S1-03 / AC-S4-02）
# =========================================================================

## 慢动作（完美格挡专属，ENG-S1-04）。本类是「实际写 Engine.time_scale 的唯一之处」
## （architecture.md §5.2 / EventBus.time_dilation_* 注释）。共鸣终结技不进慢动作（AUD-1）。
var _time_dilating: bool = false
var _slowmo_timer: SceneTreeTimer = null


## 完美格挡：在格挡判定窗（PARRY_WINDOW）内挡下攻击 → 触发完美格。
## 返回是否构成完美格（仅当处于 Parry 且仍 armed 时为真）；否则不改变任何状态。
## `attacker` 为来袭攻击者（敌人实体），可传 null（无实体时仅产慢动作+共鸣，便于演练/测试）。
func parry_incoming(attacker: Node3D = null) -> bool:
	if current_state_name() != STATE_PARRY:
		return false
	var ps := state_machine.current_state as ParryState
	if ps == null or not ps.is_armed():
		return false
	_perform_perfect_parry(attacker)
	return true


func _perform_perfect_parry(attacker: Node3D) -> void:
	# 共鸣 +5（P4 支柱，经唯一增益入口）
	ResonancePool.add(GameConstants.GAIN_PERFECT_PARRY, ResonancePool.SOURCE_PERFECT_PARRY)
	# 广播事实（过去式信号，不改敌人状态 —— 敌人经 enemy_staggered 自行进入 Stagger）
	EventBus.perfect_parry_landed.emit(attacker)
	EventBus.enemy_staggered.emit(attacker, GameConstants.ENEMY_STAGGER_FRAMES)
	# 慢动作 0.3s 墙钟（非 tick），完美格挡专属
	start_time_dilation()


## 启动慢动作：Engine.time_scale = 0.3，墙钟 300ms（忽略 time_scale 的计时器）后复原。
## ⚠ 绝不用游戏 tick 计时（否则真实时长会被放大 ~3.3×，吞掉破防窗口）。
func start_time_dilation() -> void:
	if _time_dilating:
		return
	_time_dilating = true
	Engine.time_scale = GameConstants.PARRY_SLOWMO_SCALE
	EventBus.time_dilation_started.emit(GameConstants.PARRY_SLOWMO_SCALE, GameConstants.PARRY_SLOWMO_FRAMES)
	_slowmo_timer = get_tree().create_timer(float(GameConstants.PARRY_SLOWMO_MSEC) / 1000.0, true, false, true)
	_slowmo_timer.timeout.connect(_on_slowmo_timeout)


func _on_slowmo_timeout() -> void:
	end_time_dilation()


## 结束慢动作：复原 time_scale = 1.0 并广播。幂等（重复调用安全，避免测试/提前打断重复发信号）。
func end_time_dilation() -> void:
	if not _time_dilating:
		return
	_time_dilating = false
	if _slowmo_timer != null:
		if _slowmo_timer.timeout.is_connected(_on_slowmo_timeout):
			_slowmo_timer.timeout.disconnect(_on_slowmo_timeout)
		_slowmo_timer = null
	Engine.time_scale = 1.0
	EventBus.time_dilation_ended.emit()


func _add_state(state: CombatState, state_name: StringName) -> void:
	state.name = String(state_name)
	state_machine.add_child(state)


func _request(state_name: StringName) -> bool:
	if state_machine == null:
		return false
	return state_machine.try_transition(state_name)


## S4-04：敌人被完美格破防时，经其唯一转移入口进入 Stagger 硬直。
## enemy 可能为任意 Node3D；仅当它是 EnemyCombat 时才联动（其他实体忽略）。
func _on_enemy_staggered(enemy: Node3D, frames: int) -> void:
	var ec := enemy as EnemyCombat
	if ec != null:
		ec.apply_stagger(frames)


## S9：应用出战角色的最终数值（抽卡 roll 锁定后的值）。
## max_hp 直接生效并满血；其余维度持有，供战斗 / 移动 / 共鸣结算消费。
func apply_character_stats(inst: CharacterInstance) -> void:
	if inst == null:
		return
	max_hp = inst.final_hp
	hp = max_hp
	attack_power = inst.final_attack
	defense = inst.final_defense
	move_speed = float(inst.final_move_speed)
	resonance_affinity = inst.final_affinity
