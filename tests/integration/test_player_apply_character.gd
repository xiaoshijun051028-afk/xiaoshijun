extends GdUnitTestSuite
## S9 集成 · 出战角色数值注入 PlayerCombat（AC-GACHA 出战契约）。
## 验证 apply_character_stats 注入 final 五维，且 defense 接入 take_damage 减伤。

func _make_inst() -> CharacterInstance:
	var inst := CharacterInstance.new()
	inst.character_id = &"test_char"
	inst.final_hp = 150
	inst.final_attack = 120
	inst.final_defense = 80
	inst.final_move_speed = 110
	inst.final_affinity = 130
	return inst


func _make_pc() -> PlayerCombat:
	var pc := PlayerCombat.new()
	pc.initialize()
	add_child(pc)
	return pc


func test_apply_sets_stats_and_full_hp() -> void:
	var pc := _make_pc()
	var inst := _make_inst()
	pc.apply_character_stats(inst)
	assert_int(pc.max_hp).is_equal(150)
	assert_int(pc.hp).is_equal(150)
	assert_int(pc.attack_power).is_equal(120)
	assert_int(pc.defense).is_equal(80)
	assert_float(pc.move_speed).is_equal(110.0)
	assert_int(pc.resonance_affinity).is_equal(130)


func test_null_inst_is_noop() -> void:
	var pc := _make_pc()
	var before_hp := pc.max_hp
	pc.apply_character_stats(null)
	assert_int(pc.max_hp).is_equal(before_hp)


## defense=80 → dealt = max(1, 100*100/80) = 125（防御低于基准 → 受伤加重，符合「防御有意义」）。
func test_defense_low_increases_damage() -> void:
	var pc := _make_pc()
	pc.apply_character_stats(_make_inst())   # defense=80
	var dealt := pc.take_damage(100)
	assert_int(dealt).is_equal(125)


## defense=200 → dealt = 100*100/200 = 50（高防御减伤）。
func test_defense_high_mitigates() -> void:
	var pc := _make_pc()
	var inst := _make_inst()
	inst.final_defense = 200
	pc.apply_character_stats(inst)
	var dealt := pc.take_damage(100)
	assert_int(dealt).is_equal(50)


## 未注入（默认 defense=100）→ 伤害不变（向后兼容 S1）。
func test_default_defense_passthrough() -> void:
	var pc := _make_pc()
	var dealt := pc.take_damage(100)
	assert_int(dealt).is_equal(100)
