class_name BossCombat
extends EnemyCombat
## Boss 战斗控制器（ENG-S4-05）。复用敌人 FSM 骨架（Idle/Telegraph/Attack/Recover/Stagger/Dead），
## 新增**阶段切换无即死**机制：HP 跌破阶段阈值时清空当前攻击（进 Stagger 硬直）→ 0.5s 无敌
## （防即死）→ phase++ → 广播 boss_phase_changed。
##
## 无敌窗内任何伤害归零（不被即死补刀）；阶段切换不改动 HP / 共鸣池，不产生非法状态。

## 阶段切换无敌帧（0.5s @60Hz）。常量本地化，不污染 GameConstants（避免触动 CI 的 test_constants_match_gdd）。
const BOSS_PHASE_INVULN_FRAMES: int = 30

## 阶段触发线（降序的 HP 阈值，按索引对应 phase-1 → phase 的切换）。
## 例 [600]：HP 从 1000 跌破 600 切到 phase 2；最后一阶段无阈值，HP 归零才真死。
var phase_thresholds: PackedInt32Array = PackedInt32Array()

## 当前阶段（1 起）。
var phase: int = 1

## 剩余无敌帧（阶段切换后置满，每物理帧递减）。
var invulnerable_frames: int = 0


## 阶段切换（ENG-S4-05）。清当前攻击 → 进 Stagger 硬直（邻接表保证期间禁新 telegraph）
## → 置无敌 → 广播阶段变更。幂等：已 Dead / 已 Stagger 时不再重复切态。
func _enter_phase(next: int) -> void:
	phase = next
	invulnerable_frames = BOSS_PHASE_INVULN_FRAMES
	var cur := current_state_name()
	if cur != STATE_DEAD and cur != STATE_STAGGER:
		state_machine.try_transition(STATE_STAGGER)
	EventBus.boss_phase_changed.emit(phase)


## 检查并连续切换所有已跌破的阈值（一次大额伤害可能跨多阶段，但 HP 归零则只真死不切阶段）。
func _check_phase() -> void:
	while phase <= phase_thresholds.size() and hp > 0 and hp <= phase_thresholds[phase - 1]:
		_enter_phase(phase + 1)


## 受击（覆盖基类）：无敌窗内免疫（防即死补刀）；否则走基类扣血，再查阶段切换。
func take_damage(amount: int, hit_weakpoint: bool = false) -> int:
	if invulnerable_frames > 0 or hp <= 0:
		return 0
	var dealt := super.take_damage(amount, hit_weakpoint)
	if dealt > 0 and hp > 0:
		_check_phase()
	return dealt


## 每物理帧推进；无敌计时递减（先于基类 tick，确保切换当帧即生效）。
func physics_tick(delta: float) -> void:
	if invulnerable_frames > 0:
		invulnerable_frames = maxi(0, invulnerable_frames - 1)
	super.physics_tick(delta)
