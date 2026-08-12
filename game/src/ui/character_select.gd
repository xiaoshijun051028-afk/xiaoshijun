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

# 预览旋转（鼠标拖拽自由转；未拖拽时缓慢自转）。
var _preview_dragging: bool = false
var _preview_yaw: float = 0.0
var _preview_pitch: float = 0.0
# 星轨召唤面板引用（关闭时置 null）。
var _summon_panel: Control = null
var _summon_currency: Label = null
var _summon_results: VBoxContainer = null


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
	# 必须让 pad/inner 纵向 EXPAND，否则整棵 UI 塌缩到最小高度，
	# 底部「开始战斗」按钮栏会被挤出可视区（用户反馈“找不到按钮”的根因）。
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)

	var title := Label.new()
	title.text = "选择出战角色"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ColorTokens.RESONANCE_GLOW)
	inner.add_child(title)

	var hint := Label.new()
	hint.text = "点击卡片选择 · 右侧查看详情 · 点「开始战斗」进入竞技场"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	inner.add_child(hint)

	# 中部内容区：可滚动，保证窗口较矮时细节列不会把底部按钮挤出屏幕。
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(scroller)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # 保持最小高度 → 过高时由 scroller 纵向滚动
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(split)

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
	cap.text = "实时预览 · 拖拽旋转，松手自动转"
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(cap)
	_detail_text = VBoxContainer.new()
	_detail_text.add_theme_constant_override("separation", 8)
	_detail.add_child(_detail_text)

	# 底：操作按钮（开始战斗 作为主按钮，实心高亮；其余为描边次按钮）。
	# 关键：bar 直接挂在 root 上（pad 的兄弟节点），始终钉在视口底部，
	# 绝不随中部内容滚动或溢出 —— 这是「开始战斗」按钮之前消失的根因。
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	bar.add_theme_constant_override("separation", 20)
	root.add_child(bar)

	_add_button(bar, "开始战斗", _on_confirm, ColorTokens.RESONANCE_GLOW, true)
	_add_button(bar, "星轨召唤", _on_summon, ColorTokens.FRIENDLY_GOLD)
	_add_button(bar, "返回菜单", _on_back, ColorTokens.INACTIVE)


var _cards_grid: GridContainer = null


func _add_button(parent: HBoxContainer, text: String, cb: Callable, accent: Color, primary: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(220, 56)
	var sb := StyleBoxFlat.new()
	if primary:
		# 主按钮：实心高亮底 + 深色字，确保「开始」无法被忽略。
		sb.bg_color = accent
		sb.border_color = accent.lightened(0.3)
		b.add_theme_color_override("font_color", Color(0.04, 0.06, 0.09))
		b.custom_minimum_size = Vector2(280, 66)
		b.add_theme_font_size_override("font_size", 30)
	else:
		sb.bg_color = ColorTokens.UI_BG.lightened(0.18)
		sb.border_color = accent
		b.add_theme_color_override("font_color", accent)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
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
	_detail_text.add_child(name)

	var arch := Label.new()
	arch.text = "职阶：%s" % ARCH_LABEL.get(_selected.archetype, String(_selected.archetype))
	arch.add_theme_font_size_override("font_size", 18)
	arch.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	_detail_text.add_child(arch)

	_detail_text.add_child(_stat_line("生命", _selected.final_hp, ColorTokens.PLAYER_ALLY_MAIN))
	_detail_text.add_child(_stat_line("攻击", _selected.final_attack, ColorTokens.FRIENDLY_CORAL))
	_detail_text.add_child(_stat_line("防御", _selected.final_defense, ColorTokens.SKY_AZURE))
	_detail_text.add_child(_stat_line("速度", _selected.final_move_speed, ColorTokens.PLAYER_ALLY_MAIN))
	_detail_text.add_child(_stat_line("共鸣亲和", _selected.final_affinity, ColorTokens.RESONANCE_GLOW))

	# 角色技能名（与竞技场 HUD 同一来源）
	var sk_name := "无"
	var sk := CharacterSkillSet.of(_selected.character_id)
	if sk != null:
		sk_name = sk.active_name
	var skill := Label.new()
	skill.text = "主动技能：%s" % sk_name
	skill.add_theme_font_size_override("font_size", 18)
	skill.add_theme_color_override("font_color", ColorTokens.FRIENDLY_GOLD)
	_detail_text.add_child(skill)


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
	_preview_container.mouse_filter = Control.MOUSE_FILTER_PASS   # 让预览区点击穿透到 _unhandled_input 做拖拽
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
	if _preview_pivot == null:
		return
	if not _preview_dragging:
		_preview_yaw += delta * 0.6
	_preview_pivot.rotation.y = _preview_yaw
	_preview_pivot.rotation.x = _preview_pitch


# --- 操作 ----------------------------------------------------------------------

func _on_confirm() -> void:
	if _selected == null:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RosterAutoload.set_active(_selected.character_id)
	get_tree().change_scene_to_file("res://game/scenes/arena_min.tscn")


func _on_back() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")


# --- 星轨召唤（抽卡入口）-------------------------------------------------------

func _on_summon() -> void:
	_open_summon()


func _open_summon() -> void:
	if _summon_panel != null:
		_summon_panel.queue_free()
		_summon_panel = null
	var dim := Control.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_summon_panel = dim

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(bg)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(580, 540)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dim.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var title := Label.new()
	title.text = "星轨召唤"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", ColorTokens.FRIENDLY_GOLD)
	v.add_child(title)

	_summon_currency = Label.new()
	_update_summon_currency()
	v.add_child(_summon_currency)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_add_button(row, "单抽", _do_summon.bind(1), ColorTokens.RESONANCE_GLOW)
	_add_button(row, "十连", _do_summon.bind(10), ColorTokens.FRIENDLY_GOLD)
	_add_button(row, "关闭", _close_summon, ColorTokens.INACTIVE)

	var cap := Label.new()
	cap.text = "召唤结果"
	cap.add_theme_font_size_override("font_size", 18)
	cap.add_theme_color_override("font_color", ColorTokens.INACTIVE)
	v.add_child(cap)

	_summon_results = VBoxContainer.new()
	_summon_results.add_theme_constant_override("separation", 4)
	v.add_child(_summon_results)


func _close_summon() -> void:
	if _summon_panel != null:
		_summon_panel.queue_free()
		_summon_panel = null
	_summon_currency = null
	_summon_results = null


func _update_summon_currency() -> void:
	if _summon_currency == null:
		return
	_summon_currency.text = "星轨碎片：%d    心愿尘埃：%d" % [RosterAutoload.astral(), RosterAutoload.dust()]
	_summon_currency.add_theme_font_size_override("font_size", 16)
	_summon_currency.add_theme_color_override("font_color", ColorTokens.INACTIVE)


func _do_summon(n: int) -> void:
	var before: Array = RosterAutoload.engine.roster.owned.keys()
	var results: Array[CharacterInstance]
	if n >= 10:
		results = RosterAutoload.pull_ten()
	else:
		results = [RosterAutoload.pull()]
	_rebuild_cards()
	_update_summon_currency()
	# 面板可能未打开（如冒烟直驱），结果区为空时跳过展示，仅保证抽卡+刷新不崩。
	if _summon_results != null:
		for c in _summon_results.get_children():
			c.queue_free()
		for inst in results:
			var is_new: bool = not (inst.character_id in before)
			var line := Label.new()
			line.text = "%s  [%s]%s" % [
				inst.display_name,
				RARITY_LABEL[inst.rarity] if inst.rarity < RARITY_LABEL.size() else "?",
				"（新！）" if is_new else "",
			]
			line.add_theme_font_size_override("font_size", 20)
			line.add_theme_color_override("font_color", _rarity_color(inst.rarity))
			_summon_results.add_child(line)


func _rebuild_cards() -> void:
	for c in _cards_grid.get_children():
		c.queue_free()
	_cards.clear()
	_collect_owned()
	_build_cards()
	if _selected != null and _cards.has(_selected.character_id):
		_select(_selected)
	else:
		_select_default()


func _unhandled_input(event: InputEvent) -> void:
	# 预览拖拽旋转：在预览区内按下左键 → 捕获鼠标自由转；松开结束。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _preview_container != null and _preview_container.get_global_rect().has_point(event.position):
				_preview_dragging = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif _preview_dragging:
			_preview_dragging = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _preview_dragging:
		_preview_yaw -= event.relative.x * 0.01
		_preview_pitch = clampf(_preview_pitch - event.relative.y * 0.01, -0.6, 0.6)
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")
