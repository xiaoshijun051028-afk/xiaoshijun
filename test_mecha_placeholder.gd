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
		for c in m.get_children():
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
				if mi.mesh == null or mi.material_override == null:
					ok = false
					printerr("TEST_FAILED: %s 子节点缺少 mesh/material" % id)
					break
				meshes += 1
		print("COUNT %s = %d" % [id, meshes])
		# 机甲占位至少应拼出 chassis（≥18 个图元）。
		if meshes < 18:
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
