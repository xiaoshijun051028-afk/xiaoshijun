extends GdUnitTestSuite
## EventBus 契约 · 信号总数 = 27（architecture §5.2 注释），且关键信号均存在。
##
## EventBus 是「纯信号容器、无状态无逻辑」（control-checklist §D #2）。
## 信号数量与命名是跨系统广播的稳定契约，增删信号必须同步本测试。

const EXPECTED_SIGNALS: Array[String] = [
	"resonance_changed", "resonance_spend_rejected", "resonance_node_consumed",
	"player_hp_changed", "player_state_entered", "combo_advanced", "perfect_parry_landed",
	"finisher_executed", "combat_state_changed",
	"enemy_telegraph_started", "enemy_telegraph_cleared", "enemy_staggered",
	"enemy_died", "boss_phase_changed",
	"gate_opened", "shrine_activated", "player_respawned", "island_entered",
	"echo_triggered", "echo_finished", "echo_collected",
	"save_completed", "settings_changed", "game_paused", "game_resumed",
	"time_dilation_started", "time_dilation_ended",
]


func test_signal_count_is_27() -> void:
	var declared := 0
	for s: Dictionary in EventBus.get_signal_list():
		if EXPECTED_SIGNALS.has(s["name"]):
			declared += 1
	assert_int(declared).is_equal(27)


func test_key_signals_present() -> void:
	var names := {}
	for s: Dictionary in EventBus.get_signal_list():
		names[s["name"]] = true
	for required: String in EXPECTED_SIGNALS:
		assert_bool(names.has(required)).is_true()
