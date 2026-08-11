extends GdUnitTestSuite
## S9 星轨召唤 · 单测（design/gdd/systems/gacha.md）。
## 覆盖：数值公式（base×eff_mult×roll/1e6）、职阶五维和=500、基础概率大数收敛、
## SSR 硬保底(90)、SR 保底(十连)、保底复位、重复角色尘返还+重掷权、roll 永久锁定。

const N: int = GachaConstants.RARITY.N
const R: int = GachaConstants.RARITY.R
const SR: int = GachaConstants.RARITY.SR
const SSR: int = GachaConstants.RARITY.SSR


func _make_instance(def: CharacterDefinition, ra: int, rd: int, rf: int) -> CharacterInstance:
	var inst := CharacterInstance.new()
	inst.character_id = def.character_id
	inst.rarity = def.rarity
	inst.roll_atk_milli = ra
	inst.roll_def_milli = rd
	inst.roll_aff_milli = rf
	inst.final_hp = GachaEngine.compute_stat(def.base_hp, &"hp", def.rarity, 1000)
	inst.final_attack = GachaEngine.compute_stat(def.base_attack, &"attack", def.rarity, ra)
	inst.final_defense = GachaEngine.compute_stat(def.base_defense, &"defense", def.rarity, rd)
	inst.final_move_speed = GachaEngine.compute_stat(def.base_move_speed, &"move_speed", def.rarity, 1000)
	inst.final_affinity = GachaEngine.compute_stat(def.base_affinity, &"resonance_affinity", def.rarity, rf)
	return inst


# =========================================================================
# 数值公式
# =========================================================================

func test_eff_mult_milli_per_dimension() -> void:
	# SSR 乘区展开（design §3.3 表）：hp/aff ×1.60、def ×1.42、atk ×1.30、spd ×1.06
	assert_int(GachaEngine.eff_mult_milli(&"hp", SSR)).is_equal(1600)
	assert_int(GachaEngine.eff_mult_milli(&"resonance_affinity", SSR)).is_equal(1600)
	assert_int(GachaEngine.eff_mult_milli(&"defense", SSR)).is_equal(1420)
	assert_int(GachaEngine.eff_mult_milli(&"attack", SSR)).is_equal(1300)
	assert_int(GachaEngine.eff_mult_milli(&"move_speed", SSR)).is_equal(1060)
	# N 档全维 ×1.000
	assert_int(GachaEngine.eff_mult_milli(&"attack", N)).is_equal(1000)


func test_compute_stats_matches_design_example() -> void:
	# 星·断空剑主（锋刃 SSR，roll atk/def/aff = 995/1000/1000）→ design §3.6 示例
	var def := GachaCatalog.new().by_id(&"voidblade_lord")
	assert_int(GachaEngine.compute_stat(def.base_hp, &"hp", SSR, 1000)).is_equal(152)
	assert_int(GachaEngine.compute_stat(def.base_attack, &"attack", SSR, 995)).is_equal(152)
	assert_int(GachaEngine.compute_stat(def.base_defense, &"defense", SSR, 1000)).is_equal(127)
	assert_int(GachaEngine.compute_stat(def.base_move_speed, &"move_speed", SSR, 1000)).is_equal(108)
	assert_int(GachaEngine.compute_stat(def.base_affinity, &"resonance_affinity", SSR, 1000)).is_equal(152)


func test_archetype_base_sum_500() -> void:
	var cat := GachaCatalog.new()
	for d in cat.all():
		var s := d.base_hp + d.base_attack + d.base_defense + d.base_move_speed + d.base_affinity
		assert_int(s).is_equal(500)


func test_roll_is_discrete_21_levels() -> void:
	# roll 千分比 ∈ {950..1050} 步长 5（21 档），hp/spd 恒 1000。
	assert_int(GachaConstants.ROLL_STEPS).is_equal(20)
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(500):
		var v := engine._roll_milli(rng)
		assert_bool(v >= 950 and v <= 1050).is_true()
		assert_bool((v - 950) % 5 == 0).is_true()


# =========================================================================
# 概率分布与保底
# =========================================================================

func test_base_rarity_distribution_converges() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240811
	var n := 200000
	var cnt := {N: 0, R: 0, SR: 0, SSR: 0}
	for i in range(n):
		cnt[engine._base_rarity_roll(rng)] += 1
	var rate_ssr := float(cnt[SSR]) / float(n)
	var rate_sr := float(cnt[SR]) / float(n)
	var rate_r := float(cnt[R]) / float(n)
	var rate_n := float(cnt[N]) / float(n)
	# 基础概率（保底前）：SSR 2% / SR 13% / R 35% / N 50%，±1% 容差
	assert_bool(abs(rate_ssr - 0.02) < 0.01).is_true()
	assert_bool(abs(rate_sr - 0.13) < 0.01).is_true()
	assert_bool(abs(rate_r - 0.35) < 0.01).is_true()
	assert_bool(abs(rate_n - 0.50) < 0.01).is_true()


func test_ssr_rate_at_hard_pity_is_guaranteed() -> void:
	assert_int(GachaEngine._ssr_rate_milli(90)).is_equal(10000)
	assert_int(GachaEngine._ssr_rate_milli(74)).is_equal(2500)  # 基础2000 + 1×500


func test_hard_pity_at_90_always_ssr() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(100):
		engine.roster.pity_ssr = 90  # 强制硬保底
		var r := engine._roll_rarity(rng)
		assert_int(r).is_equal(SSR)


func test_sr_pity_at_10_forces_sr_plus() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(100):
		engine.roster.pity_sr = 9  # 距 SR 保底还差 1 抽
		var r := engine._roll_rarity(rng)
		assert_bool(r >= SR).is_true()  # 必为 SR 或 SSR


func test_pity_resets_on_ssr() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	engine.roster.pity_ssr = 90
	var r := engine._roll_rarity(rng)
	assert_int(r).is_equal(SSR)
	assert_int(engine.roster.pity_ssr).is_equal(0)
	assert_int(engine.roster.pity_sr).is_equal(0)


func test_ten_pull_always_yields_sr_plus() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	for batch in range(100):
		var pulls := engine.try_pull_ten(rng)
		var has_sr_plus := false
		for p in pulls:
			if p.rarity >= SR:
				has_sr_plus = true
		assert_bool(has_sr_plus).is_true()


# =========================================================================
# 抽取产物 / 重复 / 锁定
# =========================================================================

func test_try_pull_yields_valid_instance() -> void:
	var engine := GachaEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var inst := engine.try_pull(rng)
	assert_object(inst).is_not_null()
	var def := engine.catalog.by_id(inst.character_id)
	assert_object(def).is_not_null()
	assert_int(inst.final_attack).is_equal(
		GachaEngine.compute_stat(def.base_attack, &"attack", inst.rarity, inst.roll_atk_milli))
	assert_bool(inst.final_hp > 0).is_true()
	assert_bool(engine.roster.is_owned(inst.character_id)).is_true()


func test_duplicate_gives_dust_and_reroll() -> void:
	var engine := GachaEngine.new()
	var def := engine.catalog.by_id(&"ash_acolyte")
	var a := _make_instance(def, 1000, 1000, 1000)
	var b := _make_instance(def, 1050, 1050, 1050)
	engine.roster.record_pull(a)
	assert_bool(a.is_duplicate).is_false()
	engine.roster.record_pull(b)
	assert_bool(b.is_duplicate).is_true()
	assert_int(engine.roster.dust).is_equal(GachaConstants.DUST_PER_DUPLICATE)
	assert_int(engine.roster.reroll_tokens).is_equal(1)
	assert_int(int(engine.roster.duplicates.get(&"ash_acolyte", 0))).is_equal(1)


func test_roll_locked_via_dict_roundtrip() -> void:
	var def := GachaCatalog.new().by_id(&"voidblade_lord")
	var inst := _make_instance(def, 995, 1000, 1000)
	var back := CharacterInstance.from_dict(inst.to_dict())
	assert_int(back.roll_atk_milli).is_equal(inst.roll_atk_milli)
	assert_int(back.rarity).is_equal(inst.rarity)
	assert_bool(back.is_duplicate).is_equal(inst.is_duplicate)
