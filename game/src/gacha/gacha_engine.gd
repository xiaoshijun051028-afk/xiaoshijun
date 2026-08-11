class_name GachaEngine
extends RefCounted
## 星轨召唤引擎（S9 / design/gdd/systems/gacha.md）。
## 职责：稀有度抽取（含双保底）、roll 生成与锁定、最终数值计算、十连、花名册记录。
## 数值全整数（千分比），无浮点漂移；try_pull 支持 RNG 注入（可复现测试）。

var catalog: GachaCatalog = GachaCatalog.new()
var roster: Roster = Roster.new()


# =========================================================================
# 纯数值（无状态、确定性、可单测）
# =========================================================================

## 维度有效乘区（千分比）：eff = 1000 + (rarity_mult - 1000) × weight / 1000。
static func eff_mult_milli(stat: StringName, rarity: int) -> int:
	var rm: int = GachaConstants.RARITY_MULT_MILLI[rarity]
	var w: int = GachaConstants.WEIGHT_MILLI[stat]
	return 1000 + (rm - 1000) * w / 1000


## 单维最终值：base × eff_mult × roll / 1e6（整数除法，先乘后除）。
static func compute_stat(base: int, stat: StringName, rarity: int, roll_milli: int) -> int:
	return base * eff_mult_milli(stat, rarity) * roll_milli / 1000000


# =========================================================================
# 稀有度抽取
# =========================================================================

## 基础稀有度 roll（保底前，纯按 BASE_RATE_MILLI 分布）。供大数收敛测试。
func _base_rarity_roll(rng: RandomNumberGenerator) -> int:
	var r := rng.randi_range(0, 99999)
	if r < GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SSR]:
		return GachaConstants.RARITY.SSR
	r -= GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SSR]
	if r < GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SR]:
		return GachaConstants.RARITY.SR
	r -= GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SR]
	if r < GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.R]:
		return GachaConstants.RARITY.R
	return GachaConstants.RARITY.N


## SSR 保底概率（千分比）：<SOFT 用基础率；[SOFT,HARD) 线性爬升；≥HARD 必出(10000)。
static func _ssr_rate_milli(pity: int) -> int:
	if pity >= GachaConstants.PITY_SSR_HARD:
		return 10000
	if pity < GachaConstants.PITY_SSR_SOFT:
		return GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SSR]
	var v := GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SSR] \
		+ (pity - GachaConstants.PITY_SSR_SOFT + 1) * GachaConstants.SSR_PITY_STEP_MILLI
	return clampi(v, 0, 10000)


## 含保底的稀有度抽取（更新 roster 双保底计数器）。
func _roll_rarity(rng: RandomNumberGenerator) -> int:
	# 1) SSR 保底判定
	var ssr_rate := _ssr_rate_milli(roster.pity_ssr)
	if rng.randi_range(0, 9999) < ssr_rate:
		roster.pity_ssr = 0
		roster.pity_sr = 0
		return GachaConstants.RARITY.SSR
	# 2) 其余档（排除 SSR 后归一化）抽 SR / R / N
	var rest := 100000 - GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SSR]
	var sr_rate := GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.SR] * 10000 / rest
	var rarity := GachaConstants.RARITY.N
	if rng.randi_range(0, 9999) < sr_rate:
		rarity = GachaConstants.RARITY.SR
	else:
		var r_rate := GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.R] * 10000 \
			/ (GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.R] + GachaConstants.BASE_RATE_MILLI[GachaConstants.RARITY.N])
		if rng.randi_range(0, 9999) < r_rate:
			rarity = GachaConstants.RARITY.R
	# 3) SR 保底：连续未出 SR/SSR 达 9 抽 → 本抽强制 SR
	if rarity != GachaConstants.RARITY.SSR and roster.pity_sr >= GachaConstants.PITY_SR_HARD - 1:
		rarity = GachaConstants.RARITY.SR
	# 4) 更新计数器
	if rarity == GachaConstants.RARITY.SR or rarity == GachaConstants.RARITY.SSR:
		roster.pity_sr = 0
	else:
		roster.pity_sr += 1
	if rarity == GachaConstants.RARITY.SSR:
		roster.pity_ssr = 0
	else:
		roster.pity_ssr += 1
	return rarity


## 单抽一次。rng 为 null 时新建随机源（不可复现）；注入 rng 用于测试。
func try_pull(rng: RandomNumberGenerator = null) -> CharacterInstance:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var rarity := _roll_rarity(rng)
	var pool := catalog.of_rarity(rarity)
	var def := pool[rng.randi_range(0, pool.size() - 1)] as CharacterDefinition
	var roll_atk := _roll_milli(rng)
	var roll_def := _roll_milli(rng)
	var roll_aff := _roll_milli(rng)
	var inst := CharacterInstance.new()
	inst.character_id = def.character_id
	inst.display_name = def.display_name
	inst.archetype = def.archetype
	inst.rarity = def.rarity
	inst.roll_atk_milli = roll_atk
	inst.roll_def_milli = roll_def
	inst.roll_aff_milli = roll_aff
	# hp / move_speed 不 roll（roll_milli=1000）
	inst.final_hp = compute_stat(def.base_hp, &"hp", rarity, 1000)
	inst.final_attack = compute_stat(def.base_attack, &"attack", rarity, roll_atk)
	inst.final_defense = compute_stat(def.base_defense, &"defense", rarity, roll_def)
	inst.final_move_speed = compute_stat(def.base_move_speed, &"move_speed", rarity, 1000)
	inst.final_affinity = compute_stat(def.base_affinity, &"resonance_affinity", rarity, roll_aff)
	roster.record_pull(inst)
	return inst


## 副属性 roll（千分比，[950,1050] 步长 5，21 档）。
func _roll_milli(rng: RandomNumberGenerator) -> int:
	return GachaConstants.ROLL_MIN_MILLI + rng.randi_range(0, GachaConstants.ROLL_STEPS) * GachaConstants.ROLL_STEP_MILLI


## 十连（全局保底计数器连续，故任意连续 10 抽必出 SR+；与 10 次单抽等价，无折扣无独占保底）。
func try_pull_ten(rng: RandomNumberGenerator = null) -> Array[CharacterInstance]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out: Array[CharacterInstance] = []
	for i in range(10):
		out.append(try_pull(rng))
	return out
