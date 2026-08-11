class_name GachaCatalog
extends RefCounted
## v1 角色花名册（S9）。8 角色 = 1 尘 + 2 铁 + 3 辉 + 2 星，
## 覆盖 4 职阶（BLADE / BULWARK / WINDCHASER / RESONANT）。
## 每个职阶五维基线之和恒 = 500（AC-GACHA-03）。


func all() -> Array[CharacterDefinition]:
	var list: Array[CharacterDefinition] = []
	# 尘·灰烬学徒 — 锋刃 N
	list.append(_mk(&"ash_acolyte", "尘·灰烬学徒", &"BLADE", GachaConstants.RARITY.N, 95, 118, 90, 102, 95, &"锋刃基线"))
	# 铁·誓锁守卫 — 磐盾 R
	list.append(_mk(&"oath_guard", "铁·誓锁守卫", &"BULWARK", GachaConstants.RARITY.R, 115, 88, 112, 92, 93, &"磐盾基线"))
	# 铁·迅羽游侠 — 风追 R
	list.append(_mk(&"swift_ranger", "铁·迅羽游侠", &"WINDCHASER", GachaConstants.RARITY.R, 90, 110, 88, 108, 104, &"风追基线"))
	# 辉·疾风回响者 — 风追 SR
	list.append(_mk(&"gale_echo", "辉·疾风回响者", &"WINDCHASER", GachaConstants.RARITY.SR, 90, 110, 88, 108, 104, &"风追基线"))
	# 辉·磐心卫士 — 磐盾 SR
	list.append(_mk(&"bulwark_heart", "辉·磐心卫士", &"BULWARK", GachaConstants.RARITY.SR, 115, 88, 112, 92, 93, &"磐盾基线"))
	# 星·谐律主祭 — 谐律 SSR
	list.append(_mk(&"resonant_hierophant", "星·谐律主祭", &"RESONANT", GachaConstants.RARITY.SSR, 98, 95, 94, 98, 115, &"谐律基线"))
	# 星·断空剑主 — 锋刃 SSR
	list.append(_mk(&"voidblade_lord", "星·断空剑主", &"BLADE", GachaConstants.RARITY.SSR, 95, 118, 90, 102, 95, &"锋刃基线"))
	# 辉·共鸣歌者 — 谐律 SR
	list.append(_mk(&"resonant_singer", "辉·共鸣歌者", &"RESONANT", GachaConstants.RARITY.SR, 98, 95, 94, 98, 115, &"谐律基线"))
	return list


func of_rarity(r: int) -> Array[CharacterDefinition]:
	var out: Array[CharacterDefinition] = []
	for d in all():
		if d.rarity == r:
			out.append(d)
	return out


func by_id(id: StringName) -> CharacterDefinition:
	for d in all():
		if d.character_id == id:
			return d
	return null


func _mk(id: StringName, name: String, arche: StringName, rarity: int,
		hp: int, atk: int, dfn: int, spd: int, aff: int, lore: String) -> CharacterDefinition:
	var d := CharacterDefinition.new()
	d.character_id = id
	d.display_name = name
	d.archetype = arche
	d.rarity = rarity
	d.base_hp = hp
	d.base_attack = atk
	d.base_defense = dfn
	d.base_move_speed = spd
	d.base_affinity = aff
	d.lore_text = lore
	return d
