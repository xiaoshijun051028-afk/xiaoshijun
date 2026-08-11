extends GdUnitTestSuite
## ENG-S4-02 · telegraph 100% 覆盖 THREAT 预警语言（AC-S4-01）。
## 断言：
##   1) 每次进入 Telegraph 态发 enemy_telegraph_started(enemy, frames>0)；
##      退出 Telegraph 态发 enemy_telegraph_cleared(enemy)。
##   2) 预警语义色 = THREAT（#A62C6B），由消费方引用 ColorTokens.THREAT，
##      不在信号里传（守"禁止硬编码色"铁律）；本测试验证 Token 名与权威取值。
##   3) 三原型 .tres 数值符合 epic-s4 §故事2 规格。
##   4) 硬直（Stagger）期间禁新 Telegraph（邻接表天然保证）。

var _captured_enemy: Node3D = null
var _captured_frames: int = -1
var _cleared_enemy: Node3D = null


func before_test() -> void:
	_captured_enemy = null
	_captured_frames = -1
	_cleared_enemy = null
	EventBus.enemy_telegraph_started.connect(_on_started)
	EventBus.enemy_telegraph_cleared.connect(_on_cleared)


func after_test() -> void:
	EventBus.enemy_telegraph_started.disconnect(_on_started)
	EventBus.enemy_telegraph_cleared.disconnect(_on_cleared)


func _on_started(enemy: Node3D, frames: int) -> void:
	_captured_enemy = enemy
	_captured_frames = frames


func _on_cleared(enemy: Node3D) -> void:
	_cleared_enemy = enemy


func _load_def(id: StringName) -> EnemyDefinition:
	var def := load("res://game/resources/enemy_defs/%s.tres" % id) as EnemyDefinition
	assert_object(def).is_not_null()
	return def


func _make(def: EnemyDefinition) -> EnemyCombat:
	var ec := EnemyCombat.new()
	ec.initialize(def)   # 先于 _ready 注入定义（_initialized 守卫屏蔽 _ready 的默认初始化）
	add_child(ec)
	return ec


## ---- 三原型 .tres 数值符合规格 ----

func test_brute_prototype_values() -> void:
	var def := _load_def(&"brute")
	assert_str(String(def.enemy_id)).is_equal("brute")
	assert_int(def.max_hp).is_equal(120)
	assert_int(def.telegraph_frames).is_equal(60)
	assert_int(def.attack_damage).is_equal(30)
	assert_float(def.move_speed).is_equal(3.0)
	assert_float(def.weakpoint_multiplier).is_equal(1.0)


func test_skirmisher_prototype_values() -> void:
	var def := _load_def(&"skirmisher")
	assert_str(String(def.enemy_id)).is_equal("skirmisher")
	assert_int(def.max_hp).is_equal(60)
	assert_int(def.telegraph_frames).is_equal(30)
	assert_int(def.attack_damage).is_equal(15)
	assert_float(def.move_speed).is_equal(5.0)
	assert_float(def.weakpoint_multiplier).is_equal(1.0)


func test_sentinel_prototype_values() -> void:
	var def := _load_def(&"sentinel")
	assert_str(String(def.enemy_id)).is_equal("sentinel")
	assert_int(def.max_hp).is_equal(80)
	assert_int(def.telegraph_frames).is_equal(30)
	assert_int(def.attack_damage).is_equal(12)
	assert_float(def.move_speed).is_equal(2.5)
	assert_float(def.weakpoint_multiplier).is_equal(2.0)


## ---- telegraph 进入/退出发信号（每个原型）----

func test_brute_telegraph_emits_started_and_cleared() -> void:
	_telegraph_cycle_emits(&"brute")


func test_skirmisher_telegraph_emits_started_and_cleared() -> void:
	_telegraph_cycle_emits(&"skirmisher")


func test_sentinel_telegraph_emits_started_and_cleared() -> void:
	_telegraph_cycle_emits(&"sentinel")


## 通用：进入 Telegraph 发 started(enemy, frames)；转 Attack 发 cleared(enemy)。
func _telegraph_cycle_emits(id: StringName) -> void:
	var def := _load_def(id)
	var ec := _make(def)
	# 从 Idle 进 Telegraph（邻接表合法）
	var ok_enter := ec.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)
	assert_bool(ok_enter).is_true()
	assert_object(_captured_enemy).is_equal(ec)
	assert_int(_captured_frames).is_equal(def.telegraph_frames)
	assert_bool(_captured_frames > 0).is_true()
	# 转 Attack 触发退出 → cleared
	var ok_leave := ec.state_machine.try_transition(EnemyCombat.STATE_ATTACK)
	assert_bool(ok_leave).is_true()
	assert_object(_cleared_enemy).is_equal(ec)


## ---- 预警语义色 = THREAT（#A62C6B），禁硬编码 ----

func test_telegraph_uses_threat_token() -> void:
	# 信号契约：telegraph 信号消费的语义色 Token 名必须是 THREAT（非 DAMAGE_WARN / 字面量）。
	assert_str(String(GameConstants.TOKEN_THREAT)).is_equal("THREAT")
	# 权威取值（design/color-tokens.md §1）：THREAT = #A62C6B。
	# 用 to_html 精确比对，避开 float32 舍入（Color 以 float32 存储，is_equal(0.651) 会漂）。
	assert_str(ColorTokens.THREAT.to_html(false)).is_equal("a62c6b")


## ---- 硬直中禁新 telegraph ----

func test_stagger_blocks_new_telegraph() -> void:
	var ec := _make(_load_def(&"brute"))
	var ok_stagger := ec.state_machine.try_transition(EnemyCombat.STATE_STAGGER)
	assert_bool(ok_stagger).is_true()
	# Stagger 合法目标仅 Idle / Dead，不含 Telegraph → 应被拒。
	var ok_telegraph := ec.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)
	assert_bool(ok_telegraph).is_false()
	assert_object(_captured_enemy).is_null()


## ---- 同一敌人任意时刻仅一个 telegraph 态（单态，天然不重叠）----

func test_cannot_reenter_telegraph_from_telegraph() -> void:
	var ec := _make(_load_def(&"brute"))
	# 先进入 Telegraph（邻接表合法）
	assert_bool(ec.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)).is_true()
	assert_str(String(ec.current_state_name())).is_equal("Telegraph")
	# 已在 Telegraph：再进 Telegraph 必须被拒（同名态唯一、邻接表不含自环）。
	var again := ec.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)
	assert_bool(again).is_false()
	assert_str(String(ec.current_state_name())).is_equal("Telegraph")
