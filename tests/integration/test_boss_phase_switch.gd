extends GdUnitTestSuite
## ENG-S4-05 · Boss 阶段切换无即死（AC-S4-04）。
## 注入 HP 跌破阈值，断言：阶段切换 + 0.5s 无敌 + 清 telegraph（进 Stagger）+ 无即死（HP 不变负）；
## 无敌窗内伤害归零；最后一阶段 HP 归零仍真死（不永久无敌）。

const PATH_BOSS := "res://game/resources/enemy_defs/boss_warden.tres"

var _def: EnemyDefinition
var _phase_captured: int = -1
var _died: bool = false


func before_test() -> void:
	_def = load(PATH_BOSS) as EnemyDefinition
	assert_object(_def).is_not_null()
	_phase_captured = -1
	_died = false
	EventBus.boss_phase_changed.connect(_on_phase)
	EventBus.enemy_died.connect(_on_died)


func after_test() -> void:
	EventBus.boss_phase_changed.disconnect(_on_phase)
	EventBus.enemy_died.disconnect(_on_died)


func _on_phase(p: int) -> void:
	_phase_captured = p


func _on_died(_e: Node3D) -> void:
	_died = true


func _make(thresholds: PackedInt32Array) -> BossCombat:
	var bc := BossCombat.new()
	bc.initialize(_def)          # max_hp=1000（来自 boss.tres）
	bc.phase_thresholds = thresholds
	add_child(bc)
	return bc


## HP 跌破阈值 → 阶段切换 + 无敌 + 清 telegraph（进 Stagger）+ HP 不变负。
func test_phase_switch_on_threshold() -> void:
	var bc := _make(PackedInt32Array([600]))
	assert_int(bc.hp).is_equal(1000)
	bc.take_damage(410)          # hp 1000→590，跌破 600
	assert_int(bc.phase).is_equal(2)
	assert_int(_phase_captured).is_equal(2)
	assert_int(bc.invulnerable_frames).is_greater(0)      # 0.5s 无敌激活
	assert_str(String(bc.current_state_name())).is_equal("Stagger")  # 清当前攻击
	assert_int(bc.hp).is_equal(590)                       # 不变负
	assert_bool(bc.hp < 0).is_false()


## 无敌窗内伤害归零（防即死补刀）。
func test_invuln_blocks_damage() -> void:
	var bc := _make(PackedInt32Array([600]))
	bc.take_damage(410)          # 触发阶段切换，进入无敌
	var hp_after_switch := bc.hp
	var dealt := bc.take_damage(100)   # 无敌窗内
	assert_int(dealt).is_equal(0)
	assert_int(bc.hp).is_equal(hp_after_switch)


## 最后一阶段 HP 归零仍真死（无即死 = 切换瞬间不死，非永久无敌）。
func test_last_phase_death() -> void:
	var bc := _make(PackedInt32Array([600]))
	bc.take_damage(410)          # 切到 phase 2，hp=590，无敌中
	bc.invulnerable_frames = 0   # 清无敌（测试模拟无敌窗结束）
	bc.take_damage(9999)         # 致命
	assert_int(bc.hp).is_equal(0)
	assert_bool(_died).is_true()
	assert_str(String(bc.current_state_name())).is_equal("Dead")


## 不触发非法状态：阈值以下、未致死时不切换、HP 不越界。
func test_no_phase_when_above_threshold() -> void:
	var bc := _make(PackedInt32Array([600]))
	bc.take_damage(300)          # hp 700，仍在阈值之上
	assert_int(bc.phase).is_equal(1)
	assert_int(_phase_captured).is_equal(-1)
	assert_int(bc.hp).is_equal(700)
