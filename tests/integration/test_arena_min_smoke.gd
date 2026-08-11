extends GdUnitTestSuite
## 可玩构建冒烟测试：arena_min.tscn 能实例化、能跑物理帧、玩家与木桩都活着。
## 这条守的是「构建能不能开起来」——比任何单元断言都先决。
##
## 隔离：arena 的 _ready() 会调 RosterAutoload.ensure_playable()，可能给全局花名册
## 授予启动角色。本套件在前后快照 / 还原全局状态，避免污染其他用例的执行顺序假设。

var _saved_roster: Dictionary = {}
var _arena: Node3D = null


func before_test() -> void:
	_saved_roster = RosterAutoload.to_dict()
	ResonancePool.reset_for_test(0)
	InputManager.reset_for_test()


func after_test() -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	RosterAutoload.from_dict(_saved_roster)
	Engine.time_scale = 1.0


func _boot_arena() -> Node3D:
	var packed := load("res://game/scenes/arena_min.tscn") as PackedScene
	assert_object(packed).is_not_null()
	_arena = packed.instantiate() as Node3D
	add_child(_arena)
	return _arena


func test_arena_instantiates_with_core_nodes() -> void:
	var arena := _boot_arena()
	assert_object(arena.get_node_or_null("PlayerRig")).is_not_null()
	assert_object(arena.get_node_or_null("PlayerRig/PlayerCombat")).is_not_null()
	assert_object(arena.get_node_or_null("PlayerRig/Model")).is_not_null()
	assert_object(arena.get_node_or_null("Dummy")).is_not_null()
	assert_object(arena.get_node_or_null("Camera")).is_not_null()
	assert_object(arena.get_node_or_null("HUD")).is_not_null()


func test_player_spawns_alive_with_character_stats() -> void:
	var arena := _boot_arena()
	var pc := arena.get_node("PlayerRig/PlayerCombat") as PlayerCombat
	# 空存档也必须有角色可打——ensure_playable 的兜底在此生效。
	assert_int(pc.max_hp).is_greater(0)
	assert_int(pc.hp).is_equal(pc.max_hp)
	assert_str(String(pc.current_state_name())).is_equal("Idle")


func test_dummy_spawns_with_definition_hp() -> void:
	var arena := _boot_arena()
	var dummy := arena.get_node("Dummy") as EnemyCombat
	assert_object(dummy.definition).is_not_null()
	assert_str(String(dummy.definition.enemy_id)).is_equal("dummy")
	assert_int(dummy.hp).is_equal(dummy.definition.max_hp)
	assert_int(dummy.hp).is_greater(0)
	# 训练弹 = 0 伤害，玩家可反复练格挡而不会被打死。
	assert_int(dummy.definition.attack_damage).is_equal(0)
	# telegraph 必须 > 0，否则起手不可读、格挡无从练起。
	assert_int(dummy.definition.telegraph_frames).is_greater(0)


func test_physics_frames_advance_without_error() -> void:
	var arena := _boot_arena()
	var pc := arena.get_node("PlayerRig/PlayerCombat") as PlayerCombat
	for i in range(20):
		await get_tree().physics_frame
	# 跑满 20 物理帧后玩家仍在 Idle 且满血（无输入 → 无状态迁移、无掉血）。
	assert_int(pc.hp).is_equal(pc.max_hp)
	assert_str(String(pc.current_state_name())).is_equal("Idle")


func test_dummy_telegraphs_then_attacks() -> void:
	# 木桩 Idle 满 DUMMY_ATTACK_PERIOD 秒起手；Telegraph 收尽自动转 Attack。
	# 这里不等真实 4 秒，直接踢一次转移验证 FSM 链路通。
	var arena := _boot_arena()
	var dummy := arena.get_node("Dummy") as EnemyCombat
	assert_bool(dummy.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)).is_true()
	assert_str(String(dummy.current_state_name())).is_equal("Telegraph")
	for i in range(dummy.definition.telegraph_frames + 2):
		await get_tree().physics_frame
	# telegraph 帧数走完后必然离开 Telegraph（转 Attack，随后 Recover）。
	assert_str(String(dummy.current_state_name())).is_not_equal("Telegraph")
