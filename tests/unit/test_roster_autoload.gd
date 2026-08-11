extends GdUnitTestSuite
## S9 集成 · RosterAutoload 行为与持久化（AC-GACHA 子集）。
## 直接 new RosterAutoload 测其方法（不依赖 autoload 全局注册顺序）。

var _roster: RosterService


func before_test() -> void:
	_roster = RosterService.new()


func test_pull_adds_to_owned() -> void:
	var before := _roster.owned_count()
	var inst := _roster.pull(null)
	assert_object(inst).is_not_null()
	assert_int(_roster.owned_count()).is_equal(before + 1)


func test_set_active_requires_ownership() -> void:
	var inst := _roster.pull(null)
	var ok := _roster.set_active(inst.character_id)
	assert_bool(ok).is_true()
	assert_object(_roster.get_active()).is_not_null()
	assert_str(String(_roster.get_active().character_id)).is_equal(String(inst.character_id))
	# 未拥有的角色不能设出战
	var ok2 := _roster.set_active(&"nonexistent_char")
	assert_bool(ok2).is_false()


func test_dict_roundtrip_preserves_owned() -> void:
	_roster.pull(null)
	_roster.pull(null)
	var d := _roster.to_dict()
	assert_int(int(d.get("owned", []).size())).is_greater(0)
	var r2 := RosterService.new()
	r2.from_dict(d)
	assert_int(r2.owned_count()).is_equal(_roster.owned_count())


func test_active_persists_in_dict() -> void:
	var inst := _roster.pull(null)
	_roster.set_active(inst.character_id)
	var d := _roster.to_dict()
	assert_str(String(d.get("active_character_id", ""))).is_equal(String(inst.character_id))
	var r2 := RosterService.new()
	r2.from_dict(d)
	assert_str(String(r2.active_character_id)).is_equal(String(inst.character_id))


func test_pull_ten_returns_ten() -> void:
	var out := _roster.pull_ten(null)
	assert_int(out.size()).is_equal(10)
