class_name CharacterSelect
extends Control
## 出战人物选择画面（S10 增补）。介于主菜单与竞技场之间：列出已拥有角色，
## 点击卡片选中、右侧展示详情，确认后写入 RosterAutoload.active_character_id 再进竞技场。
##
## 纪律：①不硬编码颜色，一律 ColorTokens.*；②不重复抽卡/数值规则（只读 RosterAutoload 与 CharacterInstance）；
## ③空花名册（新档）自动授予初始角色 STARTER_ID，保证「打开就能选」。

## 职阶中文标签（archetype → 中文），仅展示用。
const ARCH_LABEL := {
	&"BLADE": "锋刃",
	&"BULWARK": "磐盾",
	&"WINDCHASER": "风追",
	&"RESONANT": "谐律",
}
## 稀有度标签（索引 = rarity）：N / R / SR / SSR。
const RARITY_LABEL := ["N", "R", "SR", "SSR"]

var _owned: Array[CharacterInstance] = []
var _selected: CharacterInstance = null
var _cards: Dictionary = {}        # character_id -> Button
var _detail: VBoxContainer = null
var _detail_text: VBoxContainer = null      # 文字详情（_refresh_detail 只清这个，不碰预览）
var _preview_container: SubViewportContainer = null
var _preview_sub: SubViewport = null
var _preview_pivot: Node3D = null           # 旋转轴：承载机甲模型，_process 持续自转
var _sel_style: StyleBoxFlat = null
var _norm_style: StyleBoxFlat = null


func _ready() -> void:
	_build_styles()
	_build_ui()
	_collect_owned()
	_build_cards()
	_select_default()


# --- 样式（选中 = 稀有度色粗边框；未选 = 中性细边框）-----------------------------

func _build_styles() -> void:
	_norm_style = StyleBoxFlat.new()
	_norm_style.bg_color = ColorTokens.UI_BG.lightened(0.1)
	_norm_style.border_color = ColorTokens.INACTIVE
	_norm_style.set_border_width_all(2)
	_norm_style.set_corner_radius_all(8)
	_norm_style.set_content_margin_all(10)

	_sel_style = StyleBoxFlat.new()
	_sel_style.bg_color = ColorTokens.UI_BG.lightened(0.1)
	_sel_style.border_color = ColorTokens.RESONANCE_GLOW
	_sel_style.set_border_width_all(4)
	_sel_style.set_corner_radius_all(8)
	_sel_style.set_content_margin_all(10)


func _rarity_color(r: int) -> Color:
	match r:
		3: return ColorTokens.FRIENDLY_GOLD
		2: return ColorTokens.SKY_AZURE
		1: return ColorTokens.PLAYER_ALLY_MAIN
		_: return ColorTokens.INACTIVE


# --- 布局 ----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ColorTokens.UI_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 40)
	pad.add_theme_constant_override("margin_top", 28)
	pad.add_theme_constant_override("margin_bottom", 24)
	root.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	pad.add_child(inner)

	var title := Label.new()
	title.text = "选择出战角色"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ColorTokens.RESONANCE_GLOW)
	inner.add_child(title)

	var hint := Label.new()
	hint.text = "点击卡片选择 · 右侧查看详情 · 确认后进入战斗"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	inner.add_child(hint)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(split)

	# 左：可滚动卡片网格
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	_cards_grid = grid

	# 右：详情面板
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size = Vector2(360, 0)
	detail.add_theme_constant_override("separation", 10)
	split.add_child(detail)
	_detail = detail

	# 右栏顶部：实时 3D 机甲预览（自动旋转），下方为文字详情。
	_build_preview()
	var cap := Label.new()
	cap.text = "实时预览 · 自动旋转"
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(cap)
	_detail_text = VBoxContainer.new()
	_detail_text.add_theme_constant_override("separation", 8)
	_detail.add_child(_detail_text)

	# 底：操作按钮
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 20)
	inner.add_child(bar)

	_add_button(bar, "确认出战", _on_confirm, ColorTokens.RESONANCE_GLOW)
	_add_button(bar, "返回菜单", _on_back, ColorTokens.INACTIVE)


var _cards_grid: GridContainer = null


func _add_button(parent: HBoxContainer, text: String, cb: Callable, accent: Color) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(220, 56)
	b.add_theme_color_override("font_color", accent)
	b.pressed.connect(cb)
	parent.add_child(b)


# --- 数据收集 ------------------------------------------------------------------

func _collect_owned() -> void:
	# 空花名册（新档）先授予初始角色，保证至少一张可选卡片。
	if RosterAutoload.engine.roster.owned_count() == 0:
		RosterAutoload.grant(RosterAutoload.STARTER_ID)
	_owned = []
	for id in RosterAutoload.engine.roster.owned.keys():
		_owned.append(RosterAutoload.engine.roster.owned[id])
	_owned.sort_custom(
		func(a: CharacterInstance, b: CharacterInstance) -> bool:
			if a.rarity != b.rarity:
				return a.rarity > b.rarity
			return a.display_name < b.display_name
	)


# --- 卡片 ----------------------------------------------------------------------

func _build_cards() -> void:
	for inst in _owned:
		var btn := Button.new()
		btn.text = _card_text(inst)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(220, 132)
		btn.add_theme_font_size_override("font_size", 17)
		btn.add_theme_stylebox_override("normal", _norm_style)
		btn.add_theme_stylebox_override("hover", _norm_style)
		btn.add_theme_stylebox_override("pressed", _norm_style)
		btn.add_theme_stylebox_override("focus", _norm_style)
		btn.pressed.connect(_on_card_pressed.bind(inst))
		_cards_grid.add_child(btn)
		_cards[inst.character_id] = btn


func _card_text(inst: CharacterInstance) -> String:
	var rt: String = RARITY_LABEL[inst.rarity] if inst.rarity < RARITY_LABEL.size() else "?"
	var arch: String = ARCH_LABEL.get(inst.archetype, String(inst.archetype))
	var tag := "[%s] %s" % [rt, arch]
	var active := "（出战中）" if RosterAutoload.active_character_id == inst.character_id else ""
	return "%s%s\n%s\nHP %d · 攻 %d · 防 %d\n速 %d · 亲和 %d" % [
		inst.display_name, active, tag,
		inst.final_hp, inst.final_attack, inst.final_defense,
		inst.final_move_speed, inst.final_affinity,
	]


func _on_card_pressed(inst: CharacterInstance) -> void:
	_select(inst)


func _select(inst: CharacterInstance) -> void:
	if _selected != null and _cards.has(_selected.character_id):
		var prev: Button = _cards[_selected.character_id]
		prev.add_theme_stylebox_override("normal", _norm_style)
		prev.add_theme_stylebox_override("hover", _norm_style)
		prev.add_theme_stylebox_override("pressed", _norm_style)
		prev.add_theme_stylebox_override("focus", _norm_style)
	_selected = inst
	var btn: Button = _cards[inst.character_id]
	btn.add_theme_stylebox_override("normal", _sel_style)
	btn.add_theme_stylebox_override("hover", _sel_style)
	btn.add_theme_stylebox_override("pressed", _sel_style)
	btn.add_theme_stylebox_override("focus", _sel_style)
	_refresh_detail()


func _select_default() -> void:
	var active: CharacterInstance = RosterAutoload.get_active()
	if active != null and _cards.has(active.character_id):
		_select(active)
	elif _owned.size() > 0:
		_select(_owned[0])


# --- 详情面板 ------------------------------------------------------------------

func _refresh_detail() -> void:
	for c in _detail_text.get_children():
		c.queue_free()
	if _selected == null:
		return
	_set_preview_model(_selected.character_id)
	var rc: Color = _rarity_color(_selected.rarity)

	var name := Label.new()
	name.text = "%s  [%s]" % [_selected.display_name, RARITY_LABEL[_selected.rarity] if _selected.rarity < RARITY_LABEL.size() else "?"]
	name.add_theme_font_size_override("font_size", 30)
	name.add_theme_color_override("font_color", rc)
	_detail.add_child(name)

	var arch := Label.new()
	arch.text = "职阶：%s" % ARCH_LABEL.get(_selected.archetype, String(_selected.archetype))
	arch.add_theme_font_size_override("font_size", 18)
	arch.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	_detail.add_child(arch)

	_detail.add_child(_stat_line("生命", _selected.final_hp, ColorTokens.PLAYER_ALLY_MAIN))
	_detail.add_child(_stat_line("攻击", _selected.final_attack, ColorTokens.FRIENDLY_CORAL))
	_detail.add_child(_stat_line("防御", _selected.final_defense, ColorTokens.SKY_AZURE))
	_detail.add_child(_stat_line("速度", _selected.final_move_speed, ColorTokens.PLAYER_ALLY_MAIN))
	_detail.add_child(_stat_line("共鸣亲和", _selected.final_affinity, ColorTokens.RESONANCE_GLOW))

	# 角色技能名（与竞技场 HUD 同一来源）
	var sk_name := "无"
	var sk := CharacterSkillSet.of(_selected.character_id)
	if sk != null:
		sk_name = sk.active_name
	var skill := Label.new()
	skill.text = "主动技能：%s" % sk_name
	skill.add_theme_font_size_override("font_size", 18)
	skill.add_theme_color_override("font_color", ColorTokens.FRIENDLY_GOLD)
	_detail.add_child(skill)


func _stat_line(label: String, value: int, accent: Color) -> Label:
	var l := Label.new()
	l.text = "%s：%d" % [label, value]
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", accent)
	return l


# --- 实时 3D 预览（SubViewport 渲染选中机甲，自动旋转）---------------------------

func _build_preview() -> void:
	_preview_container = SubViewportContainer.new()
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.custom_minimum_size = Vector2(340, 300)
	_preview_container.stretch = true
	_detail.add_child(_preview_container)

	var vp := SubViewport.new()
	vp.size = Vector2(512, 480)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(vp)
	_preview_sub = vp

	# 摄影机：正对机身中段、略仰视（先入树再 look_at，避免「Node not inside tree」）。
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.35, 4.0)
	vp.add_child(cam)
	cam.look_at(Vector3(0.0, 1.25, 0.0), Vector3.UP)

	# 打光：主光（白）+ 补光（苍穹蓝）+ 轮廓光（青白），保证无环境也能看清 albedo 与 emissive。
	var key := DirectionalLight3D.new()
	key.position = Vector3(3.0, 5.0, 4.0)
	key.light_color = Color.WHITE
	key.light_energy = 1.6
	vp.add_child(key)
	key.look_at(Vector3.ZERO)

	var fill := DirectionalLight3D.new()
	fill.position = Vector3(-4.0, 2.0, -2.0)
	fill.light_color = ColorTokens.SKY_AZURE
	fill.light_energy = 0.5
	vp.add_child(fill)
	fill.look_at(Vector3.ZERO)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.0, 1.4, -3.0)
	rim.light_color = ColorTokens.RESONANCE_GLOW
	rim.light_energy = 0.8
	vp.add_child(rim)

	# 旋转轴：承载机甲模型，_process 中持续自转。
	_preview_pivot = Node3D.new()
	vp.add_child(_preview_pivot)


func _set_preview_model(id: StringName) -> void:
	if _preview_pivot == null:
		return
	for c in _preview_pivot.get_children():
		c.queue_free()
		_preview_pivot.remove_child(c)
	var m := CharacterModel.new()
	m.build(id)
	_preview_pivot.add_child(m)


func _process(delta: float) -> void:
	if _preview_pivot != null:
		_preview_pivot.rotation.y += delta * 0.6


# --- 操作 ----------------------------------------------------------------------

func _on_confirm() -> void:
	if _selected == null:
		return
	RosterAutoload.set_active(_selected.character_id)
	get_tree().change_scene_to_file("res://game/scenes/arena_min.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")
