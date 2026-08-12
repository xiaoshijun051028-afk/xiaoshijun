class_name CombatVFX
extends Node3D
## 轻量战斗特效层（S10 增补）。零外部资源：基础图元 + emissive 自发光 + Tween 淡出 + 自动 queue_free。
## 颜色严格取自 ColorTokens：玩家侧 = 当前出战角色签名色 `accent`（由 arena 设定）；敌方锁 THREAT。
##
## 主题化（S10「不同人物特效完全不一样」）：arena 在确认出战角色后写入 `accent`（ColorTokens.ACCENT_*）
## 与 `profile`（角色 id）；玩家侧 slash / finisher / skill_cast 即按该角色的专属几何样式 + 签名色呈现，
## 八角色八套互异视觉语言。模型与特效共用 CharacterModel.accent_of() 单一真相源，保证同色。

var accent: Color = ColorTokens.RESONANCE_GLOW   # 当前出战角色签名色（arena 设定）
var profile: StringName = &"__player__"          # 当前出战角色 id（决定特效样式）


func _fx(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3, start_s: float, end_s: float, dur: float, sweep_deg: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_color.a = 1.0
	# Godot 4.7 未开 Physical Light Units 时赋 emission_intensity 会报错，只用 emissive 颜色做发光。
	# Godot 4 中发光只需把 emissive 设为非黑色即自动启用（emissive_enabled 是 3.x 旧属性）。
	m.emissive = color
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3.ONE * start_s
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * end_s, dur)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	# 可选挥扫：绕 Z 轴从 -sweep 摆到 +sweep，让静态弧光有「挥出去」的动势。
	if sweep_deg > 0.0:
		mi.rotation_degrees.z = rot_deg.z - sweep_deg
		tw.parallel().tween_property(mi, "rotation_degrees:z", rot_deg.z + sweep_deg, dur)
	# 计时器兜底清理，确保即便 tween 异常也不会留下孤儿节点。
	if get_tree() != null:
		var t := get_tree().create_timer(dur)
		t.timeout.connect(mi.queue_free)


# 共用构件（均走 accent 签名色）。
func _ring(pos: Vector3, inner: float, outer: float, end_s: float, dur: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	_fx(t, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.7, end_s, dur)


func _ball(pos: Vector3, r: float, end_s: float, dur: float) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	_fx(s, accent, pos, Vector3.ZERO, 0.5, end_s, dur)


# 放射火花（斩击/命中/终结的「碎屑」层次，强化动感与打击密度）。
func _spark_burst(pos: Vector3, color: Color, count: int, radius: float) -> void:
	for i in count:
		var ang := deg_to_rad(float(i) / float(count) * 360.0)
		var off := Vector3(cos(ang), randf() * 0.6, sin(ang)) * radius
		var s := SphereMesh.new()
		s.radius = 0.10
		s.height = 0.20
		_fx(s, color, pos + off, Vector3.ZERO, 0.6, 0.02, 0.28 + randf() * 0.12)


# =====================================================================================
# 斩击：8 角色 8 套样式（命中与否都展示，给玩家明确的「我挥了」反馈；尺寸已放大）
# =====================================================================================

func slash(pos: Vector3) -> void:
	match profile:
		&"ash_acolyte":         _slash_crescent(pos)
		&"voidblade_lord":      _slash_cross(pos)
		&"oath_guard":          _slash_shock(pos)
		&"bulwark_heart":       _slash_pulse(pos)
		&"swift_ranger":        _slash_streak(pos)
		&"gale_echo":           _slash_storm(pos)
		&"resonant_hierophant": _slash_rings(pos)
		&"resonant_singer":     _slash_wave(pos)
		_:                      _slash_crescent(pos)
	# 统一补一层放射火花，强化「挥击碎屑」层次（八角色共用）。
	_spark_burst(pos, accent, 5, 1.1)


## BLADE 锋刃·旭金：上挑新月弧（锐利、快）。
func _slash_crescent(pos: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 1.7
	_fx(ring, accent, pos, Vector3(-60.0, 0.0, 0.0), 0.5, 2.9, 0.38, 50.0)


## BLADE·断空·霜白：双刀交叉 X 斩。
func _slash_cross(pos: Vector3) -> void:
	var a := BoxMesh.new(); a.size = Vector3(0.18, 2.6, 0.18)
	_fx(a, accent, pos, Vector3(0.0, 0.0, 35.0), 0.6, 2.4, 0.36)
	var b := BoxMesh.new(); b.size = Vector3(0.18, 2.6, 0.18)
	_fx(b, accent, pos, Vector3(0.0, 0.0, -35.0), 0.6, 2.4, 0.36)


## BULWARK 磐盾·皇家蓝：厚重震波（贴地环 + 前向小弧）。
func _slash_shock(pos: Vector3) -> void:
	_ring(pos, 0.9, 1.7, 3.2, 0.42)
	var arc := TorusMesh.new(); arc.inner_radius = 0.5; arc.outer_radius = 1.1
	_fx(arc, accent, pos + Vector3(0.0, 0.0, 0.6), Vector3(-90.0, 0.0, 0.0), 0.5, 2.2, 0.4, 40.0)


## BULWARK·磐心·玉青：双核脉冲（左右两球扩张）。
func _slash_pulse(pos: Vector3) -> void:
	var s1 := SphereMesh.new(); s1.radius = 0.5; s1.height = 1.0
	_fx(s1, accent, pos + Vector3(0.3, 0.0, 0.0), Vector3.ZERO, 0.4, 2.4, 0.4)
	var s2 := SphereMesh.new(); s2.radius = 0.5; s2.height = 1.0
	_fx(s2, accent, pos + Vector3(-0.3, 0.0, 0.0), Vector3.ZERO, 0.4, 2.4, 0.4)


## WINDCHASER 风追·炽橙：横向疾掠残线（长条）。
func _slash_streak(pos: Vector3) -> void:
	var st := BoxMesh.new(); st.size = Vector3(3.4, 0.42, 0.42)
	_fx(st, accent, pos, Vector3.ZERO, 0.7, 0.06, 0.3)


## WINDCHASER·疾风·玫红：刃风暴（环 + 四向辐条）。
func _slash_storm(pos: Vector3) -> void:
	var ring := TorusMesh.new(); ring.inner_radius = 0.6; ring.outer_radius = 1.4
	_fx(ring, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 3.0, 0.4, 60.0)
	for i in 4:
		var b := BoxMesh.new(); b.size = Vector3(0.12, 0.12, 1.3)
		_fx(b, accent, pos, Vector3(0.0, float(i) * 90.0, 0.0), 0.5, 2.6, 0.4)


## RESONANT 谐律主祭·碧蓝：谐波同心双环。
func _slash_rings(pos: Vector3) -> void:
	var r1 := TorusMesh.new(); r1.inner_radius = 0.6; r1.outer_radius = 1.5
	_fx(r1, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 3.0, 0.4, 30.0)
	var r2 := TorusMesh.new(); r2.inner_radius = 1.1; r2.outer_radius = 1.5
	_fx(r2, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 3.6, 0.46)


## RESONANT 共鸣歌者·紫晶：宽幅声波弧。
func _slash_wave(pos: Vector3) -> void:
	var arc := TorusMesh.new(); arc.inner_radius = 1.0; arc.outer_radius = 1.8
	_fx(arc, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 3.4, 0.42, 40.0)


# =====================================================================================
# 终结技：8 角色 8 套高潮样式
# =====================================================================================

func finisher(pos: Vector3) -> void:
	match profile:
		&"ash_acolyte":         _fin_ash(pos)
		&"voidblade_lord":      _fin_void(pos)
		&"oath_guard":          _fin_oath(pos)
		&"bulwark_heart":       _fin_heart(pos)
		&"swift_ranger":        _fin_ranger(pos)
		&"gale_echo":           _fin_gale(pos)
		&"resonant_hierophant": _fin_hierophant(pos)
		&"resonant_singer":     _fin_singer(pos)
		_:                      _fin_ash(pos)
	# 终结前导快环 + 收尾放射星火，强化高潮爆发感。
	_ring(pos, 0.3, 0.9, 3.4, 0.3)
	_spark_burst(pos, accent, 9, 1.7)


## 锋刃·旭金：升腾光柱 + 环 + 核。
func _fin_ash(pos: Vector3) -> void:
	var pil := CylinderMesh.new(); pil.top_radius = 0.45; pil.bottom_radius = 0.7; pil.height = 3.2
	_fx(pil, accent, pos + Vector3(0.0, 1.1, 0.0), Vector3.ZERO, 0.4, 2.4, 0.6)
	_ring(pos, 0.8, 1.7, 4.4, 0.6)
	_ball(pos, 0.6, 2.6, 0.6)


## 断空·霜白：交叉巨剑爆裂 + 核。
func _fin_void(pos: Vector3) -> void:
	var a := BoxMesh.new(); a.size = Vector3(0.3, 3.4, 0.3)
	_fx(a, accent, pos, Vector3(0.0, 0.0, 40.0), 0.6, 3.0, 0.6)
	var b := BoxMesh.new(); b.size = Vector3(0.3, 3.4, 0.3)
	_fx(b, accent, pos, Vector3(0.0, 0.0, -40.0), 0.6, 3.0, 0.6)
	_ball(pos, 0.7, 2.8, 0.6)


## 磐盾·皇家蓝：守护穹顶 + 环。
func _fin_oath(pos: Vector3) -> void:
	var d := SphereMesh.new(); d.radius = 1.2; d.height = 2.4
	_fx(d, accent, pos + Vector3(0.0, 0.2, 0.0), Vector3.ZERO, 0.3, 2.2, 0.6)
	_ring(pos, 0.9, 1.8, 4.2, 0.6)


## 磐心·玉青：双核新星 + 环。
func _fin_heart(pos: Vector3) -> void:
	var s1 := SphereMesh.new(); s1.radius = 0.7; s1.height = 1.4
	_fx(s1, accent, pos + Vector3(0.4, 0.0, 0.0), Vector3.ZERO, 0.4, 3.0, 0.6)
	var s2 := SphereMesh.new(); s2.radius = 0.7; s2.height = 1.4
	_fx(s2, accent, pos + Vector3(-0.4, 0.0, 0.0), Vector3.ZERO, 0.4, 3.0, 0.6)
	_ring(pos, 0.6, 1.4, 4.0, 0.6)


## 风追·炽橙：前刺锥爆 + 环。
func _fin_ranger(pos: Vector3) -> void:
	var cone := CylinderMesh.new(); cone.top_radius = 0.1; cone.bottom_radius = 0.8; cone.height = 2.6
	_fx(cone, accent, pos + Vector3(0.0, 0.0, 1.0), Vector3(90.0, 0.0, 0.0), 0.4, 2.6, 0.55)
	_ring(pos, 0.7, 1.5, 4.0, 0.6)


## 疾风·玫红：涡环 + 核。
func _fin_gale(pos: Vector3) -> void:
	_ring(pos, 0.5, 1.4, 4.4, 0.6)
	_ball(pos, 0.6, 2.8, 0.6)


## 谐律主祭·碧蓝：大头光环爆 + 环 + 核。
func _fin_hierophant(pos: Vector3) -> void:
	var hal := TorusMesh.new(); hal.inner_radius = 0.5; hal.outer_radius = 1.4
	_fx(hal, accent, pos + Vector3(0.0, 1.0, 0.0), Vector3.ZERO, 0.5, 3.2, 0.6)
	_ring(pos, 0.8, 1.7, 4.4, 0.6)
	_ball(pos, 0.6, 2.6, 0.6)


## 共鸣歌者·紫晶：径向星爆（六球 + 环）。
func _fin_singer(pos: Vector3) -> void:
	for i in 6:
		var orb := SphereMesh.new(); orb.radius = 0.3; orb.height = 0.6
		var ang := deg_to_rad(float(i) * 60.0)
		var off := Vector3(cos(ang), 0.0, sin(ang)) * 1.0
		_fx(orb, accent, pos + off, Vector3.ZERO, 0.4, 2.2, 0.6)
	_ring(pos, 0.7, 1.5, 4.2, 0.6)


# =====================================================================================
# 技能发动：复用角色母题（slash 形状）+ 快速签名色环，与普攻同源但更盛
# =====================================================================================

func skill_cast(pos: Vector3) -> void:
	slash(pos)
	_ring(pos, 0.5, 1.2, 3.2, 0.5)


# =====================================================================================
# 其余反馈（仍走 accent；敌方语义锁 THREAT）
# =====================================================================================

## 闪避残影（友方签名色，细长方块）。
func dash_trail(pos: Vector3) -> void:
	var streak := BoxMesh.new()
	streak.size = Vector3(0.46, 0.46, 2.7)
	_fx(streak, accent, pos, Vector3.ZERO, 0.9, 0.07, 0.32)


## 完美格挡环闪（角色签名色，贴地大环）。
func perfect_parry(pos: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.6
	_fx(ring, accent, pos, Vector3(-90.0, 0.0, 0.0), 0.6, 3.4, 0.48)


## 命中火花（颜色由调用方决定：玩家命中传 accent，玩家受击传 THREAT）。
## 双段：彩色冲击球 + 纯白高亮核心，强化「打到了」的确认感。
func hit_impact(pos: Vector3, color: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	_fx(s, color, pos, Vector3.ZERO, 0.8, 0.08, 0.32)
	var core := SphereMesh.new()
	core.radius = 0.24
	core.height = 0.48
	_fx(core, Color(1.0, 1.0, 1.0), pos, Vector3.ZERO, 0.45, 0.03, 0.2)
	# 受击方向碎屑四散，强化「打到了」的密度反馈。
	for i in 4:
		var ang := deg_to_rad(float(i) * 90.0)
		var off := Vector3(cos(ang), 0.3, sin(ang)) * 0.7
		var sp := SphereMesh.new()
		sp.radius = 0.08
		sp.height = 0.16
		_fx(sp, color, pos + off, Vector3.ZERO, 0.6, 0.02, 0.26)


## 浮动伤害数字（Label3D，默认字体，零外部资源）。上升 + 淡出，明确「−X」。
func damage_popup(pos: Vector3, amount: int, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = "-%d" % amount
	lbl.position = pos
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.font_size = 84
	lbl.outline_size = 7
	lbl.outline_modulate = Color(0.0, 0.0, 0.0)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", pos.y + 1.9, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.finished.connect(lbl.queue_free)


## 敌方蓄力指示（THREAT 红环，随 windup 帧数放大后自动消散）。
func enemy_telegraph(pos: Vector3, dur: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.6
	_fx(ring, ColorTokens.THREAT, pos, Vector3(-90.0, 0.0, 0.0), 0.8, 2.7, dur)
