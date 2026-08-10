class_name State
extends Node
## 状态基类（ADR-003 / architecture §4.4）。
##
## 所有玩家 / 敌人状态继承此类。**取消窗逻辑在此单点实现**，避免每个状态各写一遍
## （architecture §4.4「取消窗只在一处实现，所有动词共享」）。这让 S8 技能树改窗口
## 只需改一个读取点（GameConstants.CANCEL_WINDOW）。
##
## 纪律：
##   - 本类**不持有**取消窗宽度常量，只读 GameConstants.CANCEL_WINDOW。
##   - 状态只描述「何时可取消」「进入/退出做什么」，不推进其他游戏状态。
##   - 由 StateMachine 在 _enter 前注入 machine 引用。

## 该状态进入"可被取消"的起始帧（-1 = 不可取消）。
## 子类在 _enter() 里按 VerbDefinition 设置（如 Slash 在出招第 N 帧开取消窗）。
@export var cancel_open_at_frame: int = -1

## 当前状态已持续的物理 tick 数。每 tick +1（由 StateMachine.physics_tick 驱动）。
var frames_in_state: int = 0

## 状态机引用（由 StateMachine._set_current 注入）。供状态查询宿主（如 Player）。
var machine: Node = null


func _enter() -> void:
	frames_in_state = 0


func _exit() -> void:
	pass


## 每物理 tick 推进（由 StateMachine.physics_tick 调用）。
func physics_tick(_delta: float) -> void:
	frames_in_state += 1


## 是否处于取消窗内：从 cancel_open_at_frame 起，持续 CANCEL_WINDOW 帧。
## 这是取消窗的唯一实现点，所有动词共享（architecture §4.4）。
func is_cancellable() -> bool:
	if cancel_open_at_frame < 0:
		return false
	var elapsed := frames_in_state - cancel_open_at_frame
	return elapsed >= 0 and elapsed < GameConstants.CANCEL_WINDOW
