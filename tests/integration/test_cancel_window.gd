extends GdUnitTestSuite
## ENG-S1-02 · FSM 动词态与取消窗集成测试。
##
## 覆盖 epic-s1-combat ENG-S1-02 四条出口 + AC-S1-01（任意两动词取消延迟 ≤8 帧）
## + AC-S2-03（跃→闪→斩 ≤8 帧）。
##
## 这些断言是 P1「流动即正义」的**可执行形式**：手感是主观的，但「第 8 帧能接、第 9 帧不能接」
## 是客观的。SPIKE-3 若把窗口调窄，本文件会立刻变红——调参的代价因此始终可见。
##
## 全部转移经**同一个** `try_transition()`；全部取消判定经**同一个** `State.is_cancellable()`。
## 测试刻意不实例化 Player 场景：FSM 是纯逻辑，若跑它需要一整个场景，说明耦合已经出问题了。

var _combat: PlayerCombat = null
var _entered: Array[StringName] = []


func before_test() -> void:
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)
	_entered = []
	EventBus.player_state_entered.connect(_on_player_state_entered)
	_combat = auto_free(PlayerCombat.new()) as PlayerCombat
	_combat.initialize()


func after_test() -> void:
	if EventBus.player_state_entered.is_connected(_on_player_state_entered):
		EventBus.player_state_entered.disconnect(_on_player_state_entered)
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)


# =========================================================================
# 出口 1 · 状态集：idle → {slash, dash, grapple, leap, parry, resonate}
# =========================================================================

func test_initial_state_is_idle() -> void:
	assert_str(String(_combat.current_state_name())).is_equal("Idle")


func test_all_verb_states_assembled() -> void:
	# 名字即闭集契约：node.name == player_state_entered 的取值（architecture §4.4）。
	var expected: Array[StringName] = [
		&"Idle", &"Slash", &"Dash", &"Grapple", &"Leap", &"Parry", &"Resonate", &"Hitstun",
	]
	for state_name: StringName in expected:
		assert_object(_combat.state_machine.get_state(state_name)).is_not_null()


func test_no_numbered_slash_states() -> void:
	# ADR-003 §1：连段由 combo:int 驱动。Slash1..Slash4 **不得存在**，
	# 否则「4 段连段」会从一个整数退化成 4 份重复的取消窗实现。
	for suffix: int in range(1, SlashState.MAX_COMBO + 1):
		var forbidden := StringName("Slash%d" % suffix)
		assert_object(_combat.state_machine.get_state(forbidden)).is_null()


func test_idle_to_slash_transition_succeeds() -> void:
	assert_bool(_combat.state_machine.try_transition(&"Slash")).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Slash")


# =========================================================================
# 出口 2 · 取消窗 = CANCEL_WINDOW(8) 帧，经 State.is_cancellable() 单点判定
# =========================================================================

func test_slash_not_cancellable_on_entry_frame() -> void:
	# 第 0 帧（起手同帧）不开窗：零帧取消等于没有起手承诺。
	_combat.input_slash()
	assert_bool(_current_state().is_cancellable()).is_false()


func test_slash_cancellable_within_cancel_window() -> void:
	_combat.input_slash()
	for frame: int in range(1, GameConstants.CANCEL_WINDOW + 1):
		_advance(1)
		# frame 变量参与断言：窗内每一帧都必须为 true，任何一帧漏掉都会在此处红。
		assert_int(frame).is_less_equal(GameConstants.CANCEL_WINDOW)
		assert_bool(_current_state().is_cancellable()).is_true()


func test_slash_not_cancellable_from_frame_nine() -> void:
	_combat.input_slash()
	_advance(GameConstants.CANCEL_WINDOW + 1)   # 第 9 帧
	assert_bool(_current_state().is_cancellable()).is_false()


func test_cancel_window_width_equals_constant() -> void:
	# 窗宽不是「大约 8 帧」，是恰好 CANCEL_WINDOW 帧。改常量则本断言自动跟随。
	_combat.input_slash()
	var open_frames: int = 0
	for _i: int in SlashState.TOTAL_FRAMES:
		_advance(1)
		if _combat.state_machine.current_state_name != &"Slash":
			break
		if _current_state().is_cancellable():
			open_frames += 1
	assert_int(open_frames).is_equal(GameConstants.CANCEL_WINDOW)


# =========================================================================
# 出口 4 · 闪取消斩收招 / 跃取消闪 / 格接斩反击 —— 全部经同一 try_transition()
# =========================================================================

func test_dash_cancels_slash_recovery() -> void:
	_combat.input_slash()
	_advance(1)
	assert_bool(_combat.input_dash()).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Dash")


func test_leap_cancels_into_dash() -> void:
	assert_bool(_combat.input_leap()).is_true()
	_advance(1)
	assert_bool(_combat.input_dash()).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Dash")


func test_leap_dash_slash_chain() -> void:
	# AC-S2-03：跃→闪→斩，每一跳都落在 ≤8 帧的取消窗内。
	assert_bool(_combat.input_leap()).is_true()
	_advance(GameConstants.CANCEL_WINDOW)
	assert_bool(_combat.input_dash()).is_true()
	_advance(GameConstants.CANCEL_WINDOW)
	assert_bool(_combat.input_slash()).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Slash")


func test_parry_into_slash_counter() -> void:
	assert_bool(_combat.input_parry()).is_true()
	_advance(1)
	assert_bool(_combat.input_slash()).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Slash")


func test_transition_rejected_outside_cancel_window() -> void:
	# 窗外必须**拒绝**且不改状态——否则取消窗就只是个装饰。
	_combat.input_slash()
	_advance(GameConstants.CANCEL_WINDOW + 1)
	assert_bool(_combat.input_dash()).is_false()
	assert_str(String(_combat.current_state_name())).is_equal("Slash")


func test_dash_iframes_use_integer_frames() -> void:
	# ADR-003 §3：无敌帧是字面 10 次 tick，不是 0.167 秒。
	_combat.input_dash()
	var dash := _current_state() as DashState
	assert_int(dash.iframes_left).is_equal(GameConstants.DASH_IFRAMES)
	_advance(GameConstants.DASH_IFRAMES)
	assert_bool(dash.is_invulnerable()).is_false()


# =========================================================================
# 出口 3 · 整数 tick 计时，确定性（与 delta 取值无关）
# =========================================================================

func test_cancel_profile_is_delta_independent() -> void:
	# 同一序列在 60Hz 与 30Hz 的 delta 下必须给出**逐帧相同**的可取消序列。
	# 若哪天有人把窗口改成秒累加，这条会第一个红。
	var at_60 := _sample_cancel_profile(1.0 / float(GameConstants.TICKS_PER_SECOND))
	var at_30 := _sample_cancel_profile(1.0 / 30.0)
	assert_str(str(at_60)).is_equal(str(at_30))


# =========================================================================
# hitstun · 拒绝非受击类转移（architecture §5.3 流 B）
# =========================================================================

func test_hitstun_entered_on_hit() -> void:
	_combat.take_hit(GameConstants.HITSTUN_MAX_FRAMES)
	assert_str(String(_combat.current_state_name())).is_equal("Hitstun")


func test_hitstun_rejects_non_hitstun_transition() -> void:
	_combat.take_hit(GameConstants.HITSTUN_MAX_FRAMES)
	assert_bool(_combat.state_machine.try_transition(&"Slash")).is_false()
	assert_bool(_combat.input_dash()).is_false()
	assert_str(String(_combat.current_state_name())).is_equal("Hitstun")


func test_hitstun_expires_back_to_idle() -> void:
	# 上限 30 帧防卡死：硬直到点必须自己走掉，不能等玩家输入来解锁。
	_combat.take_hit(GameConstants.HITSTUN_MAX_FRAMES)
	_advance(GameConstants.HITSTUN_MAX_FRAMES)
	assert_int(_combat.state_machine.hitstun_frames_left()).is_equal(0)
	assert_str(String(_combat.current_state_name())).is_equal("Idle")


func test_short_hitstun_does_not_leave_dead_frames() -> void:
	# 轻击硬直 < 上限时，状态时长必须跟着缩短，否则会出现「硬直已解除但态还锁着」的哑帧。
	var short_frames: int = GameConstants.HITSTUN_MAX_FRAMES / 3
	_combat.take_hit(short_frames)
	_advance(short_frames)
	assert_str(String(_combat.current_state_name())).is_equal("Idle")


# =========================================================================
# 终结技 · 池门槛（ADR-003 §4 第 3 步 / AC-S1-04 的 FSM 侧）
# =========================================================================

func test_resonate_locked_when_pool_insufficient() -> void:
	ResonancePool.reset_for_test(GameConstants.FINISHER_COST - 1)   # 39
	assert_bool(_combat.input_resonate()).is_false()
	assert_str(String(_combat.current_state_name())).is_equal("Idle")
	assert_int(ResonancePool.current).is_equal(GameConstants.FINISHER_COST - 1)  # 分文未扣


func test_resonate_spends_pool_on_enter() -> void:
	ResonancePool.reset_for_test(GameConstants.FINISHER_COST)       # 40
	assert_bool(_combat.input_resonate()).is_true()
	assert_str(String(_combat.current_state_name())).is_equal("Resonate")
	assert_int(ResonancePool.current).is_equal(0)


func test_resonate_is_not_cancellable() -> void:
	# 终结技付了 40 点代价，不能被一个闪逃课掉。
	ResonancePool.reset_for_test(GameConstants.FINISHER_COST)
	_combat.input_resonate()
	for _i: int in GameConstants.CANCEL_WINDOW + 1:
		_advance(1)
		assert_bool(_combat.input_dash()).is_false()
	assert_str(String(_combat.current_state_name())).is_equal("Resonate")


# =========================================================================
# 广播 · player_state_entered 取值落在闭集内（EventBus 契约）
# =========================================================================

func test_player_state_entered_broadcast() -> void:
	var closed_set: Array[StringName] = [
		&"Idle", &"Slash", &"SlashHeavy", &"Dash", &"Grapple",
		&"Leap", &"Parry", &"Resonate", &"Hitstun",
	]
	_entered = []
	_combat.input_slash()
	_advance(1)
	_combat.input_dash()
	assert_int(_entered.size()).is_equal(2)
	for state_name: StringName in _entered:
		assert_bool(closed_set.has(state_name)).is_true()
	assert_str(String(_entered[0])).is_equal("Slash")
	assert_str(String(_entered[1])).is_equal("Dash")


# =========================================================================
# 辅助
# =========================================================================

func _on_player_state_entered(state_name: StringName) -> void:
	_entered.append(state_name)


func _current_state() -> State:
	return _combat.state_machine.current_state


func _advance(frames: int) -> void:
	var delta: float = 1.0 / float(GameConstants.TICKS_PER_SECOND)
	for _i: int in frames:
		_combat.physics_tick(delta)


## 采样一次「斩态逐帧是否可取消」的序列，用给定 delta 驱动。
func _sample_cancel_profile(delta: float) -> Array[bool]:
	var probe: PlayerCombat = auto_free(PlayerCombat.new()) as PlayerCombat
	probe.initialize()
	probe.input_slash()
	var profile: Array[bool] = []
	for _i: int in GameConstants.CANCEL_WINDOW + 4:
		probe.physics_tick(delta)
		var state := probe.state_machine.current_state
		profile.append(state.is_cancellable())
	return profile
