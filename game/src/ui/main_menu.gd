class_name MainMenu
extends Control
## 主菜单（design/gdd/ux/opening-ui.md）。四个按钮：开始游戏 / 星轨召唤 / 设置 / 退出。
## 开始游戏 → arena_min；星轨召唤 → 叠加 GachaPanel（复用既有抽卡 UI）；
## 设置 → 叠加 SettingsPanel；退出 → 进程退出。Esc → 回标题屏。


var _gacha_panel: GachaPanel = null
var _settings_panel: Control = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ColorTokens.UI_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	_add_button(vbox, "开始游戏", _on_play)
	_add_button(vbox, "星轨召唤", _on_gacha)
	_add_button(vbox, "设置", _on_settings)
	_add_button(vbox, "退出", _on_quit)


func _add_button(parent: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(300, 58)
	b.pressed.connect(cb)
	parent.add_child(b)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://game/scenes/arena_min.tscn")


func _on_gacha() -> void:
	if _gacha_panel == null:
		_gacha_panel = GachaPanel.new()
		_gacha_panel.name = "GachaPanel"
		add_child(_gacha_panel)


func _on_settings() -> void:
	if _settings_panel == null:
		_settings_panel = preload("res://game/scenes/settings_panel.tscn").instantiate()
		add_child(_settings_panel)


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://game/scenes/title_screen.tscn")
