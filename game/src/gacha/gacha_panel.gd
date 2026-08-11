class_name GachaPanel
extends Control
## 抽卡面板（S9 UI · 最小可用）。动态构建按钮与文本，调 RosterAutoload 抽卡并刷新显示。
## 不依赖外部 .tscn；挂到任意 Control 子树（如据点菜单）即可生效。
## 测试可用 _roster_override 注入独立 RosterService，避免依赖全局 autoload 加载顺序。

## 测试注入点：非 null 时替代全局 RosterAutoload。
var _roster_override = null

var _pull_btn: Button
var _pull_ten_btn: Button
var _info_label: Label
var _result_label: Label
var _last_results: Array[CharacterInstance] = []


func _get_roster() -> RosterService:
	return _roster_override as RosterService if _roster_override != null else RosterAutoload


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	add_child(_info_label)

	_pull_btn = Button.new()
	_pull_btn.name = "PullButton"
	_pull_btn.text = "单抽"
	add_child(_pull_btn)
	_pull_btn.pressed.connect(_on_pull_pressed)

	_pull_ten_btn = Button.new()
	_pull_ten_btn.name = "PullTenButton"
	_pull_ten_btn.text = "十连"
	add_child(_pull_ten_btn)
	_pull_ten_btn.pressed.connect(_on_pull_ten_pressed)

	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	add_child(_result_label)


func _on_pull_pressed() -> void:
	_last_results = [_get_roster().pull(null)]
	_refresh()


func _on_pull_ten_pressed() -> void:
	_last_results = _get_roster().pull_ten(null)
	_refresh()


func _refresh() -> void:
	var roster := _get_roster()
	if _info_label != null:
		_info_label.text = "拥有 %d" % roster.owned_count()
	if _result_label != null and _last_results.size() > 0:
		var parts: PackedStringArray = PackedStringArray()
		for inst in _last_results:
			parts.append("%s [%s]" % [inst.display_name, GachaConstants.RARITY_NAME.get(inst.rarity, "?")])
		_result_label.text = "\n".join(parts)
