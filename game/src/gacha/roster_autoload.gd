class_name RosterService
extends Node
## 花名册 Autoload（S9 集成层）。持有 GachaEngine 单例，向全游戏暴露抽卡 / 拥有查询 / 出战管理，
## 并通过 to_dict / from_dict 与 SaveModel 对接持久化（ADR-004）。
##
## 仅做「编排与 IO 适配」，抽卡概率 / 数值计算全在 GachaEngine / CharacterInstance，本类不重复任何规则。

var engine: GachaEngine = GachaEngine.new()

## 当前出战角色 id（持久化于 roster dict 内）。
var active_character_id: StringName = &""

## 新档保底角色（N 档锋刃）。保证「任何人打开就能玩」——空存档不必先抽卡。
const STARTER_ID: StringName = &"ash_acolyte"


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


## 直接授予一名角色（**非抽卡**）。roll 全取中位 1000（不掷骰），
## 因此不触碰保底计数器、不返尘、不发重掷权——绕开 record_pull 是刻意的：
## 保底与货币只应由「真实抽取」驱动，赠送角色若走 record_pull 会污染 pity。
## 已拥有则原样返回既有实例（roll 已永久锁定，绝不覆盖）。
func grant(id: StringName) -> CharacterInstance:
	if engine.roster.is_owned(id):
		return engine.roster.owned[id]
	var def := engine.catalog.by_id(id)
	if def == null:
		return null
	var inst := CharacterInstance.new()
	inst.character_id = def.character_id
	inst.roll_atk_milli = 1000
	inst.roll_def_milli = 1000
	inst.roll_aff_milli = 1000
	inst.rehydrate(def)
	engine.roster.owned[id] = inst
	return inst


## 保证「有人能上场」——供 arena 入口调用，空存档也可直接开打。
## 1) 已有出战 → 原样返回；2) 有拥有角色但未选 → 自动选稀有度最高者；
## 3) 一个都没有 → 授予 STARTER_ID 并出战。
func ensure_playable() -> CharacterInstance:
	var current := get_active()
	if current != null:
		return current
	if engine.roster.owned_count() > 0:
		var best: CharacterInstance = null
		for id: StringName in engine.roster.owned.keys():
			var c: CharacterInstance = engine.roster.owned[id]
			if best == null or c.rarity > best.rarity:
				best = c
		if best != null:
			active_character_id = best.character_id
			return best
	var starter := grant(STARTER_ID)
	if starter != null:
		active_character_id = starter.character_id
	return starter


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
	# 派生字段不入档（见 CharacterInstance.rehydrate 注释），读档后必须按目录补齐，
	# 否则 final_hp 停在 0 → 出战瞬间 0 血。此处是回读路径上唯一的补齐点。
	for id: StringName in engine.roster.owned.keys():
		var inst: CharacterInstance = engine.roster.owned[id]
		inst.rehydrate(engine.catalog.by_id(id))
	active_character_id = StringName(d.get("active_character_id", ""))
	# 存档里的出战 id 若已不在花名册（目录改版 / 档损），降级为「未选」而非留悬空引用。
	if active_character_id != &"" and not engine.roster.is_owned(active_character_id):
		active_character_id = &""
