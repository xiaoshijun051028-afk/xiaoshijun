extends GdUnitTestSuite
## S0 硬门禁 · 常量一致性（test_constants_match_gdd）
##
## 架构承重墙：把「文档一致性」变成可执行门禁。两道边一起守：
##   1) systems-index §2 的全部常量被直接断言（改 GDD 必须同步此处，否则 CI 红）；
##   2) ConstantsResource（.tres 承载类）与 GameConstants autoload 逐字段比对，
##      守「.tres ↔ const」双真相源边（architecture §4.2 / ConstantsResource 注释）。
##
## 任何一处漂移 → 本测试红 → 强制走「先改 GDD → 改 game_constants.gd → 同步 .tres」流程。

func test_gdd_frame_baseline_constants() -> void:
	assert_int(GameConstants.CANCEL_WINDOW).is_equal(8)
	assert_int(GameConstants.PARRY_WINDOW).is_equal(6)
	assert_int(GameConstants.DASH_IFRAMES).is_equal(10)
	assert_int(GameConstants.CANCEL_WINDOW_MIN).is_equal(5)
	assert_int(GameConstants.CANCEL_WINDOW_ASSIST).is_equal(10)


func test_gdd_resonance_constants() -> void:
	assert_int(GameConstants.RESONANCE_MAX).is_equal(100)
	assert_int(GameConstants.RESONANCE_INITIAL).is_equal(50)
	assert_int(GameConstants.GATE_COST).is_equal(30)
	assert_int(GameConstants.FINISHER_COST).is_equal(40)
	assert_int(GameConstants.GAIN_HIT).is_equal(1)
	assert_int(GameConstants.GAIN_PERFECT_PARRY).is_equal(5)
	assert_int(GameConstants.GAIN_KILL).is_equal(15)
	assert_int(GameConstants.GAIN_NODE).is_equal(10)
	assert_int(GameConstants.GAIN_OUT_OF_COMBAT_PER_SEC).is_equal(2)
	assert_int(GameConstants.NODE_COOLDOWN_FRAMES).is_equal(300)
	assert_int(GameConstants.OUT_OF_COMBAT_FRAMES).is_equal(180)


func test_gdd_slowmo_constants_and_finisher_has_no_slowmo() -> void:
	# 慢动作仅归属完美格挡（AUD-1 / systems-index §2）。
	assert_int(GameConstants.PARRY_SLOWMO_FRAMES).is_equal(18)
	# 2 参显式写法：Godot 4.7-stable 与 4.7.1 均支持（单参便利写法为 4.7.1-only）。
	assert_float(GameConstants.PARRY_SLOWMO_SCALE).is_equal_approx(0.3, 0.0001)
	# 终极度不能引入慢动作：测试断言这两个名字不存在即"设计决策焊死"。
	# GameConstants 已用 FINISHER_USES_SLOWMO=false 表达该决策。
	assert_bool(GameConstants.FINISHER_USES_SLOWMO).is_false()


func test_tres_mirror_matches_autoload() -> void:
	var cr := ConstantsResource.new()
	var mismatches := cr.diff_against_autoload(GameConstants)
	assert_array(mismatches).is_empty()
