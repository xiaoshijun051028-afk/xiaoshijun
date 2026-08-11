class_name CharacterModel
extends Node3D
## 卡池角色样本模型（design/art/character-sample-models.md）。
## 用 Godot 基元（Capsule / Box / Cylinder / Sphere / Cone / Torus）+ StandardMaterial3D
## 拼出差异化剪影；不依赖外部 .glb（v1 共用骨骼前的占位，但已具辨识度）。
## 配色严格引用 ColorTokens，**绝不**使用 THREAT（仅敌/混沌专属）。
## 播放确定性 idle（轻微上下 bob + 自转），不依赖动画集。

const BOB_HEIGHT: float = 0.10
const BOB_SPEED: float = 1.6

var _base_y: float = 0.0
var _spin: bool = false
var _t: float = 0.0


func _ready() -> void:
	if get_child_count() == 0:
		build(&"__player__")


## 按 character_id 构建样本模型；未知 id → 默认玩家剪影。
func build(id: StringName) -> void:
	_clear()
	var spec: Dictionary = _spec_for(id)
	var color: Color = spec.get("color", ColorTokens.PLAYER_ALLY_MAIN)
	var emissive: bool = spec.get("emissive", false)
	_spin = spec.get("spin", false)
	var s: float = spec.get("scale", 1.0)
	_build_silhouette(spec.get("kind", &"player"), color, emissive)
	scale = Vector3(s, s, s)
	_base_y = position.y


func _spec_for(id: StringName) -> Dictionary:
	match id:
		&"ash_acolyte":        return {"kind": &"ash_acolyte",        "color": ColorTokens.FRIENDLY_GOLD,                 "scale": 1.00}
		&"oath_guard":         return {"kind": &"oath_guard",         "color": ColorTokens.SKY_AZURE,                     "scale": 1.15}
		&"swift_ranger":       return {"kind": &"swift_ranger",       "color": ColorTokens.FRIENDLY_CORAL,                 "scale": 0.95}
		&"gale_echo":          return {"kind": &"gale_echo",          "color": ColorTokens.RESONANCE_GLOW,                 "scale": 0.95, "emissive": true}
		&"bulwark_heart":      return {"kind": &"bulwark_heart",      "color": ColorTokens.SKY_AZURE * 0.6,                "scale": 1.15}
		&"resonant_hierophant":return {"kind": &"resonant_hierophant", "color": ColorTokens.RESONANCE_GLOW,                 "scale": 1.05, "emissive": true}
		&"voidblade_lord":     return {"kind": &"voidblade_lord",     "color": ColorTokens.FRIENDLY_GOLD * 0.6,            "scale": 1.00}
		&"resonant_singer":    return {"kind": &"resonant_singer",    "color": ColorTokens.RESONANCE_GLOW * 0.85,          "scale": 1.00, "emissive": true}
		_:                     return {"kind": &"player",             "color": ColorTokens.PLAYER_ALLY_MAIN,              "scale": 1.00}


func _build_silhouette(kind: StringName, color: Color, emissive: bool) -> void:
	match kind:
		&"player":             _build_player(color)
		&"ash_acolyte":        _build_ash(color)
		&"oath_guard":         _build_oath(color)
		&"swift_ranger":       _build_swift(color)
		&"gale_echo":          _build_gale(color, emissive)
		&"bulwark_heart":      _build_bulwark_heart(color)
		&"resonant_hierophant":_build_hierophant(color, emissive)
		&"voidblade_lord":     _build_voidblade(color)
		&"resonant_singer":    _build_singer(color, emissive)


# --- 通用基元助手 -----------------------------------------------------------

func _mat(color: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.emissive_enabled = true
		m.emissive = color
		m.metallic = 0.0
		m.roughness = 0.4
	return m


func _add(mesh: Mesh, color: Color, emissive: bool, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emissive)
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


# Godot 4 无 ConeMesh，用 CylinderMesh + top_radius=0 顶替（apex 朝上，等价圆锥）。
func _cone(bottom_radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = bottom_radius
	c.height = height
	return c


# --- 剪影们（基元拼装）------------------------------------------------------

func _build_player(color: Color) -> void:
	_add(CapsuleMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(SphereMesh.new(), color, false, Vector3(0, 1.85, 0))
	_add(CylinderMesh.new(), color, false, Vector3(0.55, 1.0, 0), Vector3(0, 0, 90))
	_add(CylinderMesh.new(), color, false, Vector3(-0.55, 1.0, 0), Vector3(0, 0, 90))


func _build_ash(color: Color) -> void:
	_add(CapsuleMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(_cone(0.5, 0.9), color * 1.1, false, Vector3(0, 1.95, 0))
	_add(BoxMesh.new(), color * 0.8, false, Vector3(0.45, 1.0, 0.1), Vector3(0, 0, 20))


func _build_oath(color: Color) -> void:
	_add(BoxMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(SphereMesh.new(), color * 1.15, false, Vector3(0.5, 1.7, 0))
	_add(SphereMesh.new(), color * 1.15, false, Vector3(-0.5, 1.7, 0))
	_add(CylinderMesh.new(), color * 0.7, false, Vector3(-0.75, 1.0, 0.1), Vector3(0, 0, 90))


func _build_swift(color: Color) -> void:
	_add(CapsuleMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(_cone(0.4, 0.9), color, false, Vector3(0.5, 1.6, -0.2), Vector3(90, 0, 30))
	_add(_cone(0.4, 0.9), color, false, Vector3(-0.5, 1.6, -0.2), Vector3(90, 0, -30))
	_add(CylinderMesh.new(), color * 0.9, false, Vector3(0.25, 0.9, 0.6), Vector3(90, 0, 0))


func _build_gale(color: Color, emissive: bool) -> void:
	_add(CapsuleMesh.new(), color, emissive, Vector3(0, 1.0, 0))
	_add(BoxMesh.new(), color, emissive, Vector3(0.7, 1.2, -0.1), Vector3(0, 0, 70))
	_add(BoxMesh.new(), color, emissive, Vector3(-0.7, 1.2, -0.1), Vector3(0, 0, -70))
	_add(TorusMesh.new(), color, emissive, Vector3(0, 1.95, 0), Vector3(90, 0, 0))


func _build_bulwark_heart(color: Color) -> void:
	_add(BoxMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(SphereMesh.new(), color * 1.2, false, Vector3(0.3, 1.5, 0.2))
	_add(SphereMesh.new(), color * 1.2, false, Vector3(-0.3, 1.5, 0.2))
	_add(CylinderMesh.new(), color * 0.7, false, Vector3(-0.7, 1.0, 0.1), Vector3(0, 0, 90))


func _build_hierophant(color: Color, emissive: bool) -> void:
	_add(CapsuleMesh.new(), color, emissive, Vector3(0, 1.0, 0))
	_add(TorusMesh.new(), color, emissive, Vector3(0, 2.0, 0), Vector3(90, 0, 0))
	_add(TorusMesh.new(), color * 0.8, emissive, Vector3(0.3, 1.0, 0.4), Vector3(0, 0, 90))


func _build_voidblade(color: Color) -> void:
	_add(CapsuleMesh.new(), color, false, Vector3(0, 1.0, 0))
	_add(BoxMesh.new(), color, false, Vector3(0.45, 1.0, 0.3), Vector3(0, 0, 30))
	_add(BoxMesh.new(), color, false, Vector3(-0.45, 1.0, 0.3), Vector3(0, 0, -30))


func _build_singer(color: Color, emissive: bool) -> void:
	_add(CapsuleMesh.new(), color, emissive, Vector3(0, 1.0, 0))
	_add(SphereMesh.new(), color * 1.1, false, Vector3(0, 1.9, 0))
	_add(SphereMesh.new(), color, emissive, Vector3(0, 1.0, 0.35))


func _clear() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
	if _spin:
		rotation.y += delta * 0.8
