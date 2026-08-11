extends GdUnitTestSuite
## S9 UI · 抽卡面板逻辑（headless 不验视觉，只验按钮回调→抽卡→刷新文本）。

func _make() -> GachaPanel:
	var panel := GachaPanel.new()
	panel._roster_override = RosterService.new()
	add_child(panel)   # _ready 构建 UI
	return panel


func test_panel_single_pull_increments_owned_and_refreshes() -> void:
	var panel := _make()
	var before: int = panel._get_roster().owned_count()
	panel._on_pull_pressed()
	assert_int(panel._get_roster().owned_count()).is_equal(before + 1)
	assert_bool(panel._result_label.text.length() > 0).is_true()
	# 单抽只显示 1 行结果
	assert_int(panel._last_results.size()).is_equal(1)


func test_panel_ten_pull_refreshes_ten_results() -> void:
	var panel := _make()
	panel._on_pull_ten_pressed()
	# 返回数组含 10 个结果（含可能重复，重复不计入 owned）
	assert_int(panel._last_results.size()).is_equal(10)
	# 拥有数 > 0（去重后唯一角色数，8 角色抽 10 次必有重复，故不恒等于 10）
	assert_int(panel._get_roster().owned_count()).is_greater(0)


func test_panel_info_shows_owned_count() -> void:
	var panel := _make()
	panel._on_pull_pressed()
	assert_bool(panel._info_label.text.contains("拥有 1")).is_true()
