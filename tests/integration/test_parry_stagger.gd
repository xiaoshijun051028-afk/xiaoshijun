extends GdUnitTestSuite
## ENG-S1-04 回归 · 完美格 → 破防 + 慢动作（AC-S1-03 / AC-S4-02）。
## 注入「telegraph 攻击在 PARRY_WINDOW 内被挡下」，断言：
##   1) 敌人破防硬直 = ENEMY_STAGGER_FRAMES(72) ≥1.2s（enemy_staggered 信号）
##   2) 慢动作启动：Engine.time_scale=0.3 + time_dilation_started(0.3, 18)
##   3) 共鸣池 +5（ResonancePool.add(SOURCE_PERFECT_PARRY)）
## 非 armed / 非 Parry 态时 parry_incoming 返回 false，不产生上述任何效果（架构 §4.4 单点）。

var _captured_stagger_frames: int = -1
var _captured_scale: float = -1.0
var _captured_duration: int = -1


func before_test() -> void:
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)
	Engine.time_scale = 1.0
	_captured_stagger_frames = -1
	_captured_scale = -1.0
	_captured_duration = -1
	EventBus.enemy_staggered.connect(_on_enemy_staggered)
	EventBus.time_dilation_started.connect(_on_dilation_started)


func after_test() -> void:
	EventBus.enemy_staggered.disconnect(_on_enemy_staggered)
	EventBus.time_dilation_started.disconnect(_on_dilation_started)
	Engine.time_scale = 1.0
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)


func _on_enemy_staggered(_enemy: Node3D, frames: int) -> void:
	_captured_stagger_frames = frames


func _on_dilation_started(scale: float, duration_frames: int) -> void:
	_captured_scale = scale
	_captured_duration = duration_frames


func _make() -> PlayerCombat:
	var pc := PlayerCombat.new()
	add_child(pc)
	pc.initialize()
	return pc


func test_perfect_parry_staggers_enemy_gains_resonance_slowmo() -> void:
	var pc := _make()
	pc.input_parry()
	assert_bool(pc.current_state_name() == &"Parry").is_true()
	var before := ResonancePool.current
	assert_int(before).is_equal(GameConstants.RESONANCE_INITIAL)
	# 注入 telegraph 攻击在 armed 窗内被挡下
	var ok := pc.parry_incoming(null)
	assert_bool(ok).is_true()
	# 1) 共鸣 +5
	assert_int(ResonancePool.current).is_equal(before + GameConstants.GAIN_PERFECT_PARRY)
	# 2) 敌人破防 ≥1.2s（72 帧）
	assert_int(_captured_stagger_frames).is_equal(GameConstants.ENEMY_STAGGER_FRAMES)
	# 3) 慢动作启动：墙钟 0.3s（scale 0.3 / 18 帧名义时长）
	assert_float(Engine.time_scale).is_equal(GameConstants.PARRY_SLOWMO_SCALE)
	assert_float(_captured_scale).is_equal(GameConstants.PARRY_SLOWMO_SCALE)
	assert_int(_captured_duration).is_equal(GameConstants.PARRY_SLOWMO_FRAMES)
	# 收尾复原（避免污染后续测试 / 拖慢编辑器）
	pc.end_time_dilation()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_parry_not_armed_rejects_perfect_parry() -> void:
	var pc := _make()
	pc.input_parry()
	assert_bool(pc.current_state_name() == &"Parry").is_true()
	# 推进越过 PARRY_WINDOW 使 parry_armed_left 归零（仍处 Parry 态，只是不再 armed）
	for i in range(GameConstants.PARRY_WINDOW + 1):
		pc.physics_tick(0.0)
	var ps := pc.state_machine.current_state as ParryState
	assert_bool(ps.is_armed()).is_false()
	var before := ResonancePool.current
	var ok := pc.parry_incoming(null)
	assert_bool(ok).is_false()
	assert_int(ResonancePool.current).is_equal(before)   # 无共鸣增益
	assert_int(_captured_stagger_frames).is_equal(-1)     # 无破防信号
	assert_float(Engine.time_scale).is_equal(1.0)         # 无慢动作


func test_perfect_parry_requires_parry_state() -> void:
	var pc := _make()
	pc.input_slash()
	assert_bool(pc.current_state_name() == &"Slash").is_true()
	var before := ResonancePool.current
	var ok := pc.parry_incoming(null)
	assert_bool(ok).is_false()
	assert_int(ResonancePool.current).is_equal(before)
