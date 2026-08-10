extends SceneTree
## lint_magic_numbers · CI 软门禁（control-checklist §K / architecture §11.4）
##
## 扫描 src/combat 与 src/movement 下的 .gd，标记可能的「裸玩法数值」
## （应来自 GameConstants / VerbDefinition.tres 而非硬编码）。
##
## ⚠ 重要：本工具为**软门禁 / 信息性**，默认退出码 0（不阻断 CI）。
##   原因：裸数值判定天然有噪音（索引、enum、坐标、0/1/-1 等结构性用法），
##   在本地无 Godot 可执行以校准误报的情况下，贸然设为硬门禁会阻断 CI。
##   待 Godot 就位、跑通后，按需收紧 allowlist 并升级为硬门禁（exit 1）。
##
## 运行：godot --headless -s game/tools/lint/lint_magic_numbers.gd

const SCAN_ROOTS: PackedStringArray = [
	"res://game/src/combat",
	"res://game/src/movement",
]

## 结构性安全字面量（不视为魔法数字）。
const SAFE_LITERALS: PackedStringArray = ["0", "1", "-1", "2", "3", "4"]


func _initialize() -> void:
	var hits := _scan()
	if hits.is_empty():
		print("lint_magic_numbers: PASS — 无非预期裸数值")
	else:
		print("lint_magic_numbers: [INFO/软门禁] 发现 %d 处疑似裸数值（待人工复核，不阻断 CI）：" % hits.size())
		for h: String in hits:
			print("  " + h)
	quit(0)


func _scan() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for root: String in SCAN_ROOTS:
		_collect(root, out)
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			_collect(full, out)
		elif full.get_extension().to_lower() == "gd":
			_check_file(full, out)
		name = dir.get_next()
	dir.list_dir_end()


func _check_file(path: String, out: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	for i: int in lines.size():
		var raw := lines[i] as String
		var line := raw.strip_edges()
		if line.begins_with("#") or line.begins_with("//") or line.begins_with(";"):
			continue
		if line.begins_with("const ") or line.begins_with("@export"):
			continue   # const / @export 是声明点，允许字面量
		# 抓独立整数/浮点字面量
		var re := RegEx.new()
		re.compile("(?<![\\w.])(\\d+(\\.\\d+)?)(?![\\w.])")
		var results := re.search_all(line)
		if results == null:
			continue
		for r: RegExMatch in results:
			var lit := (r.get_string(0) as String)
			if SAFE_LITERALS.has(lit):
				continue
			# 排除明显非玩法上下文：枚举索引、数组下标、坐标、delta
			if raw.contains("Vector") or raw.contains("delta") or raw.contains("position"):
				continue
			out.append("%s:%d  %s" % [path.trim_prefix("res://"), i + 1, lit])
