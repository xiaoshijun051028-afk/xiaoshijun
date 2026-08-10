class_name CombatState
extends State
## 动词态基类（ENG-S1-02 / ADR-003 §1、§4）。
##
## 在 S0 的 `State` 之上只**追加**能力，**不改写基类**——取消窗判定仍是 `State.is_cancellable()`
## 的单点实现（architecture §4.4「取消窗只在一处实现」），本类绝不重复实现窗宽。
##
## 追加两件事，各自解决一个具体问题：
##   1. `duration_frames` —— 动作总帧数。`frames_in_state >= duration` 即「收招已尽」。
##      有了它，「动作自然打完回中立态」与「被别的动词取消」才是两件可分辨的事；
##      否则终结技这类不可取消的动作一旦起手就永远出不来（can_enter 会一路拒绝）。
##   2. `neutral` / `can_enter_state()` —— 承接 ADR-003 §4 转移裁决第 3 步「目标状态自检」。
##
## 帧数为 v1 占位常量。[GAP-VERB-1] 真实分段帧（startup/active/recovery）随 ENG-S1-03
## 迁入 `resources/verbs/*.tres`（ADR-003 §5 动词参数数据化），届时本类只读资源、不改逻辑。

## 收招自然结束后回落的中立态名（架构 §4.4 闭集）。
const RETURN_STATE: StringName = &"Idle"

## 动作总时长（整数帧）。-1 = 不会自然结束（中立态，或由外部事件收束）。
@export var duration_frames: int = -1

## 中立态标记：true 表示该态无收招承诺，任意动词可自由起手（v1 仅 Idle）。
@export var neutral: bool = false


## 收招是否已尽。整数帧比较，不用秒、不累加 delta（architecture §3.2 第 6 条）。
func is_finished() -> bool:
	if duration_frames < 0:
		return false
	return frames_in_state >= duration_frames


## 目标态自检（ADR-003 §4 第 3 步）。默认放行；Resonate 覆写为「池 ≥ FINISHER_COST」。
func can_enter_state() -> bool:
	return true


## 推进一帧；收招已尽则经**同一个** try_transition() 回落中立态——不另开转移入口，
## 这样「自然结束」也走得通转移裁决，不会绕过 hitstun 拒绝等规则。
func physics_tick(delta: float) -> void:
	super.physics_tick(delta)
	if not is_finished():
		return
	var sm := machine as StateMachine
	if sm != null and sm.current_state_name != RETURN_STATE:
		sm.try_transition(RETURN_STATE)
