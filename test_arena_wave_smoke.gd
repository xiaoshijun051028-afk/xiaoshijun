extends Node
## 无头校验：arena_min 刷出真敌人、敌人会逼近到攻击距离、斩击能扣血、全程无报错。
## 运行：godot --headless --path . res://test_arena_wave_smoke.tscn
## 成功打印 "TEST_FINISHED_OK"；失败打印 "TEST_FAILED: ..." 并以错误码退出。

func _ready() -> void:
	var arena := ArenaMin.new()
	add_child(arena)
	await get_tree().physics_frame   # 让 _ready + 首帧跑完

	var ok := true
	var msgs := ""

	if arena.debug_enemy_count() < 1:
		ok = false; msgs += "场上无真敌人 "

	# 步进物理帧，让敌人逼近到攻击距离内（≤ ATTACK_RANGE）。
	var in_range := false
	for i in range(360):
		await get_tree().physics_frame
		var tgt = arena.debug_target()
		if tgt != null and arena.debug_player_pos().distance_to(tgt.global_position) <= 2.8:
			in_range = true
			break
	if not in_range:
		ok = false; msgs += "敌人未逼近/无目标 "

	# 斩击扣血校验
	var tgt = arena.debug_target()
	if tgt != null:
		var hp0: int = tgt.hp
		arena.debug_force_slash()
		if tgt.hp >= hp0:
			ok = false; msgs += "斩击未扣血 "
	else:
		ok = false; msgs += "无目标可斩 "

	if ok:
		print("TEST_FINISHED_OK")
		get_tree().quit(0)
	else:
		printerr("TEST_FAILED: " + msgs)
		get_tree().quit(1)
