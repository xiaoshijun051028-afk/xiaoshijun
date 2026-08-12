class_name CombatVFX
extends Node3D
## 轻量战斗特效层（S10 增补）。零外部资源：基础图元 + emissive 自发光 + Tween 淡出 + 自动 queue_free。
## 颜色严格取自 ColorTokens（玩家侧青白谐波虹膜 / 敌方锁 THREAT），不引入任何新语义色。
##
## 用法：宿主（arena_min）在 _ready 里 `add_child(CombatVFX.new())`，在结算点调用下列接口即可。

func _fx(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3, start_s: float, end_s: float, dur: float) -> void:
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
	# 计时器兜底清理，确保即便 tween 异常也不会留下孤儿节点。
	if get_tree() != null:
		var t := get_tree().create_timer(dur)
		t.timeout.connect(mi.queue_free)


## 斩击弧光（青白谐波虹膜，贴地环）。命中与否都展示，给玩家明确的「我挥了」反馈。
func slash(pos: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 1.05
	_fx(ring, ColorTokens.RESONANCE_GLOW, pos, Vector3(-90.0, 0.0, 0.0), 0.3, 1.8, 0.36)


## 闪避残影（友方主色，细长方块）。
func dash_trail(pos: Vector3) -> void:
	var streak := BoxMesh.new()
	streak.size = Vector3(0.3, 0.3, 1.8)
	_fx(streak, ColorTokens.PLAYER_ALLY_MAIN, pos, Vector3.ZERO, 0.6, 0.05, 0.3)


## 完美格挡环闪（友方金，贴地大环）。
func perfect_parry(pos: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 1.0
	_fx(ring, ColorTokens.FRIENDLY_GOLD, pos, Vector3(-90.0, 0.0, 0.0), 0.4, 2.2, 0.45)


## 终结技谐波虹膜爆发（青白：外环 + 内核）。
func finisher(pos: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 1.0
	_fx(ring, ColorTokens.RESONANCE_GLOW, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 3.0, 0.6)
	var core := SphereMesh.new()
	core.radius = 0.4
	core.height = 0.8
	_fx(core, ColorTokens.RESONANCE_GLOW, pos, Vector3.ZERO, 0.3, 1.6, 0.6)


## 角色技能发动（珊瑚色上升环，复用谐波虹膜视觉语言）。
func skill_cast(pos: Vector3) -> void:
	finisher(pos)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.9
	_fx(ring, ColorTokens.FRIENDLY_CORAL, pos, Vector3(-90.0, 0.0, 0.0), 0.4, 2.6, 0.5)


## 命中火花（颜色由调用方决定：玩家命中传 RESONANCE_GLOW，玩家受击传 THREAT）。
## 双段：彩色冲击球 + 纯白高亮核心，强化「打到了」的确认感。
func hit_impact(pos: Vector3, color: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	_fx(s, color, pos, Vector3.ZERO, 0.5, 0.05, 0.3)
	var core := SphereMesh.new()
	core.radius = 0.15
	core.height = 0.3
	_fx(core, Color(1.0, 1.0, 1.0), pos, Vector3.ZERO, 0.3, 0.02, 0.18)


## 浮动伤害数字（Label3D，默认字体，零外部资源）。上升 + 淡出，明确「−X」。
func damage_popup(pos: Vector3, amount: int, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = "-%d" % amount
	lbl.position = pos
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.font_size = 52
	lbl.outline_size = 5
	lbl.outline_modulate = Color(0.0, 0.0, 0.0)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", pos.y + 1.3, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.finished.connect(lbl.queue_free)


## 敌方蓄力指示（THREAT 红环，随 windup 帧数放大后自动消散）。
func enemy_telegraph(pos: Vector3, dur: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 1.1
	_fx(ring, ColorTokens.THREAT, pos, Vector3(-90.0, 0.0, 0.0), 0.5, 1.8, dur)
