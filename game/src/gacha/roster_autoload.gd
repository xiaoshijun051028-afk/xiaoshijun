class_name RosterService
extends Node
## 花名册 Autoload（S9 集成层）。持有 GachaEngine 单例，向全游戏暴露抽卡 / 拥有查询 / 出战管理，
## 并通过 to_dict / from_dict 与 SaveModel 对接持久化（ADR-004）。
##
## 仅做「编排与 IO 适配」，抽卡概率 / 数值计算全在 GachaEngine / CharacterInstance，本类不重复任何规则。

var engine: GachaEngine = GachaEngine.new()

## 当前出战角色 id（持久化于 roster dict 内）。
var active_character_id: StringName = &""


## 单抽（rng 注入用于测试复现）。
func pull(rng: RandomNumberGenerator = null) -> CharacterInstance:
	return engine.try_pull(rng)


## 十连。
func pull_ten(rng: RandomNumberGenerator = null) -> Array[CharacterInstance]:
	return engine.try_pull_ten(rng)


func is_owned(id: StringName) -> bool:
	return engine.roster.is_owned(id)


func owned_count() -> int:
	return engine.roster.owned_count()


## 设出战角色；仅当已拥有才生效，返回是否成功。
func set_active(id: StringName) -> bool:
	if engine.roster.is_owned(id):
		active_character_id = id
		return true
	return false


## 当前出战角色实例（未选或为空时返 null）。
func get_active() -> CharacterInstance:
	if active_character_id == &"":
		return null
	return engine.roster.owned.get(active_character_id, null)


## 货币查询（供 UI 显示 / 抽取成本校验）。
func dust() -> int:
	return engine.roster.dust


func astral() -> int:
	return engine.roster.astral


func pity_ssr() -> int:
	return engine.roster.pity_ssr


## 序列化为存档字典（含 active 选择）。
func to_dict() -> Dictionary:
	var d := engine.roster.to_dict()
	d["active_character_id"] = active_character_id
	return d


func from_dict(d: Dictionary) -> void:
	engine.roster.from_dict(d)
	active_character_id = StringName(d.get("active_character_id", ""))
