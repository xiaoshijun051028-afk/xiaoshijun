extends GdUnitTestSuite
## S3 节点共鸣 · AC-S3-04（节点 5s cd 内重复触发不二次增益）
##
## 5s = 300 tick（GameConstants.NODE_COOLDOWN_FRAMES）。cd 用整数帧绝对差比较，
## 确定性、与刷新率解耦（architecture §3 时间基准）。resonate_at_node() 是唯一增益入口，
## cd 判定在 ResonancePool，不在 EchoDirector（ADR-002 单一真相源）。

func before_test() -> void:
	ResonancePool.reset_for_test(50)
	# 进入战斗以禁用脱战被动回充，隔离变量（避免 advance_ticks 期间池值被回充扰动断言）。
	ResonancePool.notify_combat_contact()


func after_test() -> void:
	ResonancePool.reset_for_test(50)


func test_node_gain_adds_10() -> void:
	var before := ResonancePool.current
	var ok := ResonancePool.resonate_at_node(&"node_a")
	assert_bool(ok).is_true()
	assert_int(ResonancePool.current).is_equal(before + GameConstants.GAIN_NODE)


func test_node_cd_blocks_repeat_within_window() -> void:
	var ok1 := ResonancePool.resonate_at_node(&"node_a")
	assert_bool(ok1).is_true()
	# 立刻二次触发：仍在 cd → 失败且不二次增益
	var ok2 := ResonancePool.resonate_at_node(&"node_a")
	assert_bool(ok2).is_false()
	assert_int(ResonancePool.current).is_equal(50 + GameConstants.GAIN_NODE)


func test_node_cd_remaining_positive_then_zero() -> void:
	ResonancePool.resonate_at_node(&"node_b")
	assert_int(ResonancePool.node_cooldown_remaining(&"node_b")).is_greater(0)
	# 推进 < cd → 仍未就绪
	ResonancePool.advance_ticks_for_test(100)
	assert_bool(ResonancePool.is_node_ready_to_resonate(&"node_b")).is_false()
	# 推进满 cd（300 tick）→ 就绪，剩余 0
	ResonancePool.advance_ticks_for_test(GameConstants.NODE_COOLDOWN_FRAMES)
	assert_bool(ResonancePool.is_node_ready_to_resonate(&"node_b")).is_true()
	assert_int(ResonancePool.node_cooldown_remaining(&"node_b")).is_equal(0)


func test_node_repeat_after_cd_succeeds() -> void:
	ResonancePool.resonate_at_node(&"node_c")
	ResonancePool.advance_ticks_for_test(GameConstants.NODE_COOLDOWN_FRAMES)
	var ok := ResonancePool.resonate_at_node(&"node_c")
	assert_bool(ok).is_true()


func test_distinct_nodes_have_independent_cd() -> void:
	ResonancePool.resonate_at_node(&"node_x")
	# 未触发过的节点恒就绪（首次触发无 cd 记录）
	assert_bool(ResonancePool.is_node_ready_to_resonate(&"node_y")).is_true()
