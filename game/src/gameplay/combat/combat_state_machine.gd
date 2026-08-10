class_name CombatStateMachine
extends StateMachine
## S1 战斗 FSM 的转移裁决（ADR-003 §4）。**只覆写 can_enter()**，不动 S0 基类一行。
##
## 为什么是覆写而不是改基类：`try_transition()` 必须保持唯一入口（epic 出口第 4 条），
## 而基类已经把 `can_enter()` 留成了裁决扩展点。战斗规则（取消窗、终结技池门槛）是 S1 的事，
## 塞进 S0 基类会让 S4 敌人 FSM 也被迫背上这些规则——ADR-003 §6 明确敌人复用同一基类。
##
## 裁决顺序严格照 ADR-003 §4：
##   1. hitstun_left > 0 → 只放行 Hitstun 自身（architecture §5.3 流 B）
##   2. 目标态自检 can_enter_state()（如 Resonate 需池 ≥ FINISHER_COST）
##   3. 取消窗判定 —— 中立态自由起手 / 收招已尽自然结束 / 否则必须落在 is_cancellable() 内
##   4~5. 由基类 _set_current() 完成（exit → enter → emit player_state_entered）
##
## ⚠ 已知基类缺口（本类以覆写方式回避，未改基类，待主理人裁决是否回修 S0）：
##   `StateMachine.can_enter()` 的注释写着「Hitstun 自身除外」，但实现对 hitstun 期间的
##   **任意**目标一律返回 false —— 包括 Hitstun 自己。于是基类自带的 `enter_hitstun()`
##   （先置 _hitstun_frames_left 再 try_transition(&"Hitstun")）永远进不去 Hitstun 态。
##   本类在第 1 步实现了注释所述的例外，使 enter_hitstun() 行为与文档一致。

## 硬直态名（架构 §4.4 闭集）。hitstun 期间唯一放行的目标。
const STATE_HITSTUN: StringName = &"Hitstun"


## 转移裁决第 1–3 步。第 4/5 步在基类 _set_current()。
func can_enter(target: State) -> bool:
	if target == null:
		return false

	# 步骤 1 —— 硬直期禁输入（GDD S1 §⑥ / architecture §5.3 流 B）。
	# 例外只有 Hitstun 自身：受击刷新硬直不该被自己的规则挡住。
	if _hitstun_frames_left > 0:
		return StringName(target.name) == STATE_HITSTUN

	# 步骤 2 —— 目标态自检（ADR-003 §4 第 3 步）。
	var target_combat := target as CombatState
	if target_combat != null and not target_combat.can_enter_state():
		return false

	if current_state == null:
		return true

	# 步骤 3 —— 取消窗判定。窗宽本身**不在这里**，只在 State.is_cancellable() 一处。
	var source := current_state as CombatState
	if source != null and (source.neutral or source.is_finished()):
		return true
	return current_state.is_cancellable()


## 按闭集名取状态节点。返回 null 表示该态未装配。
func get_state(state_name: StringName) -> State:
	return get_node_or_null(NodePath(String(state_name))) as State


## 剩余硬直帧（只读）。供 Hitstun 态对齐自身时长、DebugOverlay 显示、测试断言。
func hitstun_frames_left() -> int:
	return _hitstun_frames_left
