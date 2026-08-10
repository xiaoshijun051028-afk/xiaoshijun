extends GdUnitTestSuite
## S3-04 · 扣费/增益唯一入口 emit EventBus 广播；失败 emit resonance_spend_rejected。
##
## 用本地计数器接收信号（版本无关，不依赖 gdUnit4 信号专用 matcher），
## 断言「改状态必广播、失败必拒广播」的契约（architecture §5.1 L2 红线）。

var _changed := 0
var _rejected := 0
var _node := 0


func _on_changed(_a: int, _b: int) -> void:
	_changed += 1


func _on_rejected(_c: int, _r: StringName) -> void:
	_rejected += 1


func _on_node(_id: StringName) -> void:
	_node += 1


func before_test() -> void:
	ResonancePool.reset_for_test(50)
	_changed = 0
	_rejected = 0
	_node = 0
	EventBus.resonance_changed.connect(_on_changed)
	EventBus.resonance_spend_rejected.connect(_on_rejected)
	EventBus.resonance_node_consumed.connect(_on_node)


func after_test() -> void:
	EventBus.resonance_changed.disconnect(_on_changed)
	EventBus.resonance_spend_rejected.disconnect(_on_rejected)
	EventBus.resonance_node_consumed.disconnect(_on_node)


func test_add_emits_changed() -> void:
	ResonancePool.add(5, ResonancePool.SOURCE_HIT)
	assert_int(_changed).is_equal(1)
	assert_int(ResonancePool.current).is_equal(55)


func test_spend_emits_changed_not_rejected() -> void:
	ResonancePool.try_spend(GameConstants.GATE_COST, ResonancePool.REASON_GATE)
	assert_int(_changed).is_equal(1)
	assert_int(_rejected).is_equal(0)


func test_insufficient_spend_emits_rejected_not_changed() -> void:
	ResonancePool.reset_for_test(10)
	ResonancePool.try_spend(GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER)
	assert_int(_rejected).is_equal(1)
	assert_int(_changed).is_equal(0)


func test_node_resonate_emits_node_consumed() -> void:
	ResonancePool.resonate_at_node(&"e1")
	assert_int(_node).is_equal(1)
