extends GdUnitTestSuite
## S3 共鸣池 · AC-S3-01（上限不溢出）/ AC-S3-02（恰扣 40·30）/ AC-S3-03（池=35 开门可·终结技不可）
##
## 验证驱动：本测试先于"确认实现"存在——ResonancePool 单例（autoload #3）与其私有内核
## ResonanceModel 已实现，本文件是**架构承重墙**的可执行形式：它把「P4 互斥」从设计陈述
## 变成 CI 里跑不过就红门的断言。
##
## 依赖：ResonancePool / GameConstants / EventBus 经 project.godot 注册为 Autoload。
## ⚠ 执行缺口：本机未安装 Godot 4 引擎（见 README「执行缺口」），源码与测试可审阅但
##   无法本地运行；CI（godot --headless + gdUnit4）方为真实执行环境。

func before_test() -> void:
	ResonancePool.reset_for_test(50)   # GDD 新档初始值


func after_test() -> void:
	ResonancePool.reset_for_test(50)


# =========================================================================
# AC-S3-01 · 上限严格 100，溢出部分丢弃不保留
# =========================================================================

func test_cap_no_overflow() -> void:
	ResonancePool.reset_for_test(0)
	ResonancePool.add(1000)   # 远超上限
	assert_int(ResonancePool.current).is_equal(GameConstants.RESONANCE_MAX)  # 100


func test_cap_clamps_at_exact_max() -> void:
	ResonancePool.reset_for_test(0)
	ResonancePool.add(100)
	assert_int(ResonancePool.current).is_equal(100)
	ResonancePool.add(1)   # 撞顶不再增长
	assert_int(ResonancePool.current).is_equal(100)


func test_floor_no_negative_on_insufficient_spend() -> void:
	ResonancePool.reset_for_test(0)
	var ok := ResonancePool.try_spend(10, ResonancePool.REASON_FINISHER)
	assert_bool(ok).is_false()
	assert_int(ResonancePool.current).is_equal(0)   # 分文未扣，不出现负数


# =========================================================================
# AC-S3-02 · 恰扣 40（终结技）/ 30（闸门），数值来自 GameConstants 非字面量
# =========================================================================

func test_spend_exact_finisher_40() -> void:
	ResonancePool.reset_for_test(50)
	var ok := ResonancePool.try_spend(GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER)
	assert_bool(ok).is_true()
	assert_int(ResonancePool.current).is_equal(50 - GameConstants.FINISHER_COST)  # 10


func test_spend_exact_gate_30() -> void:
	ResonancePool.reset_for_test(50)
	var ok := ResonancePool.try_spend(GameConstants.GATE_COST, ResonancePool.REASON_GATE)
	assert_bool(ok).is_true()
	assert_int(ResonancePool.current).is_equal(50 - GameConstants.GATE_COST)  # 20


func test_insufficient_spend_does_not_mutate() -> void:
	ResonancePool.reset_for_test(35)
	var ok := ResonancePool.try_spend(GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER)
	assert_bool(ok).is_false()
	assert_int(ResonancePool.current).is_equal(35)   # 余额不足：拒绝且不扣


# =========================================================================
# AC-S3-03 · 池=35 时开门(30)可、终结技(40)不可 —— P4 支柱唯一硬证据
# =========================================================================

func test_mutex_35_gate_ok_finisher_no() -> void:
	ResonancePool.reset_for_test(35)
	# 开门：35 >= 30 → 成功，池剩 5
	var gate_ok := ResonancePool.try_spend(GameConstants.GATE_COST, ResonancePool.REASON_GATE)
	assert_bool(gate_ok).is_true()
	assert_int(ResonancePool.current).is_equal(5)
	# 此时池=5，终结技 40 必然失败
	var fin_ok := ResonancePool.try_spend(GameConstants.FINISHER_COST, ResonancePool.REASON_FINISHER)
	assert_bool(fin_ok).is_false()


func test_mutex_single_pool_source() -> void:
	# 互斥性来自「开门与终结技读同一份 _current」，不依赖任何人的自律。
	ResonancePool.reset_for_test(35)
	assert_bool(ResonancePool.can_afford_gate()).is_true()
	assert_bool(ResonancePool.can_afford_finisher()).is_false()
	# 另一侧：池=40 时终结技可、开门当然也可（不互斥的边界）
	ResonancePool.reset_for_test(40)
	assert_bool(ResonancePool.can_afford_finisher()).is_true()
	assert_bool(ResonancePool.can_afford_gate()).is_true()


# =========================================================================
# 同帧竞争裁决：终结技优先，闸门排队（ADR-002 决策 3）
# =========================================================================

func test_double_spend_priority_finisher_consumes_shared_pool() -> void:
	ResonancePool.reset_for_test(40)   # 刚好够终结技
	# 玩家主动终结技：成功，池 → 0
	var fin_ok := ResonancePool.try_spend_finisher(0)
	assert_bool(fin_ok).is_true()
	assert_int(ResonancePool.current).is_equal(0)
	# 同一帧闸门请求：池已空 → 进排队
	var gate_ok := ResonancePool.try_spend_gate(&"test_gate")
	assert_bool(gate_ok).is_false()
	# 下一 tick 重试仍失败（池仍 0）→ 丢弃，不崩
	ResonancePool.advance_ticks_for_test(1)
	assert_int(ResonancePool.current).is_equal(0)
