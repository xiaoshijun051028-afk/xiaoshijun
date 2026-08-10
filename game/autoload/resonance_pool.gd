## Autoload #3 · S3 共鸣池权威（★ 支柱 P4「共鸣统一」的工程落点）。
##
## 依据 ADR-002。四条不可协商的约束：
##   1. `_current` 私有、**无 setter**；唯一入口 try_spend() / add()。
##   2. 常量不落地在池里，全部读 GameConstants（改平衡不动池代码）。
##   3. 同帧双消耗裁决：终结技优先，闸门排队（GDD S3 §⑥）。
##   4. 存档只存当前值，不存任何常量（ADR-004 决策 3）。
##
## ★ 为什么开门与终结技天然互斥：二者调用的是**同一个** try_spend()，读的是
##   **同一份** _current。互斥性是物理事实，不是靠代码评审保证的自律。
##   池 = 35 → 开门(30) 可、终结技(40) 不可 —— 这就是 AC-S3-03。
##
## 本单例还是**脱战计时权威**（architecture.md §5.2 combat_state_changed 契约表）：
## 脱战被动回充的计时已在此，故 in_combat 翻转由此广播，不另立系统。
extends Node

## 扣费原因（reason）的闭集。用 StringName 常量而非裸字符串，防拼写漂移导致
## DebugOverlay 环形日志分组失效、以及 HUD 对不同拒绝原因误分派。
const REASON_GATE: StringName = &"gate"
const REASON_FINISHER: StringName = &"finisher"

## 增益来源（source）的闭集，对应 systems-index §2 五种获取途径。
const SOURCE_HIT: StringName = &"hit"
const SOURCE_PERFECT_PARRY: StringName = &"perfect_parry"
const SOURCE_KILL: StringName = &"kill"
const SOURCE_NODE: StringName = &"node"
const SOURCE_OUT_OF_COMBAT: StringName = &"out_of_combat"
const SOURCE_LOAD: StringName = &"load"

## 变更来源环形日志容量（ADR-002「负面/成本」对策：可回看最近 N 次变更来源）。
const CHANGE_LOG_CAPACITY: int = 32

## 纯逻辑内核。Autoload 只是它的全局宿主（ADR-002）。
var _model: ResonanceModel = null

## 战斗状态。true = 交战中（停止被动回充）。
var _in_combat: bool = false

## 距上次敌人接触已过的帧数。达到 OUT_OF_COMBAT_FRAMES 即判脱战。
var _frames_since_combat: int = 0

## 脱战被动回充的秒计数器（整数帧累加，不用 float 累加秒 —— architecture.md §3.2 第 6 条）。
var _regen_frame_accum: int = 0

## 单例自身的物理 tick 计数。节点 cd 用它做**绝对帧**比较，
## 比「每个节点各自倒计时」省一次全量遍历，且不会因节点未被 _physics_process 而漂移。
var _tick: int = 0

## node_id -> 上次触发时的 _tick。cd 判定 = (_tick - last) >= NODE_COOLDOWN_FRAMES。
var _node_last_tick: Dictionary = {}

## 同帧被拒的闸门请求队列（GDD S3 §⑥「闸门排队」/ ADR-002 决策 3）。
## 下一 tick 重试一次，仍失败即丢弃并提示。
var _pending_gate: StringName = &""

## 最近 N 次变更来源。元素形如 {tick, delta, value, source}。
var _change_log: Array[Dictionary] = []


## 只读访问器（L3 权威查询）。HUD / AudioDirector 冷启动对齐读这里。
var current: int:
	get:
		return _model.current if _model != null else 0


## 当前是否交战中（L3 权威查询）。
var in_combat: bool:
	get:
		return _in_combat


func _ready() -> void:
	_model = ResonanceModel.new()
	# 玩法逻辑一律跑 _physics_process（architecture.md §3.2 第 2 条）。
	# 本单例只在 _physics_process 推进计数，_process 完全不用。
	set_process(false)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_tick_combat_state()
	_tick_out_of_combat_regen()
	_retry_pending_gate()


# =========================================================================
# 消耗 —— 唯一入口
# =========================================================================

## ★ 唯一扣费入口。成功扣减并返回 true；不足返回 false 且不扣，同时发拒绝事件。
##
## 调用方**必须**检查返回值。任何绕过本函数改 _current 的写法都要在评审打回
## （ADR-002 决策 1）——那等于把 P4 支柱拆掉。
func try_spend(cost: int, reason: StringName) -> bool:
	var before: int = _model.current
	if not _model.try_spend(cost):
		EventBus.resonance_spend_rejected.emit(cost, reason)
		return false
	_broadcast(before, reason)
	return true


## 便捷入口：开闸门。等价 try_spend(GATE_COST, REASON_GATE)。
## 失败时把 gate_id 压入排队，下一 tick 重试一次（GDD S3 §⑥）。
func try_spend_gate(gate_id: StringName) -> bool:
	if try_spend(GameConstants.GATE_COST, REASON_GATE):
		EventBus.gate_opened.emit(gate_id)
		return true
	# 同帧竞争裁决：终结技优先，闸门排队。只排一个（后到覆盖先到，避免无界队列）。
	_pending_gate = gate_id
	return false


## 便捷入口：放终结技。等价 try_spend(FINISHER_COST, REASON_FINISHER)。
func try_spend_finisher(damage: int = 0) -> bool:
	if try_spend(GameConstants.FINISHER_COST, REASON_FINISHER):
		EventBus.finisher_executed.emit(damage)
		return true
	return false


## 只读判定，无副作用。HUD 灰显 / 音频三态用它（L3 权威查询）。
func can_afford(cost: int) -> bool:
	return _model.can_afford(cost)


func can_afford_gate() -> bool:
	return _model.can_afford(GameConstants.GATE_COST)


func can_afford_finisher() -> bool:
	return _model.can_afford(GameConstants.FINISHER_COST)


# =========================================================================
# 增益 —— 唯一入口
# =========================================================================

## ★ 唯一增益入口。自动钳制上限，溢出丢弃（AC-S3-01）。
## 所有增益来源（命中 +1 / 完美格 +5 / 击杀 +15 / 节点 +10 / 脱战 +2/s）必经此处。
func add(amount: int, source: StringName) -> void:
	var before: int = _model.current
	_model.add(amount)
	_broadcast(before, source)


## 世界共鸣节点触发。+GAIN_NODE 并启动 NODE_COOLDOWN_FRAMES 冷却。
##
## ★ AC-S3-04：cd 内重复调用返回 false 且**不二次增益**。
## cd 用整数帧比较（绝对 tick 差），确定性、与刷新率解耦。
func resonate_at_node(node_id: StringName) -> bool:
	if not is_node_ready_to_resonate(node_id):
		return false
	_node_last_tick[node_id] = _tick
	add(GameConstants.GAIN_NODE, SOURCE_NODE)
	EventBus.resonance_node_consumed.emit(node_id)
	return true


## 节点是否已过 cd。首次触发（无记录）恒为 true。
func is_node_ready_to_resonate(node_id: StringName) -> bool:
	if not _node_last_tick.has(node_id):
		return true
	var elapsed: int = _tick - int(_node_last_tick[node_id])
	return elapsed >= GameConstants.NODE_COOLDOWN_FRAMES


## 节点剩余冷却帧数（DebugOverlay / HUD 用）。已就绪返回 0。
func node_cooldown_remaining(node_id: StringName) -> int:
	if is_node_ready_to_resonate(node_id):
		return 0
	var elapsed: int = _tick - int(_node_last_tick[node_id])
	return GameConstants.NODE_COOLDOWN_FRAMES - elapsed


# =========================================================================
# 战斗状态 / 脱战被动回充
# =========================================================================

## 敌人接触。战斗系统每次玩家与敌人发生攻防交互时调用，用于刷新脱战计时。
func notify_combat_contact() -> void:
	_frames_since_combat = 0
	if not _in_combat:
		_in_combat = true
		_regen_frame_accum = 0
		EventBus.combat_state_changed.emit(true)


func _tick_combat_state() -> void:
	if not _in_combat:
		return
	_frames_since_combat += 1
	if _frames_since_combat >= GameConstants.OUT_OF_COMBAT_FRAMES:
		_in_combat = false
		_regen_frame_accum = 0
		EventBus.combat_state_changed.emit(false)


func _tick_out_of_combat_regen() -> void:
	if _in_combat:
		return
	_regen_frame_accum += 1
	if _regen_frame_accum < GameConstants.TICKS_PER_SECOND:
		return
	# 满 60 tick = 1 秒，回充一次。用整数帧累加而非 delta 求和，保证与刷新率解耦。
	_regen_frame_accum = 0
	if _model.current >= GameConstants.RESONANCE_MAX:
		return
	add(GameConstants.GAIN_OUT_OF_COMBAT_PER_SEC, SOURCE_OUT_OF_COMBAT)


func _retry_pending_gate() -> void:
	if _pending_gate == &"":
		return
	var gate_id: StringName = _pending_gate
	# 先清空再重试：无论成败本 tick 后都不再排队（GDD S3 §⑥「下一 tick 重试一次即丢弃」）。
	_pending_gate = &""
	if try_spend(GameConstants.GATE_COST, REASON_GATE):
		EventBus.gate_opened.emit(gate_id)


# =========================================================================
# 存档接口（ADR-004：只存当前值，绝不存常量）
# =========================================================================

## 供 SaveManager 收集快照。**只返回当前值**，不含 MAX / GATE_COST 等规则常量。
func capture_save_state() -> Dictionary:
	return {"current": _model.current}


## 供 SaveManager 应用读档。逐字段钳制（防篡改存档写入 999）。
func apply_save_state(data: Dictionary) -> void:
	var loaded: int = int(data.get("current", GameConstants.RESONANCE_INITIAL))
	var before: int = _model.current
	_model.reset(clampi(loaded, 0, GameConstants.RESONANCE_MAX))
	_broadcast(before, SOURCE_LOAD)


# =========================================================================
# 测试隔离（ADR-002：gdUnit4 before_test() 调用）
# =========================================================================

## 复位全部全局状态。**必须**在每个测试的 before_test() 调用，否则测试互相污染。
## value = -1 表示用 GDD 初始值 50。
func reset_for_test(value: int = -1) -> void:
	if _model == null:
		_model = ResonanceModel.new()
	_model.reset(value)
	_in_combat = false
	_frames_since_combat = 0
	_regen_frame_accum = 0
	_tick = 0
	_node_last_tick.clear()
	_pending_gate = &""
	_change_log.clear()


## 测试专用：手动推进 N 个物理 tick，无需真实场景树。
## 生产代码禁止调用（gdlint 无法拦，靠评审）。
func advance_ticks_for_test(count: int) -> void:
	for _i: int in count:
		_physics_process(1.0 / float(GameConstants.TICKS_PER_SECOND))


## DebugOverlay 环形日志读取口。
func get_change_log() -> Array[Dictionary]:
	return _change_log


# =========================================================================
# 内部
# =========================================================================

func _broadcast(before: int, source: StringName) -> void:
	var after: int = _model.current
	if after == before:
		# 无变化不广播：避免上限饱和时每秒一次的空事件把 HUD/音频打满。
		return
	_log_change(after - before, after, source)
	EventBus.resonance_changed.emit(after, before)


func _log_change(delta: int, value: int, source: StringName) -> void:
	_change_log.append({"tick": _tick, "delta": delta, "value": value, "source": source})
	if _change_log.size() > CHANGE_LOG_CAPACITY:
		_change_log.remove_at(0)
