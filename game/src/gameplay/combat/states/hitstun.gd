class_name HitstunState
extends CombatState
## Hitstun · 受击硬直（架构 §4.4 节点树 / §5.3 流 B / EventBus 闭集第 9 态）。
##
## 为什么 ENG-S1-02 必须一并落地它：`StateMachine.enter_hitstun()` 会
## `try_transition(&"Hitstun")`。缺这个子节点，基类会 `push_error("未知状态 Hitstun")`，
## 且硬直期玩家「无处可去」——拒绝转移的规则就变成了卡死玩家的规则。
## 它同时是 epic 出口「hitstun 拒绝转移」可被断言的前提。
##
## 时长**对齐状态机的硬直计时**而非写死 30：`enter_hitstun(n)` 在转移前就已置好
## `_hitstun_frames_left = n`，本态据此取值，两个计数器同一 tick 归零 → 自然回 Idle。
## 若各记各的，轻击（n < 30）会出现「硬直已解除但状态还锁着」的哑帧——
## 那 20 帧玩家按什么都没反应，且从画面上完全读不出原因。


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = -1     # 硬直不可取消（GDD S1 §⑥ 硬直期禁输入）
	neutral = false
	duration_frames = _resolve_duration()


## 取本次硬直的帧数，上限 HITSTUN_MAX_FRAMES(30) = 0.5s 防卡死。
func _resolve_duration() -> int:
	var sm := machine as CombatStateMachine
	if sm == null:
		return GameConstants.HITSTUN_MAX_FRAMES
	return clampi(sm.hitstun_frames_left(), 0, GameConstants.HITSTUN_MAX_FRAMES)
