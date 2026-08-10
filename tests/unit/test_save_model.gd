extends GdUnitTestSuite
## S8 存档 · AC-S8-01（还原 100%）/ AC-S8-04（写盘失败不崩的纯逻辑侧）/ ADR-002（常量不入档）
##
## 纯逻辑，无文件 IO：SaveModel 的 new_save / serialize / deserialize / clamp_fields /
## compute_checksum / find_forbidden_keys。文件 IO 与原子写由 test_save_atomic.gd 覆盖。

func test_new_save_has_initial_pool_and_schema() -> void:
	var s := SaveModel.new_save("0.5.0")
	assert_int(int(s["schema_version"])).is_equal(SaveModel.SCHEMA_VERSION)
	assert_int(int(s["resonance"]["current"])).is_equal(GameConstants.RESONANCE_INITIAL)


func test_roundtrip_preserves_current() -> void:
	var s := SaveModel.new_save("0.5.0")
	s["resonance"]["current"] = 73
	var text := SaveModel.serialize(s)
	var result := SaveModel.deserialize(text)
	assert_bool(result.ok).is_true()
	assert_int(int(result.data["resonance"]["current"])).is_equal(73)


func test_checksum_tamper_rejected() -> void:
	var s := SaveModel.new_save("0.5.0")
	s["resonance"]["current"] = 80
	var text := SaveModel.serialize(s)
	# 篡改 checksum 前缀 → 校验失败 → 优雅拒绝（不抛异常、不污染内存）。
	var tampered := text.replace("sha256:", "sha256x:")
	var result := SaveModel.deserialize(tampered)
	assert_bool(result.ok).is_false()


func test_future_schema_version_rejected() -> void:
	var s := SaveModel.new_save("0.5.0")
	s["schema_version"] = SaveModel.SCHEMA_VERSION + 1
	var text := SaveModel.serialize(s)
	var result := SaveModel.deserialize(text)
	assert_bool(result.ok).is_false()


func test_clamp_fields_bounds_pool() -> void:
	var over := SaveModel.clamp_fields({"resonance": {"current": 9999}})
	assert_int(int(over["resonance"]["current"])).is_equal(GameConstants.RESONANCE_MAX)
	var under := SaveModel.clamp_fields({"resonance": {"current": -50}})
	assert_int(int(under["resonance"]["current"])).is_equal(0)


func test_no_constants_in_clean_save() -> void:
	var clean := SaveModel.new_save("0.5.0")
	clean["resonance"]["current"] = 60
	var clean_v := SaveModel.find_forbidden_keys(clean)
	assert_array(clean_v).is_empty()


func test_forbidden_keys_detected() -> void:
	var dirty := SaveModel.new_save("0.5.0")
	dirty["resonance_max"] = 100
	dirty["gate_cost"] = 30
	dirty["max"] = 999
	var violations := SaveModel.find_forbidden_keys(dirty)
	assert_array(violations).is_not_empty()
