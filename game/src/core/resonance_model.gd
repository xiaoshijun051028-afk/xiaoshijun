## 共鸣池的**纯逻辑**内核（无场景树、无信号、无 Autoload 依赖）。
##
## 存在理由（ADR-002「负面/成本」的对策）：Autoload 是全局状态，测试需隔离。
## 把数学抽到可独立 `new()` 的类里，AC-S3-01..03 就能在毫秒级、零场景开销下断言，
## 且不会被其他测试的全局状态污染。Autoload `ResonancePool` 只是它的全局宿主。
##
## 纪律：本类**不持有规则常量**，全部从 GameConstants 读（ADR-002 决策 2）。
## 本类**没有 setter**；外部只能经 try_spend() / add() / reset() 三个入口改值。
class_name ResonanceModel
extends RefCounted

## 私有当前值。下划线前缀 + 无 setter = 架构层强制 P4 互斥（ADR-002 决策 1）。
var _current: int = 0

## 只读访问器：外部可读不可写。
var current: int:
	get:
		return _current


func _init(initial_value: int = -1) -> void:
	# -1 = 用 GDD 初始值；显式传值仅供测试与读档使用。
	var start: int = initial_value if initial_value >= 0 else GameConstants.RESONANCE_INITIAL
	_current = clampi(start, 0, GameConstants.RESONANCE_MAX)


## 是否付得起。**只读判定，不产生副作用** —— 调用它不会扣费也不会发拒绝事件。
func can_afford(cost: int) -> bool:
	return _current >= cost


## 唯一扣费入口。成功返回 true 并扣减；余额不足返回 false 且**分文不扣**。
##
## ★ AC-S3-03（P4 支柱唯一硬证据）由本函数保证：
##   池 = 35 时 try_spend(GATE_COST=30) → true（35 ≥ 30）
##            try_spend(FINISHER_COST=40) → false（35 < 40）
##   因为开门与终结技读的是**同一个 _current**，互斥不依赖任何人的自律。
func try_spend(cost: int) -> bool:
	if cost < 0:
		# 负成本 = 变相增益，会绕过 add() 的上限钳制。视为编程错误而非玩法路径。
		push_error("ResonanceModel.try_spend: cost 不得为负（收到 %d）" % cost)
		return false
	if _current < cost:
		return false
	_apply(_current - cost)
	return true


## 唯一增益入口。自动钳制到上限，**溢出部分丢弃不保留**（GDD S3 §⑥ / AC-S3-01）。
## 返回本次实际生效的增量（可能小于 amount，因为撞了上限）。
func add(amount: int) -> int:
	var before: int = _current
	_apply(_current + amount)
	return _current - before


## 复位。仅供 reset_for_test() 与读档使用；读档值必须再次钳制（ADR-004 决策 5 防篡改）。
func reset(value: int = -1) -> void:
	var target: int = value if value >= 0 else GameConstants.RESONANCE_INITIAL
	_apply(target)


## 唯一写入点。所有路径必经此处 → 上限钳制不可能被绕过。
func _apply(v: int) -> void:
	_current = clampi(v, 0, GameConstants.RESONANCE_MAX)
