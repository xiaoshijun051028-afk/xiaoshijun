class_name IdleState
extends CombatState
## Idle · 中立态（架构 §4.4 节点树，node.name == &"Idle"）。
##
## 刻意保持 `cancel_open_at_frame = -1`：Idle **不需要**取消窗，因为它没有收招承诺。
## 「自由起手」与「取消」是两个概念，用 `neutral` 而不是「一个永远开着的取消窗」来表达：
## 若把 Idle 伪装成常开窗态，CANCEL_WINDOW 的语义会在 S8 技能树调窗时连带漂移
## （窗宽最低可减到 5 帧），Idle 就会莫名其妙变成「站 5 帧后出不了招」。


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = -1     # 不可取消：无收招可取消
	duration_frames = -1          # 不会自然结束
	neutral = true                # 任意动词可自由起手
