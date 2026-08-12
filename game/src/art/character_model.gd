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
## 精致化（2026-08-12）：分层装甲（外板 + 内衬 + 暗色描边）、锥形肢体、关节球、
## 面板发光缝（faction 细条）、背包 + 头冠/天线细节；材质提升金属度与粗糙度层次。
## 仍零外部资源、只走 ColorTokens（MECH_BASE 为本地权威常量，见下方说明）。
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

## 临时回退集合：5 台占位角色当前是 3 台真模型的字节级复制，先回退到各自专属程序化剪影避免撞脸。
## 8/13 真 AI 模型覆盖 game/assets/mecha/mecha_<id>.glb 后，把此数组置空 [] 即可让真模型生效（见 8/13 定时任务）。
const PROCEDURAL_FALLBACK_IDS: Array = [
	&"bulwark_heart", &"swift_ranger", &"gale_echo", &"resonant_hierophant", &"resonant_singer"
]

var _id: StringName = &""
var _base_y: float = 0.0
var _spin: bool = false
var _t: float = 0.0
var _pulse: bool = false

# 实例级材质缓存（控制材质数 ≤10）：chassis / trim / dark / faction / accent / wing。
var _m_chassis: StandardMaterial3D = null
var _m_trim: StandardMaterial3D = null
var _m_dark: StandardMaterial3D = null
var _m_faction: StandardMaterial3D = null
var _m_accent: StandardMaterial3D = null
var _m_wing: StandardMaterial3D = null
var _m_accent_soft: StandardMaterial3D = null
var _accent_base: Color = Color.WHITE  # 用于心核脉冲（调 emissive 颜色亮度，不碰 emission_intensity）


func _ready() -> void:
	if get_child_count() == 0:
		build(&"__player__")


## 按 character_id 构建样本模型；未知 id → 默认玩家剪影。
## 优先加载真机甲 GLB(game/assets/mecha/mecha_<id>.glb)；缺失则回退到程序化占位。
func build(id: StringName) -> void:
	_clear()
	_id = id
	var spec: Dictionary = _spec_for(id)
	_spin = spec.get("spin", false)
	var s: float = spec.get("scale", 1.0)
	var accent: Color = spec.get("accent", ColorTokens.RESONANCE_GLOW)
	# 临时：5 台占位角色（GLB 为复制件）回退到各自专属程序化剪影，避免与 3 台真模型撞脸。
	# 8/13 真 AI 模型覆盖 GLB 后，_is_procedural_pending 改回全 false 即失效。
	if not _is_procedural_pending(id) and _try_load_glb(id, accent):
		scale = Vector3(s, s, s)
		_base_y = position.y
		return
	_make_materials(accent)
	var builder: Callable = spec.get("builder", _build_blade)
	builder.call(accent)
	scale = Vector3(s, s, s)
	_base_y = position.y


## 临时判定：5 台占位角色当前用复制 GLB，先回退到各自专属程序化剪影避免撞脸。
## 8/13 真 AI 模型覆盖 game/assets/mecha/mecha_<id>.glb 后，把此函数体改为 `return false` 即可让真模型生效。
static func _is_procedural_pending(id: StringName) -> bool:
	match id:
		&"bulwark_heart", &"swift_ranger", &"gale_echo", &"resonant_hierophant", &"resonant_singer":
			return true
		_:
			return false


func _try_load_glb(id: StringName, accent: Color) -> bool:
	var path := "res://game/assets/mecha/mecha_%s.glb" % id
	if not FileAccess.file_exists(path):
		return false
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("CharacterModel: failed to load GLB %s" % path)
		return false
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	_normalize_glb(inst)
	_apply_accent(inst, accent)
	return true


func _normalize_glb(root: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var local_aabb := mi.get_aabb()
		var transformed := local_aabb * mi.transform
		if first:
			aabb = transformed
			first = false
		else:
			aabb = aabb.merge(transformed)
	if first:
		return
	var center := aabb.get_center()
	var size := aabb.size
	var max_size := maxf(size.x, maxf(size.y, size.z))
	if max_size <= 0.001:
		return
	var target_height: float = 2.0
	var s := target_height / max_size
	root.position = -center * s
	root.scale = Vector3(s, s, s)


func _apply_accent(root: Node3D, accent: Color) -> void:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var surf_count: int = mi.mesh.get_surface_count()
		for i in range(surf_count):
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate()
				dup.emission_enabled = true
				dup.emission = accent
				dup.emission_energy_multiplier = 1.4
				mi.set_surface_override_material(i, dup)


## 八台各路由到专属 builder（不再退化成四档通用剪影）。
## 用户试玩反馈（2026-08-12）：不同人物「特效要一样」。占位阶段取消职阶强调色差异，
## 所有机甲 accent emissive 统一为青白谐波虹膜 RESONANCE_GLOW，仅靠剪影区分职阶。
func _spec_for(id: StringName) -> Dictionary:
	match id:
		&"ash_acolyte":         return {"builder": _build_blade,         "accent": accent_of(id)}
		&"voidblade_lord":      return {"builder": _build_voidblade,    "accent": accent_of(id)}
		&"oath_guard":          return {"builder": _build_bulwark,      "accent": accent_of(id)}
		&"bulwark_heart":       return {"builder": _build_bulwark_heart,"accent": accent_of(id)}
		&"swift_ranger":        return {"builder": _build_windchaser,   "accent": accent_of(id)}
		&"gale_echo":           return {"builder": _build_gale,         "accent": accent_of(id)}
		&"resonant_hierophant": return {"builder": _build_hierophant,   "accent": accent_of(id)}
		&"resonant_singer":     return {"builder": _build_singer,       "accent": accent_of(id)}
		_:                      return {"builder": _build_blade,         "accent": accent_of(id)}


## 角色签名色查询（单一真相源）：模型与 CombatVFX 共用，确保「同一角色模型与特效同色」。
## 默认 ash_acolyte 旭金（未知 id 兜底）。
static func accent_of(id: StringName) -> Color:
	match id:
		&"ash_acolyte":         return ColorTokens.ACCENT_ASH
		&"voidblade_lord":      return ColorTokens.ACCENT_VOID
		&"oath_guard":          return ColorTokens.ACCENT_OATH
		&"bulwark_heart":       return ColorTokens.ACCENT_HEART
		&"swift_ranger":        return ColorTokens.ACCENT_RANGER
		&"gale_echo":           return ColorTokens.ACCENT_GALE
		&"resonant_hierophant": return ColorTokens.ACCENT_HIEROPHANT
		&"resonant_singer":     return ColorTokens.ACCENT_SINGER
		_:                      return ColorTokens.ACCENT_ASH


# --- 材质（例程级缓存，整机甲共享 ≤6 个材质实例）-----------------------------------

func _make_materials(accent: Color) -> void:
	_accent_base = accent
	_m_chassis = _mat(MECH_BASE, false, 0.70, 0.42)                 # 主装甲：金属感
	_m_chassis.clearcoat = 0.35
	_m_chassis.clearcoat_roughness = 0.35
	_m_trim    = _mat(MECH_BASE.lightened(0.28), false, 0.88, 0.28)  # 外衬亮板：更高金属/更低粗糙 + 清漆层
	_m_trim.clearcoat = 0.65
	_m_trim.clearcoat_roughness = 0.22
	_m_dark    = _mat(MECH_BASE * 0.5, false, 0.55, 0.62)            # 关节/暗描边
	_m_faction = _mat(ColorTokens.PLAYER_ALLY_MAIN, true, 0.20, 0.5) # 共鸣回路（发青白）
	_m_accent  = _mat(accent, true, 0.30, 0.40)                      # 识别件（统一青白）
	_m_wing    = _mat(ColorTokens.RESONANCE_GLOW, true, 0.0, 0.4, true)  # 半透发光翼
	_m_accent_soft = _mat(accent, true, 0.0, 0.4, true)             # 贴地能量盘（半透发光，呼吸由 _process 调制）


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


# 细长盒（肢体/装甲板通用）。
func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


# 圆柱（肢体段 / 盾）。axis 仅作占位（CylinderMesh 轴固定 Y，靠 rot 调向）。
func _cyl(radius: float, height: float, axis: String = "y") -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	if axis == "x":
		c.radial_segments = 8
	return c


# 锥形柱（肢体，顶端/底端不同半径 → 更有「机械肢体」收分）。
func _taper(rt: float, rb: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = height
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


# 圆环（头冠 / 胸徽 / 法杖环）。默认环面在 XY 平面、孔轴=Z（正对镜头）；rot x=90 则平躺成光环。
func _torus(ri: float, ro: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	return t


# 扁平能量盘（贴地 / 底座光晕）。
func _disc(r: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.02
	return c


# --- 通用 chassis（四职阶共用机身结构；剪影差异只靠本脚本的几何体积）--------------

func _build_chassis(heavy: bool, slim: bool) -> void:
	var tw: float = 0.62 if heavy else (0.46 if slim else 0.55)
	var td: float = 0.42 if heavy else (0.34 if slim else 0.38)
	var sw: float = 0.42 if heavy else (0.30 if slim else 0.36)

	# 躯干：骨盆 → 腹甲 → 下胸 → 上胸双片 → 锁骨，分层拼装甲感。
	_add(_box(tw * 0.85, 0.28, td * 0.80), _m_chassis, Vector3(0, 0.86, 0))
	_add(_box(tw * 0.80, 0.30, td * 0.78), _m_chassis, Vector3(0, 1.12, 0))
	_add(_box(tw, 0.26, td), _m_trim, Vector3(0, 1.40, 0.02))            # 下胸外亮板
	_add(_box(tw * 0.52, 0.30, td * 0.62), _m_chassis, Vector3(0.20 * tw, 1.62, 0))  # 右胸片
	_add(_box(tw * 0.52, 0.30, td * 0.62), _m_chassis, Vector3(-0.20 * tw, 1.62, 0)) # 左胸片
	_add(_box(tw * 0.92, 0.12, td * 0.70), _m_trim, Vector3(0, 1.80, 0))  # 锁骨亮条

	# 颈 + 传感头（小头更「机甲」）+ 青白 visor 细缝 + 头顶冠。
	_add(_cyl(0.09, 0.16), _m_dark, Vector3(0, 1.90, 0))
	_add(_box(0.22, 0.26, 0.22), _m_chassis, Vector3(0, 2.06, 0))
	_add(_box(0.18, 0.05, 0.05), _m_faction, Vector3(0, 2.07, 0.12))     # visor 发光缝
	_add(_box(0.05, 0.16, 0.05), _m_dark, Vector3(0, 2.24, 0))           # 头冠

	# 背包（增加纵深）+ 双 vents 发光。
	_add(_box(tw * 0.70, 0.50, 0.12), _m_dark, Vector3(0, 1.50, -td * 0.6))
	_add(_box(0.04, 0.30, 0.02), _m_accent, Vector3(0.10, 1.50, -td * 0.66))
	_add(_box(0.04, 0.30, 0.02), _m_accent, Vector3(-0.10, 1.50, -td * 0.66))

	# 肩甲：球节 + 外板 + 亮衬 + accent 条（分层）。
	for side in [1.0, -1.0]:
		var sx: float = 0.50 * side
		_add(_sphere(0.14), _m_dark, Vector3(sx, 1.66, 0))
		_add(_box(sw, 0.22, 0.34), _m_chassis, Vector3(sx, 1.70, 0))
		_add(_box(sw * 0.70, 0.10, 0.30), _m_trim, Vector3(sx, 1.80, 0.02))
		_add(_box(0.05, 0.18, 0.30), _m_accent, Vector3(sx, 1.70, 0.18))

	# 手臂：上臂(锥) + 肘球 + 前臂(锥) + 护腕 + 手（左右对称）。
	for side in [1.0, -1.0]:
		var sx: float = 0.55 * side
		_add(_taper(0.10, 0.13, 0.50), _m_chassis, Vector3(sx, 1.42, 0), Vector3(0, 0, 90))
		_add(_sphere(0.11), _m_dark, Vector3(sx, 1.18, 0))
		_add(_taper(0.09, 0.11, 0.42), _m_chassis, Vector3(sx, 0.96, 0), Vector3(0, 0, 90))
		_add(_box(0.24, 0.18, 0.18), _m_dark, Vector3(sx, 0.96, 0.03))   # 护腕暗甲
		_add(_box(0.05, 0.16, 0.16), _m_accent, Vector3(sx, 0.96, 0.12)) # 护腕发光条
		_add(_box(0.12, 0.14, 0.12), _m_chassis, Vector3(sx, 0.74, 0))

	# 腿：大腿(锥) + 膝甲 + 膝发光 + 小腿(锥) + 胫甲 + 脚（左右对称）。
	for side in [1.0, -1.0]:
		var sx: float = 0.20 * side
		_add(_taper(0.13, 0.16, 0.55), _m_chassis, Vector3(sx, 0.60, 0))
		_add(_box(0.18, 0.16, 0.16), _m_trim, Vector3(sx, 0.34, 0.06))    # 膝甲亮板
		_add(_box(0.06, 0.10, 0.14), _m_accent, Vector3(sx, 0.34, 0.14)) # 膝发光
		_add(_taper(0.10, 0.13, 0.50), _m_chassis, Vector3(sx, 0.12, 0))
		_add(_box(0.16, 0.26, 0.14), _m_dark, Vector3(sx, 0.10, 0.05))   # 胫甲暗甲
		_add(_box(0.18, 0.10, 0.28), _m_chassis, Vector3(sx, 0.0, 0.08)) # 脚

	# 腰封（签名色发光束，收束躯干与腿过渡，增加精致度）。
	_add(_box(tw * 0.92, 0.10, td * 0.92), _m_accent, Vector3(0, 0.82, 0.02))
	# 脚底光环（签名色贴地环，接地 + 预览展示底座感）。
	_add(_torus(0.50, 0.64), _m_accent, Vector3(0, 0.03, 0), Vector3(90, 0, 0))
	# 颈环 + 胸口签名色徽记（环+核，覆于共鸣核心之上，强化阵营识别）。
	_add(_torus(0.10, 0.16), _m_trim, Vector3(0, 1.86, 0), Vector3(90, 0, 0))
	_add(_torus(0.10, 0.16), _m_accent, Vector3(0, 1.50, 0.30))
	_add(_sphere(0.07), _m_accent, Vector3(0, 1.50, 0.32))
	# 躯干前缘发光肋（签名色细条，模拟边缘光）。
	_add(_box(0.03, 0.66, 0.03), _m_accent, Vector3(0.24 * tw, 1.45, 0.27))
	_add(_box(0.03, 0.66, 0.03), _m_accent, Vector3(-0.24 * tw, 1.45, 0.27))
	# 髋甲（骨盆两侧贴片，强化装甲层叠）。
	_add(_box(0.14, 0.20, 0.16), _m_trim, Vector3(0.22 * tw, 0.78, 0.06))
	_add(_box(0.14, 0.20, 0.16), _m_trim, Vector3(-0.22 * tw, 0.78, 0.06))
	# 边缘自发光描边（签名色细线勾边，强化「机甲被签名色勾轮廓」的精致感）。
	_add(_box(0.03, 1.0, 0.03), _m_accent, Vector3(0.50 * tw, 1.35, 0.0))   # 躯干左缘
	_add(_box(0.03, 1.0, 0.03), _m_accent, Vector3(-0.50 * tw, 1.35, 0.0))  # 躯干右缘
	_add(_box(sw, 0.04, 0.34), _m_accent, Vector3(0.50, 1.84, 0.0))          # 左肩顶描边
	_add(_box(sw, 0.04, 0.34), _m_accent, Vector3(-0.50, 1.84, 0.0))         # 右肩顶描边
	_add(_box(0.03, 0.42, 0.03), _m_accent, Vector3(0.35, 0.40, 0.0))        # 左大腿外侧
	_add(_box(0.03, 0.42, 0.03), _m_accent, Vector3(-0.35, 0.40, 0.0))       # 右大腿外侧
	# 贴地能量盘（签名色半透发光，接地 + 预览底座感）。
	_add(_disc(0.72), _m_accent_soft, Vector3(0, 0.015, 0))


# 沿躯干/肩/腿的发光共鸣回路（面板缝）+ 胸口动力核心（阵营结构色，全 8 台共用）。
func _build_conduits() -> void:
	_add(_box(0.05, 0.50, 0.03), _m_faction, Vector3(0, 1.50, 0.23))    # 胸竖缝
	_add(_box(0.40, 0.04, 0.04), _m_faction, Vector3(0, 1.80, 0.24))    # 锁骨横缝
	_add(_box(0.04, 0.40, 0.03), _m_faction, Vector3(0.22, 0.55, 0.16)) # 右腿缝
	_add(_box(0.04, 0.40, 0.03), _m_faction, Vector3(-0.22, 0.55, 0.16)) # 左腿缝
	_add(_sphere(0.12), _m_faction, Vector3(0, 1.50, 0.27))             # 胸口动力核心


# --- 八台专属剪影 + 识别件 -------------------------------------------------------

# BLADE 锋刃（ash_acolyte）：修长、单侧细剑（锥刃+护手+握柄）+ 额心节点。
func _build_blade(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_cyl(0.04, 0.30), _m_dark, Vector3(0.62, 1.00, 0.10))           # 握柄
	_add(_box(0.22, 0.05, 0.06), _m_trim, Vector3(0.62, 1.15, 0.10))     # 护手
	_add(_taper(0.02, 0.09, 1.10), _m_accent, Vector3(0.62, 1.70, 0.12), Vector3(0, 0, 8))  # 锥刃
	_add(_box(0.02, 0.95, 0.02), _m_accent, Vector3(0.62, 1.66, 0.15), Vector3(0, 0, 8))     # 刃脊发光线
	_add(_box(0.05, 0.05, 0.04), _m_accent, Vector3(0, 2.16, 0.14))     # 额心节点


# BLADE·断空剑主（voidblade_lord）：双交叉巨剑（暗刃+青白锋缘）+ 非对称大肩甲。
func _build_voidblade(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_box(0.05, 1.20, 0.10), _m_dark, Vector3(0.30, 1.40, 0.20), Vector3(0, 0, 35))   # 左巨剑身
	_add(_box(0.03, 1.00, 0.06), _m_accent, Vector3(0.30, 1.45, 0.25), Vector3(0, 0, 35)) # 左锋缘
	_add(_box(0.05, 1.20, 0.10), _m_dark, Vector3(-0.30, 1.40, 0.20), Vector3(0, 0, -35)) # 右巨剑身
	_add(_box(0.03, 1.00, 0.06), _m_accent, Vector3(-0.30, 1.45, 0.25), Vector3(0, 0, -35)) # 右锋缘
	_add(_box(0.34, 0.30, 0.36), _m_dark, Vector3(0.50, 1.70, 0))       # 非对称大肩甲


# BULWARK 磐盾（oath_guard）：厚重、宽肩、单塔盾（盾面+亮边+青白徽核）。
func _build_bulwark(accent: Color) -> void:
	_build_chassis(true, false)
	_build_conduits()
	_add(_cyl(0.50, 0.12), _m_chassis, Vector3(-0.95, 1.30, 0.05), Vector3(0, 0, 90))
	_add(_cyl(0.52, 0.14), _m_trim, Vector3(-0.95, 1.30, 0.03), Vector3(0, 0, 90))  # 盾亮边
	_add(_box(0.22, 0.22, 0.04), _m_accent, Vector3(-0.97, 1.30, 0.13))             # 徽核
	_add(_box(0.12, 0.12, 0.05), _m_dark, Vector3(-0.97, 1.30, 0.14))               # 徽心
	_add(_box(0.34, 0.26, 0.34), _m_dark, Vector3(0.46, 1.66, 0))                   # 加厚右肩


# BULWARK·磐心卫士（bulwark_heart）：胸口 twin-sphere 共鸣核心（脉冲）+ 短盾。
func _build_bulwark_heart(accent: Color) -> void:
	_build_chassis(true, false)
	_build_conduits()
	_add(_box(0.34, 0.50, 0.08), _m_chassis, Vector3(-0.78, 1.35, 0.08))   # 短盾
	_add(_sphere(0.14), _m_accent, Vector3(0.12, 1.55, 0.28))              # 左心核
	_add(_sphere(0.14), _m_accent, Vector3(-0.12, 1.55, 0.28))             # 右心核
	_pulse = true


# WINDCHASER 风追（swift_ranger base）：轻快流线、细腿、实体羽翼 + 长枪（锥杆+尖）。
func _build_windchaser(accent: Color) -> void:
	_build_chassis(false, true)
	_build_conduits()
	_add(_taper(0.03, 0.03, 1.60), _m_chassis, Vector3(0.55, 1.20, 0.35), Vector3(80, 0, 0)) # 枪杆
	_add(_box(0.02, 1.40, 0.02), _m_accent, Vector3(0.55, 1.20, 0.40), Vector3(80, 0, 0))   # 枪杆发光线
	_add(_box(0.10, 0.10, 0.10), _m_accent, Vector3(0.55, 1.20, 1.05))                      # 枪尖
	_add(_box(0.50, 0.06, 0.34), _m_accent, Vector3(0.45, 1.70, -0.25), Vector3(0, 0, 35))  # 右羽翼
	_add(_box(0.50, 0.06, 0.34), _m_accent, Vector3(-0.45, 1.70, -0.25), Vector3(0, 0, -35)) # 左羽翼


# WINDCHASER·疾风回响者（gale_echo）：半透发光翼 + 头顶光环（叠加于实翼 base）。
func _build_gale(accent: Color) -> void:
	_build_windchaser(accent)
	_add(_box(0.50, 0.05, 0.34), _m_wing, Vector3(0.45, 1.70, -0.25), Vector3(0, 0, 35))
	_add(_box(0.50, 0.05, 0.34), _m_wing, Vector3(-0.45, 1.70, -0.25), Vector3(0, 0, -35))
	_add(_torus(0.16, 0.24), _m_accent, Vector3(0, 2.30, 0), Vector3(90, 0, 0))  # 头顶光环


# RESONANT 谐律（base）：胸中央环 + 球发光核心 + 青白。
func _build_resonant(accent: Color) -> void:
	_build_chassis(false, false)
	_build_conduits()
	_add(_torus(0.13, 0.20), _m_accent, Vector3(0, 1.50, 0.26))   # 胸环（正对镜头）
	_add(_sphere(0.12), _m_accent, Vector3(0, 1.50, 0.26))


# RESONANT·谐律主祭（hierophant）：大头光环 + 环杖 + 下摆裙甲。
func _build_hierophant(accent: Color) -> void:
	_build_resonant(accent)
	_add(_torus(0.30, 0.42), _m_accent, Vector3(0, 2.45, 0), Vector3(90, 0, 0))  # 大头光环
	_add(_cyl(0.04, 1.30), _m_chassis, Vector3(0.62, 1.30, 0.10))                # 法杖杆
	_add(_torus(0.10, 0.16), _m_accent, Vector3(0.62, 1.95, 0.10), Vector3(90, 0, 0)) # 杖环
	_add(_box(0.55, 0.40, 0.40), _m_trim, Vector3(0, 0.70, 0))                   # 下摆裙甲


# RESONANT·共鸣歌者（singer）：胸前球核 + 发束头饰（青白）+ 浮游小球。
func _build_singer(accent: Color) -> void:
	_build_resonant(accent)
	_add(_sphere(0.14), _m_accent, Vector3(0, 1.50, 0.28))
	_add(_box(0.05, 0.22, 0.05), _m_accent, Vector3(0.14, 2.18, 0), Vector3(20, 0, 0))  # 右发束
	_add(_box(0.05, 0.22, 0.05), _m_accent, Vector3(-0.14, 2.18, 0), Vector3(-20, 0, 0)) # 左发束
	_add(_sphere(0.06), _m_accent, Vector3(0.32, 1.90, 0.20))                           # 浮游球
	_add(_sphere(0.06), _m_accent, Vector3(-0.32, 1.90, 0.20))


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
	# 共鸣回路呼吸（全角色）：青白能量条轻微明灭，赋予机体「活着」的质感。
	if _m_faction != null:
		var kf: float = 0.65 + 0.25 * (0.5 + 0.5 * sin(_t * 2.2))
		_m_faction.emissive = ColorTokens.PLAYER_ALLY_MAIN * kf
	# 贴地能量盘呼吸（全角色）：签名色光晕缓明缓暗，强化底座存在感。
	if _m_accent_soft != null:
		var ks: float = 0.5 + 0.3 * (0.5 + 0.5 * sin(_t * 1.5))
		_m_accent_soft.emissive = _accent_base * ks
	# 心核脉冲（仅磐心卫士/谐律主祭）：签名色整体随「心跳/吟唱」强脉冲。
	if _pulse and _m_accent != null:
		var k: float = 0.7 + 0.3 * (0.5 + 0.5 * sin(_t * 3.0))
		_m_accent.emissive = _accent_base * k
