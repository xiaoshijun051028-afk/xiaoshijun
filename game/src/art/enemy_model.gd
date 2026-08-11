class_name EnemyModel
extends Node3D
## 敌人样本模型（design/art/character-sample-models.md）。
## 全部使用 THREAT（#A62C6B，仅敌/混沌）或其 accent —— 严格守「THREAT 仅敌」铁律。
## sentinel 的弱点标记用 FRIENDLY_GOLD accent（非色编码另加菱形形状，满足可访问性 F1）。

const BOB_HEIGHT: float = 0.08
const BOB_SPEED: float = 1.2

var _base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	if get_child_count() == 0:
		build(&"brute")


func build(id: StringName) -> void:
	_clear()
	_build_silhouette(id)
	_base_y = position.y


func _mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.emissive_enabled = true
		m.emissive = color
	return m


func _add(mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
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


func _build_silhouette(id: StringName) -> void:
	match id:
		&"brute":          _build_brute()
		&"skirmisher":      _build_skirmisher()
		&"sentinel":        _build_sentinel()
		&"boss_warden":     _build_warden()
		&"dummy":           _build_dummy()
		_:                  _build_brute()


func _build_brute() -> void:
	_add(BoxMesh.new(), ColorTokens.THREAT, Vector3(0, 1.1, 0))


func _build_skirmisher() -> void:
	_add(CapsuleMesh.new(), ColorTokens.THREAT, Vector3(0, 1.0, 0))
	_add(_cone(0.3, 0.9), ColorTokens.THREAT, Vector3(0, 1.9, 0))
	_add(CylinderMesh.new(), ColorTokens.THREAT * 0.9, Vector3(0.2, 1.0, 0.6), Vector3(90, 0, 0))


func _build_sentinel() -> void:
	# 弱点标记：菱形（旋转 45° 的 Box）+ THREAT 本体；accent 用 FRIENDLY_GOLD 非色编码呼应。
	_add(CapsuleMesh.new(), ColorTokens.THREAT, Vector3(0, 1.0, 0))
	_add(BoxMesh.new(), ColorTokens.THREAT, Vector3(0, 2.1, 0), Vector3(45, 45, 0))
	_add(BoxMesh.new(), ColorTokens.FRIENDLY_GOLD, Vector3(0, 2.1, 0), Vector3(45, 45, 0), false)


func _build_warden() -> void:
	_add(BoxMesh.new(), ColorTokens.THREAT, Vector3(0, 1.6, 0))
	_add(SphereMesh.new(), ColorTokens.THREAT, Vector3(0.7, 2.6, 0))
	_add(SphereMesh.new(), ColorTokens.THREAT, Vector3(-0.7, 2.6, 0))
	_add(_cone(0.4, 0.8), ColorTokens.THREAT, Vector3(0, 3.3, 0), Vector3(0, 0, 0), true)


func _build_dummy() -> void:
	# 训练假人：中性灰（INACTIVE）表「非威胁」，FRIENDLY_GOLD 靶心表弱点练习点。
	_add(CapsuleMesh.new(), ColorTokens.INACTIVE, Vector3(0, 1.0, 0))
	_add(SphereMesh.new(), ColorTokens.FRIENDLY_GOLD, Vector3(0, 1.7, 0))


func _clear() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
