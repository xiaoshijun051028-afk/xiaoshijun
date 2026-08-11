class_name CharacterInstance
extends Resource
## 拥有角色实例（S9）。抽出瞬间 roll 掷定并**永久锁定**，随存档持久化。
## 重复角色 is_duplicate=true，仅用于尘返还与重掷权，不覆盖首次实例。

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var archetype: StringName = &"BLADE"
@export var rarity: int = 0

## 三维度副属性 roll（千分比，950–1050）；hp/move_speed 恒 1000（不 roll）。永久锁定。
@export var roll_atk_milli: int = 1000
@export var roll_def_milli: int = 1000
@export var roll_aff_milli: int = 1000

## 计算后的最终五维（整数）。
@export var final_hp: int = 0
@export var final_attack: int = 0
@export var final_defense: int = 0
@export var final_move_speed: int = 0
@export var final_affinity: int = 0

## 是否为重复角色（决定尘返还 / 重掷权）。
@export var is_duplicate: bool = false


## 序列化为存档字典（SaveModel 持久化用，v1 接入待办）。
func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"rarity": rarity,
		"roll_atk_milli": roll_atk_milli,
		"roll_def_milli": roll_def_milli,
		"roll_aff_milli": roll_aff_milli,
		"is_duplicate": is_duplicate,
	}


static func from_dict(d: Dictionary) -> CharacterInstance:
	var inst := CharacterInstance.new()
	inst.character_id = d.get("character_id", &"")
	inst.rarity = int(d.get("rarity", 0))
	inst.roll_atk_milli = int(d.get("roll_atk_milli", 1000))
	inst.roll_def_milli = int(d.get("roll_def_milli", 1000))
	inst.roll_aff_milli = int(d.get("roll_aff_milli", 1000))
	inst.is_duplicate = bool(d.get("is_duplicate", false))
	return inst


## 用静态定义补齐派生字段（存档只存 id + 锁定的 roll，**不存**派生的 final_*，
## 因为 final_* 是「常量 × roll」的函数——入档会变成第二个真相源，改一次基线全档漂移）。
## 因此读档后必须 rehydrate，否则 final_hp 停在默认 0 → 出战即 0 血暴毙。
## 幂等：同一 def 重复调用结果一致（roll 已锁定，compute_stat 为纯函数）。
func rehydrate(def: CharacterDefinition) -> void:
	if def == null or def.character_id != character_id:
		return
	display_name = def.display_name
	archetype = def.archetype
	rarity = def.rarity
	final_hp = GachaEngine.compute_stat(def.base_hp, &"hp", rarity, 1000)
	final_attack = GachaEngine.compute_stat(def.base_attack, &"attack", rarity, roll_atk_milli)
	final_defense = GachaEngine.compute_stat(def.base_defense, &"defense", rarity, roll_def_milli)
	final_move_speed = GachaEngine.compute_stat(def.base_move_speed, &"move_speed", rarity, 1000)
	final_affinity = GachaEngine.compute_stat(def.base_affinity, &"resonance_affinity", rarity, roll_aff_milli)
