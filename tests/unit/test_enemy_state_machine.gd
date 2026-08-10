extends GdUnitTestSuite
## ENG-S4-01 敌人 FSM 单测（epic-s4 故事 1）。
##
## 验证：合法转移图（Idle→Telegraph→Attack→Recover→Idle）/ 受击致死（Dead 终态）/
## Stagger 期间禁新 Telegraph / 完美格破防联动点 apply_stagger / 受击扣血与 enemy_died /
## 环形迁移日志 / 数据驱动初始化（EnemyDefinition 注入 hp 与 telegraph 帧）。
##
## 复用 S0 基座 StateMachine（ADR-003）：broadcasts_player_state=false（敌人态不广播 player_state_entered）。
## 路径：tests/unit/test_enemy_state_machine.gd

var enemy: EnemyCombat = null
var _enemy_died_received := false


func _on_s4_enemy_died(_e: Node3D) -> void:
	_enemy_died_received = true


func before_test() -> void:
	enemy = EnemyCombat.new()
	add_child(enemy)   # 触发 _ready → initialize(default def) → 进入 Idle
	_enemy_died_received = false


func after_test() -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.free()
	enemy = null


# =========================================================================
# 起始态与广播开关
# =========================================================================

func test_initial_state_is_idle_and_no_player_broadcast() -> void:
	assert_str(String(enemy.current_state_name())).is_equal("Idle")
	# 敌人态绝不放行 player_state_entered（架构 §4.5）
	assert_bool(enemy.state_machine.broadcasts_player_state).is_false()


# =========================================================================
# 合法攻击链路（直接 try_transition 验证邻接表）
# =========================================================================

func test_legal_attack_chain() -> void:
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_TELEGRAPH)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Telegraph")
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_ATTACK)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Attack")
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_RECOVER)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Recover")
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_IDLE)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Idle")


# =========================================================================
# Telegraph 自动推进到 Attack（整数帧驱动，非时间）
# =========================================================================

func test_telegraph_autoadvances_to_attack() -> void:
	enemy.state_machine.try_transition(EnemyStateMachine.STATE_TELEGRAPH)
	assert_str(String(enemy.current_state_name())).is_equal("Telegraph")
	# 推满 telegraph_frames(48) 帧 → 自动转 Attack
	for i in range(48):
		enemy.physics_tick(0.0)
	assert_str(String(enemy.current_state_name())).is_equal("Attack")


# =========================================================================
# Stagger 破防硬直 + 期间禁新 Telegraph（架构 §4.5）
# =========================================================================

func test_stagger_blocks_new_telegraph() -> void:
	assert_bool(enemy.apply_stagger()).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Stagger")
	# Stagger 合法目标仅 Idle/Dead → 新 Telegraph 必须被拒
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_TELEGRAPH)).is_false()
	assert_str(String(enemy.current_state_name())).is_equal("Stagger")


func test_stagger_recovers_to_idle() -> void:
	enemy.apply_stagger()
	assert_str(String(enemy.current_state_name())).is_equal("Stagger")
	# 推满 ENEMY_STAGGER_FRAMES(72) → 自动回落 Idle
	for i in range(GameConstants.ENEMY_STAGGER_FRAMES):
		enemy.physics_tick(0.0)
	assert_str(String(enemy.current_state_name())).is_equal("Idle")


# =========================================================================
# 受击扣血 / 死亡（Dead 终态不可再转移）
# =========================================================================

func test_dead_is_terminal() -> void:
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_DEAD)).is_true()
	assert_str(String(enemy.current_state_name())).is_equal("Dead")
	# Dead 邻接表为空 → 任何转移都拒绝
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_IDLE)).is_false()
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_TELEGRAPH)).is_false()
	assert_bool(enemy.state_machine.try_transition(EnemyStateMachine.STATE_ATTACK)).is_false()
	assert_str(String(enemy.current_state_name())).is_equal("Dead")


func test_take_damage_reduces_hp_and_dies_at_zero() -> void:
	EventBus.enemy_died.connect(_on_s4_enemy_died)

	assert_int(enemy.hp).is_equal(100)
	var dealt := enemy.take_damage(30)
	assert_int(dealt).is_equal(30)
	assert_int(enemy.hp).is_equal(70)
	assert_str(String(enemy.current_state_name())).is_equal("Idle")  # 未死仍 Idle

	enemy.take_damage(70)   # 归零
	assert_int(enemy.hp).is_equal(0)
	assert_str(String(enemy.current_state_name())).is_equal("Dead")
	assert_bool(_enemy_died_received).is_true()

	EventBus.enemy_died.disconnect(_on_s4_enemy_died)


func test_take_damage_never_goes_negative() -> void:
	enemy.take_damage(999)
	assert_int(enemy.hp).is_equal(0)   # 截到 0，不出现负数
	var dealt := enemy.take_damage(10)  # 已死，返 0
	assert_int(dealt).is_equal(0)
	assert_int(enemy.hp).is_equal(0)


# =========================================================================
# 环形迁移日志（调试 / 可观测性）
# =========================================================================

func test_recent_transitions_records_chain() -> void:
	enemy.state_machine.try_transition(EnemyStateMachine.STATE_TELEGRAPH)
	enemy.state_machine.try_transition(EnemyStateMachine.STATE_ATTACK)
	var log := enemy.state_machine.recent_transitions()
	var found_attack := false
	for entry in log:
		if String(entry["to"]) == "Attack":
			found_attack = true
	assert_bool(found_attack).is_true()


# =========================================================================
# 数据驱动初始化：EnemyDefinition 注入 hp 与 telegraph 帧
# =========================================================================

func test_initialize_with_def_sets_hp_and_telegraph() -> void:
	var def := EnemyDefinition.new()
	def.max_hp = 250
	def.telegraph_frames = 30
	var e2 := EnemyCombat.new()
	e2.initialize(def)   # 先于 _ready 注入自定义定义（_initialized 守卫屏蔽 _ready 的默认初始化）
	add_child(e2)
	assert_int(e2.max_hp).is_equal(250)
	assert_int(e2.hp).is_equal(250)
	var ts := e2.state_machine.get_state(EnemyStateMachine.STATE_TELEGRAPH) as EnemyTelegraphState
	assert_int(ts.telegraph_frames).is_equal(30)
	if is_instance_valid(e2):
		e2.free()
