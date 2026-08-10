## 存档模型的**纯逻辑**部分（无文件 IO、无场景树）——序列化 / 反序列化 / 校验 / 迁移 / 钳制。
##
## 依据 ADR-004。把这层抽成纯逻辑的收益：GDD S8 §⑦ 四条验收（还原 100% / 版本不匹配拒绝 /
## 写盘失败不崩 / 常量不入档）全部可无场景单测，毫秒级跑完。
##
## ★ 铁律（ADR-004 决策 3，同时是 ADR-002 单一真相源的延伸保护）：
##   **任何 GameConstants 常量绝不入档。** 否则调平衡后老存档会把旧规则带回内存，
##   制造第二真相源，P4 支柱的工程保障当场失效。
##   test_save_no_constants.gd 会扫描序列化产物断言这一点。
class_name SaveModel
extends RefCounted

## 当前 schema 版本。单调递增；每次不兼容改动 +1 并补一个 migrate_N_to_N1()。
const SCHEMA_VERSION: int = 1

## 校验和字段前缀。覆盖除自身外的全部内容。
const CHECKSUM_PREFIX: String = "sha256:"

## 禁止入档的字段名黑名单（大小写不敏感匹配）。
## 这不是「建议」，是 test_save_no_constants.gd 的断言依据。
const FORBIDDEN_KEYS: PackedStringArray = [
	"resonance_max", "max", "initial", "resonance_initial",
	"gate_cost", "finisher_cost",
	"cancel_window", "parry_window", "dash_iframes",
	"gain_hit", "gain_kill", "gain_node", "gain_perfect_parry",
	"ticks_per_second", "node_cooldown_frames", "out_of_combat_frames",
]


## 构造一份空白新档（GDD S8：文件不存在 → 新游戏，池 = INITIAL）。
static func new_save(game_version: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"game_version": game_version,
		"saved_at_unix": 0,
		"player": {
			"hp": 0,
			"last_shrine_id": "",
			"island_id": "hub",
			"transform": PackedFloat64Array(),
		},
		# ★ 只有 current 一个字段。上限/成本/增益全部来自 GameConstants，不入档。
		"resonance": {"current": GameConstants.RESONANCE_INITIAL},
		"world": {
			"islands_unlocked": ["hub"],
			"gates_open": [],
			"shrines_active": [],
			"nodes_triggered": [],
		},
		"narrative": {"echoes_collected": []},
		"meta": {"skill_points": 0, "skills_unlocked": [], "milestones": []},
		"stats": {"playtime_sec": 0, "deaths": 0},
	}


## 计算 checksum。覆盖除 checksum 字段本身外的全部内容。
static func compute_checksum(data: Dictionary) -> String:
	var copy: Dictionary = data.duplicate(true)
	copy.erase("checksum")
	# sort_keys = true：保证同内容恒得同 hash，不受 Dictionary 插入顺序影响。
	var payload: String = JSON.stringify(copy, "", true)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(payload.to_utf8_buffer())
	return CHECKSUM_PREFIX + ctx.finish().hex_encode()


## 序列化为可写盘的 JSON 文本（含 checksum）。
static func serialize(data: Dictionary) -> String:
	var out: Dictionary = data.duplicate(true)
	out["schema_version"] = SCHEMA_VERSION
	out["checksum"] = compute_checksum(out)
	return JSON.stringify(out, "  ", true)


## 反序列化结果。ok = false 时 error 说明原因，data 不可用。
class ParseResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var data: Dictionary = {}


## 解析 + 校验 + 迁移 + 钳制。任何一步失败都是「优雅拒绝」，绝不抛异常、绝不半途污染内存。
static func deserialize(text: String) -> ParseResult:
	var result: ParseResult = ParseResult.new()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		result.error = "JSON 解析失败或顶层不是对象"
		return result
	var data: Dictionary = parsed as Dictionary

	if not data.has("schema_version"):
		result.error = "缺少 schema_version"
		return result
	var version: int = int(data["schema_version"])

	# 版本不匹配 → 拒绝并提示，不损坏（GDD S8 §⑥）。
	if version > SCHEMA_VERSION:
		result.error = "存档来自更新版本（schema_version=%d > %d）" % [version, SCHEMA_VERSION]
		return result
	if version < SCHEMA_VERSION:
		var migrated: Dictionary = migrate(data, version)
		if migrated.is_empty():
			result.error = "无 %d → %d 的迁移器，拒绝加载" % [version, SCHEMA_VERSION]
			return result
		data = migrated

	# checksum 校验（检测损坏 / 篡改）。允许无 checksum 的手工测试档，但会标注。
	if data.has("checksum"):
		var expected: String = String(data["checksum"])
		var actual: String = compute_checksum(data)
		if expected != actual:
			result.error = "checksum 不匹配（存档可能损坏或被篡改）"
			return result

	result.data = clamp_fields(data)
	result.ok = true
	return result


## 迁移链骨架。v1 是首版，暂无上游版本；新增版本时在此加分支。
## 返回空 Dictionary 表示「无可用迁移器」。
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var working: Dictionary = data.duplicate(true)
	var v: int = from_version
	while v < SCHEMA_VERSION:
		match v:
			# 示例（v2 落地时启用）：
			# 1:
			#     working = migrate_1_to_2(working)
			_:
				return {}
		v += 1
	working["schema_version"] = SCHEMA_VERSION
	return working


## 逐字段钳制 —— **安全边界**，不是可选的整洁度处理。
## 明文 JSON 意味着玩家可以手改；我们不阻止（单机游戏，作弊是玩家自由），
## 但绝不允许非法值让游戏进入不一致状态或崩溃（ADR-004 决策 5）。
static func clamp_fields(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)

	var resonance: Dictionary = out.get("resonance", {}) as Dictionary
	var raw_current: int = int(resonance.get("current", GameConstants.RESONANCE_INITIAL))
	resonance["current"] = clampi(raw_current, 0, GameConstants.RESONANCE_MAX)
	out["resonance"] = resonance

	var meta: Dictionary = out.get("meta", {}) as Dictionary
	meta["skill_points"] = maxi(0, int(meta.get("skill_points", 0)))
	out["meta"] = meta

	var stats: Dictionary = out.get("stats", {}) as Dictionary
	stats["playtime_sec"] = maxi(0, int(stats.get("playtime_sec", 0)))
	stats["deaths"] = maxi(0, int(stats.get("deaths", 0)))
	out["stats"] = stats

	return out


## 扫描存档结构中是否混入了规则常量。测试与 CI 直接消费。
## 返回违规的字段路径列表（空 = 合规）。
static func find_forbidden_keys(data: Dictionary, path: String = "") -> PackedStringArray:
	var violations: PackedStringArray = PackedStringArray()
	for key: Variant in data.keys():
		var key_name: String = String(key)
		var full_path: String = key_name if path.is_empty() else path + "." + key_name
		if FORBIDDEN_KEYS.has(key_name.to_lower()):
			violations.append(full_path)
		var value: Variant = data[key]
		if typeof(value) == TYPE_DICTIONARY:
			violations.append_array(find_forbidden_keys(value as Dictionary, full_path))
	return violations
