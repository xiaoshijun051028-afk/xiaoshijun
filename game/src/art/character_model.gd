class_name CharacterModel
extends Node3D
## 卡池角色「机甲感程序化占位」（S10 机甲美术即时可见 stopgap，已强化剪影与共鸣核心）。
## 用 Godot 基础图元（Box / Cylinder / Sphere / Torus / Capsule，零外部 .glb）
## 拼出八台共鸣机甲的差异化剪影，遵循 design/art/mecha-art-bible.md §1/§3/§5：
##   - 阵营层：统一深岩灰 chassis（MECH_BASE）+ 青白共鸣回路（PLAYER_ALLY_MAIN emissive 能量条/核心）。
##   - 职阶层：四职阶剪影语法 + 强调色（accent emissive 识别件）。
##   - 敌方 telegraph 锁 THREAT（由 enemy_model.gd 负责，本脚本一律不引用）。
## 这是占位而非最终资产：最终会被真机甲 GLB（chr_<job>_<id>.tscn）替换，届时本脚本整体退场。
##
## 铁律遵守（production/s10-mecha-pipeline.md §2.2）：剪影差异**只靠 mesh 体积**，不缩放骨骼
## （本脚本本就无骨骼，纯 MeshInstance3D 拼装，天然满足）。不引入 root motion、不碰 AnimationTree/FSM。
##
## 对外接口保持冻结：class_name / build(id) / _ready 自动 build 行为与调用方 arena_min.gd 完全一致。

const BOB_HEIGHT: float = 0.10
const BOB_SPEED: float = 1.6

# --- 机甲线专属灰（art-bible §2.3「提案 / 待登记」Token）---------------------------
# ⚠ color_tokens.gd 当前**未收录** MECH_BASE（OPEN-ITEMS O1）。本文件只读 color_tokens.gd，
# 不得改它，故在此**本地定义**为脚本级常量，并严格引用权威 hex（art-bible §2.3 表）。
# 待补登为 ColorTokens const 后，此处应改为直接引用（消除散落 hex，满足 lint）。
const MECH_BASE: Color = Color(0.165, 0.192, 0.251)          # 深岩灰 #2A3140 机甲 chassis 基色（友方）

var _base_y: float = 0.0
var _spin: bool = false
var _t: float = 0.0
var _pulse: bool = false

# 实例级材质缓存（控制材质数 ≤10）：chassis / faction / accent / dark / wing。
var _m_chassis: StandardMaterial3D = null
var _m_faction: StandardMaterial3D = null
var _m_accent: StandardMaterial3D = null
var _m_dark: StandardMaterial3D = null
var _m_wing: StandardMaterial3D = null
var _accent_base: Color = Color.WHITE  # 用于心核脉冲（调 emissive 颜色亮度，不碰 emission_intensity）


func _ready() -> void:
	if get_child_count() == 0:
		build(&"__player__")


## 按 character_id 构建样本模型；未知 id → 默认玩家剪影。
func build(id: StringName) -> void:
	_clear()
	var spec: Dictionary = _spec_for(id)
	_spin = spec.get("spin", false)
	var s: float = spec.get("scale", 1.0)
	_make_materials(spec.get("accent", ColorTokens.PLAYER_ALLY_MAIN))
	var builder: Callable = spec.get("builder", _build_blade)
	builder.call(spec.get("accent", ColorTokens.PLAYER_ALLY_MAIN))
	scale = Vector3(s, s, s)
	_base_y = position.y


## 八台各路由到专属 builder（不再退化成四档通用剪影）。
## 用户试玩反馈（2026-08-12）：不同人物「特效要一样」。占位阶段取消职阶强调色差异，
## 所有机甲 accent emissive 统一为青白谐波虹膜 RESONANCE_GLOW，仅靠剪影区分职阶。
func _spec_for(id: StringName) -> Dictionary:
	match id:
		&"ash_acolyte":         return {"builder": _build_blade,         "accent": ColorTokens.RESONANCE_GLOW}
		&"voidblade_lord":      return {"builder": _build_voidblade,    "accent": ColorTokens.RESONANCE_GLOW}
		&"oath_guard":          return {"builder": _build_bulwark,      "accent": ColorTokens.RESONANCE_GLOW}
		&"bulwark_heart":       return {"builder": _build_bulwark_heart,"accent": ColorTokens.RESONANCE_GLOW}
		&"swift_ranger":        return {"builder": _build_windchaser,   "accent": ColorTokens.RESONANCE_GLOW}
		&"gale_echo":           return {"builder": _build_gale,         "accent": ColorTokens.RESONANCE_GLOW}
		&"resonant_hierophant": return {"builder": _build_hierophant,   "accent": ColorTokens.RESONANCE_GLOW}
		&"resonant_singer":     return {"builder": _build_singer,       "accent": ColorTokens.RESONANCE_GLOW}
		_:                      return {"builder": _build_blade,         "accent": ColorTokens.RESONANCE_GLOW}


# --- 材质（例程级缓存，整机甲共享 ≤5 个材质实例）-----------------------------------

func _make_materials(accent: Color) -> void:
	_accent_base = accent
	_m_chassis = _mat(MECH_BASE, false, 0.65, 0.5)
	_m_faction = _mat(ColorTokens.PLAYER_ALLY_MAIN, true, 0.0, 0.5)
	_m_accent  = _mat(accent, true, 0.0, 0.5)
	_m_dark    = _mat(MECH_BASE * 0.55, false, 0.8, 0.35)
	_m_wing    = _mat(ColorTokens.RESONANCE_GLOW, true, 0.0, 0.4, true)  # 半透发光翼


func _mat(color: Color, emissive: bool, metallic: float = 0.0, roughness: float = 0.6, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	# Godot 4 中发光只需把 emissive 设为非黑色即自动启用（emissive_enabled 是 3.x 旧属性）。
	if emissive:
		m.emissive = color
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.4
		m.emissive = color
	return m


func _add(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


# 细长盒（肢体/附件通用）。
func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


# 竖直/横置柱（肢体段）。
func _cyl(radius: float, height: float, axis: String = "y") -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	if axis == "x":
		c.radial_segments = 8
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


# --- 通用 chassis（四职阶共用机身结构；剪影差异只靠本脚本的几何体积）--------------

func _build_chassis(heavy: bool, slim: bool) -> void:
	var tw: float = 0.62 if heavy else (0.46 if slim else 0.55)
	var th: float = 0.62
	var td: float = 0.42 if heavy else (0.34 if slim else 0.38)
	# 躯干主盒 + 前突胸甲。
	_add(_box(tw, th, td), _m_chassis, Vector3(0, 1.35, 0))
	_add(_box(tw * 1.02, 0.34, 0.10), _m_chassis, Vector3(0, 1.46, td * 0.5 + 0.04))
	# 腹甲。
	_add(_box(tw * 0.8, 0.26, td * 0.85), _m_chassis, Vector3(0, 0.98, 0))
	# 颈 / 传感头 + 头部 visor（青白 emissive 细缝，机甲「眼」）+ 头顶角。
	_add(_box(0.26, 0.22, 0.26), _m_chassis, Vector3(0, 1.92, 0))
	_add(_box(0.20, 0.05, 0.04), _m_faction, Vector3(0, 1.94, 0.14))
	_add(_box(0.04, 0.14, 0.04), _m_dark, Vector3(0.08, 2.12, 0))
	# 肩甲（宽肩职阶更宽）。
	var sw: float = 0.40 if heavy else (0.28 if slim else 0.34)
	_add(_box(sw, 0.20, 0.30), _m_chassis, Vector3(0.42, 1.60, 0))
	_add(_box(sw, 0.20, 0.30), _m_chassis, Vector3(-0.42, 1.60, 0))
	# 手臂：上臂 + 肘关节球 + 前臂 + 护腕 + 手（左右对称）。
	var ar: float = 0.10 if heavy else 0.08
	var lr: float = 0.12 if heavy else 0.09
	for side in [1.0, -1.0]:
		var sx: float = 0.55 * side
		_add(_cyl(ar, 0.5, "x"), _m_chassis, Vector3(sx, 1.46, 0), Vector3(0, 0, 90))
		_add(_sphere(ar * 1.2), _m_dark, Vector3(sx, 1.20, 0))
		_add(_cyl(ar, 0.42, "x"), _m_chassis, Vector3(sx, 0.98, 0), Vector3(0, 0, 90))
		_add(_box(ar * 2.2, 0.18, 0.18), _m_dark, Vector3(sx, 0.98, 0.02))
		_add(_box(0.12, 0.12, 0.12), _m_chassis, Vector3(sx, 0.78, 0))
	# 腿：大腿 + 膝关节球 + 小腿 + 胫甲 + 脚（左右对称）。
	for side in [1.0, -1.0]:
		var sx: float = 0.20 * side
		_add(_cyl(lr, 0.55), _m_chassis, Vector3(sx, 0.66, 0))
		_add(_sphere(lr * 1.2), _m_dark, Vector3(sx, 0.38, 0))
		_add(_cyl(lr, 0.5), _m_chassis, Vector3(sx, 0.16, 0))
		_add(_box(0.16, 0.30, 0.12), _m_dark, Vector3(sx, 0.14, 0.06))
		_add(_box(0.18, 0.10, 0.26), _m_chassis, Vector3(sx, 0.04, 0.08))


# 沿躯干/肩的发光共鸣回路 + 胸口动力核心（阵营结构色，全 8 台共用）。
func _build_conduits() -> void:
	_add(_box(0.06, 0.5, 0.04), _m_faction, Vector3(0, 1.35, 0.21))   # 胸竖条
	_add(_box(0.08, 0.16, 0.06), _m_faction, Vector3(0.42, 1.60, 0.16))
	_add(_box(0.08, 0.16, 0.06), _m_faction, Vector3(-0.42, 1.60, 0.16))
	# 胸口共鸣核心（青白发光球，机甲「动力核心」）。
	_add(SphereMesh.new(), _m_faction, Vector3(0, 1.5, 0.24))


# --- 八台专属剪影 + 识别件 -------------------------------------------------------

# BLADE 锋刃（ash_acolyte）：修长、单侧细剑；暖金刃锋 + 额心节点。
func _build_blade(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_box(0.06, 1.0, 0.12), _m_accent, Vector3(0.6, 1.25, 0.18), Vector3(0, 0, 8))
	_add(_cyl(0.16, 0.10, "z"), _m_chassis, Vector3(-0.42, 1.7, 0.1))
	_add(_box(0.06, 0.06, 0.04), _m_accent, Vector3(0, 2.02, 0.16))


# BLADE·断空剑主（voidblade_lord）：双交叉巨剑 + 非对称肩甲 + 黑金描边。
func _build_voidblade(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_box(0.05, 1.15, 0.10), _m_dark, Vector3(0.35, 1.35, 0.2), Vector3(0, 0, 35))
	_add(_box(0.04, 1.0, 0.08), _m_accent, Vector3(0.35, 1.4, 0.24), Vector3(0, 0, 35))
	_add(_box(0.05, 1.15, 0.10), _m_dark, Vector3(-0.35, 1.35, 0.2), Vector3(0, 0, -35))
	_add(_box(0.04, 1.0, 0.08), _m_accent, Vector3(-0.35, 1.4, 0.24), Vector3(0, 0, -35))
	_add(_box(0.30, 0.26, 0.34), _m_dark, Vector3(0.46, 1.66, 0))


# BULWARK 磐盾（oath_guard）：厚重、宽肩、单塔盾；苍穹蓝盾纹章。
func _build_bulwark(accent: Color) -> void:
	_build_chassis(true, false)
	_build_conduits()
	_add(_cyl(0.55, 0.10, "x"), _m_chassis, Vector3(-0.95, 1.3, 0.05), Vector3(0, 0, 90))
	_add(_cyl(0.22, 0.12, "x"), _m_accent, Vector3(-0.97, 1.3, 0.12), Vector3(0, 0, 90))
	_add(_box(0.34, 0.26, 0.34), _m_chassis, Vector3(0.46, 1.66, 0))


# BULWARK·磐心卫士（bulwark_heart）：胸口 twin-sphere 共鸣核心（脉冲）+ 短盾。
func _build_bulwark_heart(accent: Color) -> void:
	_build_chassis(true, false)
	_build_conduits()
	_add(_box(0.34, 0.5, 0.10), _m_chassis, Vector3(-0.78, 1.35, 0.08))
	_add(SphereMesh.new(), _m_accent, Vector3(0.12, 1.4, 0.22))
	_add(SphereMesh.new(), _m_accent, Vector3(-0.12, 1.4, 0.22))
	_pulse = true


# WINDCHASER 风追（swift_ranger base）：轻快流线、细腿、实体羽翼 + 长枪。
func _build_windchaser(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_cyl(0.04, 1.4), _m_chassis, Vector3(0.55, 1.2, 0.4), Vector3(80, 0, 0))
	_add(_box(0.12, 0.12, 0.12), _m_accent, Vector3(0.55, 1.2, 1.05))
	_add(_box(0.5, 0.06, 0.34), _m_accent, Vector3(0.45, 1.7, -0.25), Vector3(0, 0, 35))
	_add(_box(0.5, 0.06, 0.34), _m_accent, Vector3(-0.45, 1.7, -0.25), Vector3(0, 0, -35))


# WINDCHASER·疾风回响者（gale_echo）：半透发光翼 + 头顶光环（叠加于实翼 base）。
func _build_gale(accent: Color) -> void:
	_build_windchaser(accent)
	_add(_box(0.5, 0.05, 0.34), _m_wing, Vector3(0.45, 1.7, -0.25), Vector3(0, 0, 35))
	_add(_box(0.5, 0.05, 0.34), _m_wing, Vector3(-0.45, 1.7, -0.25), Vector3(0, 0, -35))
	var halo := TorusMesh.new()
	halo.inner_radius = 0.16
	halo.outer_radius = 0.24
	_add(halo, _m_accent, Vector3(0, 2.25, 0), Vector3(90, 0, 0))


# RESONANT 谐律（base）：胸中央环 + 球发光核心 + 青白。
func _build_resonant(accent: Color) -> void:
	_build_chassis(false, false)
	_build_conduits()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.2
	_add(ring, _m_accent, Vector3(0, 1.4, 0.22), Vector3(90, 0, 0))
	_add(SphereMesh.new(), _m_accent, Vector3(0, 1.4, 0.22))


# RESONANT·谐律主祭（hierophant）：大头光环 + 环杖。
func _build_hierophant(accent: Color) -> void:
	_build_resonant(accent)
	var halo := TorusMesh.new()
	halo.inner_radius = 0.3
	halo.outer_radius = 0.42
	_add(halo, _m_accent, Vector3(0, 2.45, 0), Vector3(90, 0, 0))
	_add(_cyl(0.04, 1.3), _m_chassis, Vector3(0.62, 1.3, 0.1))
	var staff_ring := TorusMesh.new()
	staff_ring.inner_radius = 0.1
	staff_ring.outer_radius = 0.16
	_add(staff_ring, _m_accent, Vector3(0.62, 1.95, 0.1), Vector3(90, 0, 0))


# RESONANT·共鸣歌者（singer）：胸前球核 + 发束头饰（珊瑚点缀）。
func _build_singer(accent: Color) -> void:
	_build_resonant(accent)
	_add(SphereMesh.new(), _m_accent, Vector3(0, 1.4, 0.24))
	_add(_box(0.05, 0.22, 0.05), _m_accent, Vector3(0.14, 2.15, 0), Vector3(20, 0, 0))
	_add(_box(0.05, 0.22, 0.05), _m_accent, Vector3(-0.14, 2.15, 0), Vector3(-20, 0, 0))


func _clear() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
	if _spin:
		rotation.y += delta * 0.8
	# 心核脉冲（仅磐心卫士/谐律主祭开启），呼应「心跳/吟唱」节奏。
	# ⚠ 本项目 Physical Light Units 未开，不能设 emission_intensity；
	# 故用 emissive 颜色亮度调制（glow 强度封顶，避免 bloom 过曝，见 art-bible §6.2）。
	if _pulse and _m_accent != null:
		var k: float = 0.7 + 0.3 * (0.5 + 0.5 * sin(_t * 3.0))
		_m_accent.emissive = _accent_base * k
