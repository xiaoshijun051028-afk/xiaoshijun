extends SceneTree
## lint_hex_literals · CI 门禁（control-checklist §K / architecture §9）
##
## 扫描 res:// 下所有 .gd / .gdshader / .tres，禁止出现 hex 颜色字面量
## （如 #A62C6B）。唯一允许的颜色来源是 ColorTokens（resources/colors/*.tres + ColorTokens 类）。
##
## 退役 hex（#2BB6A8 / #F4B740）无论是否带 # 一律拒绝（color-tokens.md §4 禁令）。
##
## 运行：godot --headless -s game/tools/lint/lint_hex_literals.gd
## 退出码：0 = 通过，1 = 发现违规。
##
## ⚠ 执行缺口：本机无 Godot，未实跑；逻辑已审阅，待 CI 验证。

const SCAN_EXTS: PackedStringArray = ["gd", "gdshader", "tres"]

## 排除目录（第三方插件自带颜色代码，不应由本项目 lint 拦截）。
const EXCLUDE_DIRS: PackedStringArray = ["addons", ".godot"]


func _initialize() -> void:
	var violations := _scan()
	if violations.is_empty():
		print("lint_hex_literals: PASS — 无 hex 颜色字面量")
		quit(0)
	else:
		print("lint_hex_literals: FAIL — 发现 %d 处违规：" % violations.size())
		for v: String in violations:
			print("  " + v)
		quit(1)


func _scan() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var re := RegEx.new()
	re.compile("#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})")
	var retired := ColorTokens.retired_hex_denylist()
	_collect("res://", re, retired, out)
	return out


func _collect(dir_path: String, re: RegEx, retired: PackedStringArray, out: PackedStringArray) -> void:
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
			if not _is_excluded(name):
				_collect(full, re, retired, out)
		else:
			var ext := full.get_extension().to_lower()
			if SCAN_EXTS.has(ext):
				_check_file(full, re, retired, out)
		name = dir.get_next()
	dir.list_dir_end()


func _is_excluded(dir_name: String) -> bool:
	for ex: String in EXCLUDE_DIRS:
		if dir_name == ex:
			return true
	return false


func _check_file(path: String, re: RegEx, retired: PackedStringArray, out: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	for i: int in lines.size():
		var line := lines[i] as String
		if line.strip_edges().begins_with("#"):
			continue   # 整行注释跳过（避免文档里讨论颜色被误伤）
		if re.search(line) != null:
			out.append("%s:%d  hex 字面量" % [path.trim_prefix("res://"), i + 1])
		for rh: String in retired:
			if line.to_lower().contains(rh.to_lower()):
				out.append("%s:%d  退役 hex %s" % [path.trim_prefix("res://"), i + 1, rh])
