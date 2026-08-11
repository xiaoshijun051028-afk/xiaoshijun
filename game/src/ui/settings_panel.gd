class_name SettingsPanel
extends Control
## 设置（design/gdd/ux/opening-ui.md 最小可用）。
## 垂直同步 / 全屏切换 + 返回。Esc 或「返回」按钮 → 自身退出（回到主菜单上下文）。
## 变更经 EventBus.settings_changed 广播（供后续持久化）。


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
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ColorTokens.FRIENDLY_GOLD)
	vbox.add_child(title)

	var vsync := CheckButton.new()
	vsync.text = "垂直同步 (VSync)"
	vsync.button_pressed = (DisplayServer.window_get_vsync_mode(0) == DisplayServer.VSYNC_ENABLED)
	vsync.toggled.connect(_on_vsync_toggled)
	vbox.add_child(vsync)

	var full := CheckButton.new()
	full.text = "全屏"
	full.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	full.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(full)

	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(200, 50)
	close.pressed.connect(_on_close)
	vbox.add_child(close)


func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	EventBus.settings_changed.emit(&"vsync")


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	EventBus.settings_changed.emit(&"window_mode")


func _on_close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
