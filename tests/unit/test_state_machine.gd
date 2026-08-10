extends GdUnitTestSuite
## 回归测试 · StateMachine 硬直期转移裁决（state_machine.gd §can_enter / enter_hitstun）。
##
## 修复前 can_enter() 在 _hitstun_frames_left>0 时对「任意」目标返回 false，连 Hitstun 自身都拦，
## 导致 enter_hitstun() 永远进不去 Hitstun 态（与自身注释「Hitstun 自身除外」矛盾）。
## 本测试锁定该行为：硬直期放行 Hitstun、拒绝其余转移。
##
## 针对**基座** StateMachine（S4 敌人 FSM 直接复用基类时须行为正确；战斗 FSM 已自行覆写等价裁决）。

func _make_machine() -> StateMachine:
	var sm := StateMachine.new()
	add_child(sm)
	var idle := State.new(); idle.name = "Idle"; sm.add_child(idle)
	var hitstun := State.new(); hitstun.name = "Hitstun"; sm.add_child(hitstun)
	var slash := State.new(); slash.name = "Slash"; sm.add_child(slash)
	sm.enter_initial(idle)
	return sm


func test_hitstun_allows_entering_hitstun_state() -> void:
	var sm := _make_machine()
	# 修复前：enter_hitstun 后 current_state_name 仍为 "Idle"（进不去 Hitstun）
	sm.enter_hitstun(10)
	assert_bool(sm.current_state_name == &"Hitstun").is_true()


func test_hitstun_rejects_non_hitstun_transition() -> void:
	var sm := _make_machine()
	sm.enter_hitstun(10)
	# 硬直期内非 Hitstun 转移必须被拒
	assert_bool(sm.try_transition(&"Slash")).is_false()
	# 仍停留在 Hitstun
	assert_bool(sm.current_state_name == &"Hitstun").is_true()
