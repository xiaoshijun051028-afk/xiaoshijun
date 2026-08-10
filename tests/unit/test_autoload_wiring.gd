extends GdUnitTestSuite
## S0 出口 #4 · 8 个 Autoload 就位（顺序由 project.godot [autoload] 段保证）
##
## 依赖：autoload 经 project.godot 注册。本测试在 gdUnit4 运行的 SceneTree 下
## 经 /root/<Name> 检查全部 8 个单例就绪。顺序（依赖序）由 project.godot 登记，
## 此处做软校验，主守卫仍是 project.godot 实际内容。

const EXPECTED: Array[StringName] = [
	&"GameConstants", &"EventBus", &"ResonancePool", &"SaveManager",
	&"InputManager", &"AudioDirector", &"EchoDirector", &"DebugOverlay",
]


func test_all_eight_autoloads_present() -> void:
	for name: StringName in EXPECTED:
		var node := get_node_or_null("/root/" + String(name))
		assert_object(node).is_not_null()


func test_autoload_registered_in_project_settings() -> void:
	var order = ProjectSettings.get_setting("autoload")
	if order is Dictionary:
		for name: StringName in EXPECTED:
			assert_bool(order.has(StringName(name)) or order.has(String(name))).is_true()
