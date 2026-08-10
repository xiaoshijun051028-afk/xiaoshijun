extends GdUnitTestSuite
## ENG-S1-03 回归 · 闪无敌帧（AC-S1-05）：DASH_IFRAMES 期间受到的任何伤害均为 0；
## 无敌帧过后正常扣血；多来源（不同注入）同样被免疫（来源无关，契合多敌围攻）。

const TEST_DAMAGE: int = 10


func _make() -> PlayerCombat:
	var pc := PlayerCombat.new()
	add_child(pc)
	pc.initialize()
	return pc


func test_dash_grants_iframes_zero_damage() -> void:
	var pc := _make()
	assert_bool(pc.hp == GameConstants.PLAYER_MAX_HP).is_true()
	pc.input_dash()
	assert_bool(pc.current_state_name() == &"Dash").is_true()
	# 仍处于无敌帧内 → 0 伤害
	var applied := pc.take_damage(TEST_DAMAGE)
	assert_int(applied).is_equal(0)
	assert_int(pc.hp).is_equal(GameConstants.PLAYER_MAX_HP)


func test_multi_source_iframes_immuned() -> void:
	var pc := _make()
	pc.input_dash()
	# 两个不同来源的伤害都被免疫（来源无关）
	assert_int(pc.take_damage(TEST_DAMAGE)).is_equal(0)
	assert_int(pc.take_damage(99)).is_equal(0)
	assert_int(pc.hp).is_equal(GameConstants.PLAYER_MAX_HP)


func test_damage_applies_after_iframes() -> void:
	var pc := _make()
	pc.input_dash()
	# 推进超过 DASH_IFRAMES(10) 帧，离开无敌窗口
	for i in range(GameConstants.DASH_IFRAMES + 2):
		pc.physics_tick(0.0)
	assert_int(pc.take_damage(TEST_DAMAGE)).is_equal(TEST_DAMAGE)
	assert_int(pc.hp).is_equal(GameConstants.PLAYER_MAX_HP - TEST_DAMAGE)
