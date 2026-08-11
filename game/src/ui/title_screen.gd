class_name TitleScreen
extends Control
## 启动标题屏（design/gdd/ux/opening-ui.md）。
## 任意开始输入（Enter / 空格 / 鼠标点击）→ 进入主菜单。
## 底色调性引用 ColorTokens（UI_BG），标题用共鸣辉光，绝不触碰 THREAT。


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
	center.add_child(vbox)

	var title := Label.new()
	title.text = "星陨之境"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", ColorTokens.RESONANCE_GLOW)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Aetherfall"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", ColorTokens.FRIENDLY_GOLD)
	vbox.add_child(sub)

	var hint := Label.new()
	hint.text = "按 Enter 或 点击 开始"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", ColorTokens.PLAYER_ALLY_MAIN)
	vbox.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")
