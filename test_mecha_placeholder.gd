extends Node
## 无头校验：确认 character_model.gd 升级后对外接口未变、能生成 8 角色无报错。
## 运行：godot --headless --path . res://test_mecha_placeholder.tscn
## 成功会在 stdout 打印 "TEST_FINISHED_OK"；任何失败打印 "TEST_FAILED: ..." 并以错误码退出。

const IDS := [
	&"ash_acolyte", &"voidblade_lord", &"oath_guard", &"bulwark_heart",
	&"swift_ranger", &"gale_echo", &"resonant_hierophant", &"resonant_singer",
	&"__player__",
]


func _ready() -> void:
	var ok := true
	var summary := ""
	for id in IDS:
		var m := CharacterModel.new()
		add_child(m)
		m.build(id)
		var meshes := 0
		# GLB 模型网格嵌套在导入场景根下，需递归统计(owned=false 才能跨 PackedScene 所有权)。
		# 材质可能在 material_override 或 surface_override。
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var has_mat := false
			if mi.material_override != null:
				has_mat = true
			else:
				for s in range(mi.mesh.get_surface_count()):
					if mi.get_active_material(s) != null:
						has_mat = true
						break
			if not has_mat:
				ok = false
				printerr("TEST_FAILED: %s 子节点缺少 material" % id)
				break
			meshes += 1
		print("COUNT %s = %d" % [id, meshes])
		if meshes < 1:
			ok = false
			printerr("TEST_FAILED: %s 几何过少 (%d)" % [id, meshes])
		if not ok:
			break
		summary += "%s=%d " % [id, meshes]

	if ok:
		print("TEST_FINISHED_OK  (%s)" % summary)
	else:
		print("TEST_FAILED")
		get_tree().quit(1)
	get_tree().quit(0)
