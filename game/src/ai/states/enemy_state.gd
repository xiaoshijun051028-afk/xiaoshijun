class_name EnemyState
extends State
## 敌人状态基类（ENG-S4-01）。在 S0 State 上追加 is_finished()（与 CombatState 一致），
## 供各态在收招尽时经 try_transition() 回落下一态 —— 不另开转移入口。
## 敌人状态不直接实现取消窗（那是玩家动词语义），只描述自身持续帧与回落目标。

## 本状态持续总帧数（-1 = 不自然结束，持续直到外部触发转移，如 Idle / Dead）。
## 各态在 _enter() 里按自身语义赋值（telegraph_frames / attack_frames / ENEMY_STAGGER_FRAMES …）。
## 与玩家 CombatState 平行：玩家支在 CombatState 自管 duration_frames，敌人支在 EnemyState 自管，
## 基类 S0 State 不持有（避免与 CombatState 的声明重复冲突）。
@export var duration_frames: int = -1

## 收招是否已尽（整数帧比较，architecture §3.2 第 6 条）。
func is_finished() -> bool:
	if duration_frames < 0:
		return false
	return frames_in_state >= duration_frames
