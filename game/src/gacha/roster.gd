class_name Roster
extends RefCounted
## 花名册（S9）。持有已拥有角色（首次实例，roll 锁定）+ 重复计数 + 货币 + 保底计数器。
## 设计为可独立实例（GachaEngine 持有）；后续接入 autoload + SaveModel 持久化为待办（feature flag 可关，保零回归）。

## 首次拥有实例：character_id → CharacterInstance。
var owned: Dictionary = {}
## 重复计数：character_id → int。
var duplicates: Dictionary = {}
## 货币（双货币均游玩获取，不接支付）。
var dust: int = 0
var astral: int = 0
## 重复角色返还的 roll 重掷权计数。
var reroll_tokens: int = 0
## 保底计数器（全局连续）。
var pity_ssr: int = 0
var pity_sr: int = 0


## 记录一次抽取结果；重复则返还尘 + 发重掷权，不覆盖首次实例。
func record_pull(inst: CharacterInstance) -> void:
	if owned.has(inst.character_id):
		duplicates[inst.character_id] = int(duplicates.get(inst.character_id, 0)) + 1
		inst.is_duplicate = true
		dust += GachaConstants.DUST_PER_DUPLICATE
		reroll_tokens += 1
	else:
		owned[inst.character_id] = inst


func is_owned(id: StringName) -> bool:
	return owned.has(id)


func owned_count() -> int:
	return owned.size()


## 序列化（SaveModel 持久化用，v1 接入待办）。
func to_dict() -> Dictionary:
	var owned_arr: Array[Dictionary] = []
	for id in owned.keys():
		owned_arr.append(owned[id].to_dict())
	return {
		"owned": owned_arr,
		"dust": dust,
		"astral": astral,
		"reroll_tokens": reroll_tokens,
		"pity_ssr": pity_ssr,
		"pity_sr": pity_sr,
		# 常量禁止入档（design §5 FORBIDDEN_KEYS）：pity_ssr_hard / pity_sr_hard 为常量，绝不出档。
	}


func from_dict(d: Dictionary) -> void:
	owned = {}
	duplicates = {}
	var arr: Array = d.get("owned", [])
	for entry in arr:
		var inst := CharacterInstance.from_dict(entry)
		owned[inst.character_id] = inst
	dust = int(d.get("dust", 0))
	astral = int(d.get("astral", 0))
	reroll_tokens = int(d.get("reroll_tokens", 0))
	pity_ssr = int(d.get("pity_ssr", 0))
	pity_sr = int(d.get("pity_sr", 0))
