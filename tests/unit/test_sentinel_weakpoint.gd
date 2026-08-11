extends GdUnitTestSuite
## ENG-S4-03 · Sentinel 弱点 x2（AC-S4-03）。
## 注入弱点 / 非弱点命中，断言伤害比值 ≈ 2.0 ± 0.1（Sentinel wk=2.0）；
## 非弱点敌人（Brute wk=1.0）弱点命中比值 ≈ 1.0；弱点致命时正确转 Dead。

const PATH_SENTINEL := "res://game/resources/enemy_defs/sentinel.tres"
const PATH_BRUTE := "res://game/resources/enemy_defs/brute.tres"

var _sentinel_def: EnemyDefinition
var _brute_def: EnemyDefinition
var _died: bool = false


func before_test() -> void:
	_sentinel_def = load(PATH_SENTINEL) as EnemyDefinition
	_brute_def = load(PATH_BRUTE) as EnemyDefinition
	assert_object(_sentinel_def).is_not_null()
	assert_object(_brute_def).is_not_null()
	_died = false
	EventBus.enemy_died.connect(_on_died)


func after_test() -> void:
	EventBus.enemy_died.disconnect(_on_died)


func _on_died(_e: Node3D) -> void:
	_died = true


func _make(def: EnemyDefinition) -> EnemyCombat:
	var ec := EnemyCombat.new()
	ec.initialize(def)
	add_child(ec)
	return ec


## Sentinel（wk=2.0）：弱点伤害 / 非弱点伤害 ≈ 2.0 ± 0.1。
func test_sentinel_weakpoint_ratio() -> void:
	var a := _make(_sentinel_def)
	var b := _make(_sentinel_def)
	var d_base := a.take_damage(20, false)   # 20
	var d_weak := b.take_damage(20, true)    # 40
	var ratio := float(d_weak) / float(d_base)
	assert_bool(absf(ratio - 2.0) <= 0.1).is_true()


## 弱点倍率来自定义（非字面量）：Brute wk=1.0 时弱点命中比值 ≈ 1.0。
func test_brute_weakpoint_unaffected() -> void:
	var a := _make(_brute_def)
	var b := _make(_brute_def)
	var d_base := a.take_damage(20, false)
	var d_weak := b.take_damage(20, true)
	var ratio := float(d_weak) / float(d_base)
	assert_bool(absf(ratio - 1.0) <= 0.001).is_true()


## 弱点放大后致命：敌人正确转 Dead 并发 enemy_died。
func test_sentinel_weakpoint_lethal() -> void:
	var ec := _make(_sentinel_def)
	# max_hp=80，50×2=100 致死
	ec.take_damage(50, true)
	assert_bool(_died).is_true()
	assert_str(String(ec.current_state_name())).is_equal("Dead")


## 倍率字段来源正确（AC-S4-03 验收点：来自 EnemyDefinition，非硬编码）。
func test_weakpoint_from_definition() -> void:
	assert_float(_sentinel_def.weakpoint_multiplier).is_equal(2.0)
	assert_float(_brute_def.weakpoint_multiplier).is_equal(1.0)
