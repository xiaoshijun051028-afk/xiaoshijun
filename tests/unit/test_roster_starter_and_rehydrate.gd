extends GdUnitTestSuite
## S9 存档回读修复 + 「任何人都能玩」启动保障。
##
## 背景（真实 bug）：CharacterInstance.to_dict() 刻意只存 id + 锁定的 roll，**不存** final_*，
## 因为 final_* = f(常量基线, roll) 是派生量——入档就成了第二个真相源，改一次基线全档漂移。
## 但 from_dict() 原先没有反向补齐，导致读档后 final_hp 停在默认 0 →
## apply_character_stats() 把玩家 max_hp/hp 设成 0 → **一进场就暴毙**。
## 本套件把「读档后 final_* 必须与存档前一致」钉死。
##
## 另验证 grant()/ensure_playable()：赠送角色绝不能污染保底与货币（那只应由真实抽取驱动）。

var _svc: RosterService


func before_test() -> void:
	_svc = RosterService.new()


# =========================================================================
# 读档补齐（回归守卫）
# =========================================================================

func test_from_dict_rehydrates_final_stats() -> void:
	var origin := _svc.grant(&"voidblade_lord")
	assert_object(origin).is_not_null()
	assert_int(origin.final_hp).is_greater(0)
	_svc.set_active(&"voidblade_lord")
	var saved := _svc.to_dict()

	var loaded := RosterService.new()
	loaded.from_dict(saved)
	var back := loaded.get_active()
	assert_object(back).is_not_null()
	# 派生五维必须与存档前逐项一致——任一项为 0 即代表补齐漏了。
	assert_int(back.final_hp).is_equal(origin.final_hp)
	assert_int(back.final_attack).is_equal(origin.final_attack)
	assert_int(back.final_defense).is_equal(origin.final_defense)
	assert_int(back.final_move_speed).is_equal(origin.final_move_speed)
	assert_int(back.final_affinity).is_equal(origin.final_affinity)
	assert_str(back.display_name).is_not_empty()


func test_rehydrate_preserves_locked_rolls() -> void:
	# roll 是抽出瞬间永久锁定的，读档补齐只能「用它算」，绝不能重掷。
	var inst := _svc.pull(null)
	_svc.set_active(inst.character_id)
	var atk_roll := inst.roll_atk_milli
	var def_roll := inst.roll_def_milli
	var aff_roll := inst.roll_aff_milli

	var loaded := RosterService.new()
	loaded.from_dict(_svc.to_dict())
	var back := loaded.get_active()
	assert_int(back.roll_atk_milli).is_equal(atk_roll)
	assert_int(back.roll_def_milli).is_equal(def_roll)
	assert_int(back.roll_aff_milli).is_equal(aff_roll)


func test_loaded_character_never_zero_hp() -> void:
	# 本条是那个 bug 的直接反面断言：读档角色注入 PlayerCombat 后不得 0 血。
	_svc.grant(&"ash_acolyte")
	_svc.set_active(&"ash_acolyte")
	var loaded := RosterService.new()
	loaded.from_dict(_svc.to_dict())

	var pc := PlayerCombat.new()
	pc.initialize()
	pc.apply_character_stats(loaded.get_active())
	add_child(pc)
	assert_int(pc.max_hp).is_greater(0)
	assert_int(pc.hp).is_equal(pc.max_hp)


func test_dangling_active_id_is_dropped() -> void:
	# 档里的出战 id 若已不在花名册（目录改版 / 档损），必须降级为未选，不留悬空引用。
	var loaded := RosterService.new()
	loaded.from_dict({"owned": [], "active_character_id": "no_such_character"})
	assert_str(String(loaded.active_character_id)).is_empty()
	assert_object(loaded.get_active()).is_null()


# =========================================================================
# grant / ensure_playable
# =========================================================================

func test_grant_does_not_touch_pity_or_currency() -> void:
	_svc.grant(RosterService.STARTER_ID)
	assert_int(_svc.owned_count()).is_equal(1)
	assert_int(_svc.pity_ssr()).is_equal(0)
	assert_int(_svc.dust()).is_equal(0)
	assert_int(_svc.engine.roster.pity_sr).is_equal(0)
	assert_int(_svc.engine.roster.reroll_tokens).is_equal(0)


func test_grant_is_idempotent_and_never_overwrites() -> void:
	var first := _svc.grant(RosterService.STARTER_ID)
	var second := _svc.grant(RosterService.STARTER_ID)
	assert_object(second).is_same(first)
	assert_int(_svc.owned_count()).is_equal(1)
	# 重复赠送不得计入重复计数 / 返尘（那是抽卡语义）。
	assert_int(_svc.dust()).is_equal(0)


func test_grant_unknown_id_returns_null() -> void:
	assert_object(_svc.grant(&"not_a_character")).is_null()
	assert_int(_svc.owned_count()).is_equal(0)


func test_ensure_playable_on_empty_save_grants_starter() -> void:
	var inst := _svc.ensure_playable()
	assert_object(inst).is_not_null()
	assert_str(String(inst.character_id)).is_equal(String(RosterService.STARTER_ID))
	assert_str(String(_svc.active_character_id)).is_equal(String(RosterService.STARTER_ID))
	assert_int(inst.final_hp).is_greater(0)


func test_ensure_playable_picks_highest_rarity_when_unset() -> void:
	_svc.grant(&"ash_acolyte")           # N
	_svc.grant(&"voidblade_lord")        # SSR
	_svc.active_character_id = &""
	var inst := _svc.ensure_playable()
	assert_str(String(inst.character_id)).is_equal("voidblade_lord")


func test_ensure_playable_keeps_existing_active() -> void:
	_svc.grant(&"ash_acolyte")
	_svc.grant(&"voidblade_lord")
	_svc.set_active(&"ash_acolyte")
	var inst := _svc.ensure_playable()
	# 已有出战选择不得被「自动挑最高稀有度」覆盖——那是玩家的决定。
	assert_str(String(inst.character_id)).is_equal("ash_acolyte")
