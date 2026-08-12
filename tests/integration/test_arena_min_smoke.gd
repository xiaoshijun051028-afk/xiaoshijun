extends GdUnitTestSuite
## 可玩构建冒烟测试：arena_min.tscn 能实例化、能跑物理帧、玩家与真敌人波次都活着。
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


func _first_enemy() -> EnemyCombat:
	for e in _arena.get_children():
		if e is EnemyCombat:
			return e as EnemyCombat
	return null


func test_arena_instantiates_with_core_nodes() -> void:
	var arena := _boot_arena()
	assert_object(arena.get_node_or_null("PlayerRig")).is_not_null()
	assert_object(arena.get_node_or_null("PlayerRig/PlayerCombat")).is_not_null()
	assert_object(arena.get_node_or_null("PlayerRig/Model")).is_not_null()
	assert_object(arena.get_node_or_null("Camera")).is_not_null()
	assert_object(arena.get_node_or_null("HUD")).is_not_null()
	# 进场即刷出真敌人波次（不再有训练木桩）。
	assert_int(arena.debug_enemy_count()).is_greater_equal(1)


func test_player_spawns_alive_with_character_stats() -> void:
	var arena := _boot_arena()
	var pc := arena.get_node("PlayerRig/PlayerCombat") as PlayerCombat
	# 空存档也必须有角色可打——ensure_playable 的兜底在此生效。
	assert_int(pc.max_hp).is_greater(0)
	assert_int(pc.hp).is_equal(pc.max_hp)
	assert_str(String(pc.current_state_name())).is_equal("Idle")


func test_wave_spawns_real_enemies() -> void:
	var arena := _boot_arena()
	assert_int(arena.debug_enemy_count()).is_greater_equal(1)
	# 真敌人 attack_damage > 0（训练木桩才是 0），会真正掉血。
	var found_real := false
	for e in arena.get_children():
		if e is EnemyCombat and e.definition != null:
			if e.definition.attack_damage > 0:
				found_real = true
	assert_bool(found_real).is_true()


func test_physics_frames_advance_without_error() -> void:
	var arena := _boot_arena()
	var pc := arena.get_node("PlayerRig/PlayerCombat") as PlayerCombat
	for i in range(20):
		await get_tree().physics_frame
	# 跑满 20 物理帧后玩家仍在 Idle 且满血（无输入 → 无状态迁移、无掉血）。
	assert_int(pc.hp).is_equal(pc.max_hp)
	assert_str(String(pc.current_state_name())).is_equal("Idle")


func test_enemy_telegraphs_then_attacks() -> void:
	# 敌人 Idle 满 ENEMY_ATTACK_PERIOD 秒起手；Telegraph 收尽自动转 Attack。
	# 这里不等真实周期，直接踢一次转移验证 FSM 链路通。
	var arena := _boot_arena()
	var enemy := _first_enemy()
	assert_object(enemy).is_not_null()
	assert_bool(enemy.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Telegraph")
	for i in range(enemy.definition.telegraph_frames + 2):
		await get_tree().physics_frame
	# telegraph 帧数走完后必然离开 Telegraph（转 Attack，随后 Recover）。
	assert_str(String(enemy.current_state_name())).is_not_equal("Telegraph")
