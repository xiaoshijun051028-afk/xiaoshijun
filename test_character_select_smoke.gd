extends Node
## 无头校验：CharacterSelect 能列出已拥有角色、自动选中、点卡片切换、出战写入生效。
## 运行：godot --headless --path . res://test_character_select_smoke.tscn
## 成功打印 "TEST_FINISHED_OK"；失败打印 "TEST_FAILED: ..." 并以错误码退出。

func _ready() -> void:
	var cs := CharacterSelect.new()
	add_child(cs)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var ok := true
	var msgs := ""

	if cs._owned.size() < 1:
		ok = false; msgs += "无角色卡片 "
	if cs._selected == null:
		ok = false; msgs += "未自动选中 "
	if cs._cards.size() != cs._owned.size():
		ok = false; msgs += "卡片数与拥有数不一致 "

	# 模拟选第一张并确认写入出战
	if cs._owned.size() >= 1:
		var pick: CharacterInstance = cs._owned[0]
		cs._on_card_pressed(pick)
		if cs._selected != pick:
			ok = false; msgs += "点卡片未切换选中 "
		RosterAutoload.set_active(pick.character_id)
		if RosterAutoload.get_active() != pick:
			ok = false; msgs += "出战写入失败 "

	if ok:
		print("TEST_FINISHED_OK")
		get_tree().quit(0)
	else:
		printerr("TEST_FAILED: " + msgs)
		get_tree().quit(1)
