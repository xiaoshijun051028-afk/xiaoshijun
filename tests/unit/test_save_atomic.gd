extends GdUnitTestSuite
## S8 存档 · 原子写盘 / 读档还原（依赖 SaveManager Autoload #4 与文件系统）
##
## 覆盖 AC-S8-01（还原）、AC-S8-04（写盘失败不崩的落盘侧）、ADR-002（常量不入档）。
## 文件 IO 走 user://（headless 下为临时目录），每次 before_test 清场隔离。

func before_test() -> void:
	SaveManager.reset_for_test()
	ResonancePool.reset_for_test(50)


func after_test() -> void:
	SaveManager.reset_for_test()
	ResonancePool.reset_for_test(50)


func test_save_and_load_roundtrip() -> void:
	ResonancePool.reset_for_test(42)
	var ok := SaveManager.save_at_shrine(&"hub_shrine")
	assert_bool(ok).is_true()
	ResonancePool.reset_for_test(0)   # 模拟重启：内存池清零
	var loaded := SaveManager.load_game()
	assert_bool(loaded).is_true()
	assert_int(ResonancePool.current).is_equal(42)


func test_save_file_contains_no_constants() -> void:
	SaveManager.save_at_shrine(&"hub")
	var f := FileAccess.open(SaveManager.save_path(), FileAccess.READ)
	assert_object(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	for key: String in SaveModel.FORBIDDEN_KEYS:
		assert_bool(text.contains(key)).is_false()


func test_load_missing_file_is_new_game_not_error() -> void:
	# 清场后无存档文件 → load_game 应视为新游戏（池=初始值），不报错不崩。
	var loaded := SaveManager.load_game()
	assert_bool(loaded).is_true()
	assert_int(ResonancePool.current).is_equal(GameConstants.RESONANCE_INITIAL)
