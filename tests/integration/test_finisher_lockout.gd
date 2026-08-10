extends GdUnitTestSuite
## ENG-S1-05 回归 · 共鸣终结技·池不足锁定（AC-S1-04）。
## 终结技扣费经 ResonancePool.try_spend(FINISHER_COST) 唯一入口：
##   池 ≥ 40 → 可进入 Resonate 态并扣 40；
##   池 < 40 → 终结技态被 ResonateState.can_enter_state() 拦截，input_resonate 返回 false、
##             池不变、且 emit resonance_spend_rejected（供 HUD 灰显 / 音频拒绝）。

var _rejected_cost: int = -1
var _rejected_reason: StringName = &""


func before_test() -> void:
	_rejected_cost = -1
	_rejected_reason = &""
	EventBus.resonance_spend_rejected.connect(_on_rejected)


func after_test() -> void:
	EventBus.resonance_spend_rejected.disconnect(_on_rejected)
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)


func _on_rejected(cost: int, reason: StringName) -> void:
	_rejected_cost = cost
	_rejected_reason = reason


func _make() -> PlayerCombat:
	var pc := PlayerCombat.new()
	add_child(pc)
	pc.initialize()
	return pc


func test_finisher_locked_below_cost() -> void:
	ResonancePool.reset_for_test(GameConstants.FINISHER_COST - 1)   # 39
	assert_int(ResonancePool.current).is_equal(39)
	var pc := _make()
	var ok := pc.input_resonate()
	assert_bool(ok).is_false()                                      # 不可释放
	assert_bool(pc.current_state_name() != &"Resonate").is_true()
	assert_int(ResonancePool.current).is_equal(39)                  # 池不变
	assert_int(_rejected_cost).is_equal(GameConstants.FINISHER_COST) # 拒绝事件已发
	assert_str(String(_rejected_reason)).is_equal(String(ResonancePool.REASON_FINISHER))


func test_finisher_unlocked_at_exact_cost() -> void:
	ResonancePool.reset_for_test(GameConstants.FINISHER_COST)       # 40
	assert_int(ResonancePool.current).is_equal(40)
	var pc := _make()
	var ok := pc.input_resonate()
	assert_bool(ok).is_true()                                       # 可释放
	assert_bool(pc.current_state_name() == &"Resonate").is_true()
	assert_int(ResonancePool.current).is_equal(0)                   # 扣 40 → 0
	assert_int(_rejected_cost).is_equal(-1)                         # 无拒绝事件


func test_finisher_unlocked_above_cost_spends_forty() -> void:
	ResonancePool.reset_for_test(50)
	assert_int(ResonancePool.current).is_equal(50)
	var pc := _make()
	assert_bool(pc.input_resonate()).is_true()
	assert_int(ResonancePool.current).is_equal(10)                 # 50 - 40
