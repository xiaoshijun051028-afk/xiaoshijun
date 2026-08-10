extends Node3D

## =========================================================================
## SPIKE-1 输入延迟测量脚手架（占位）。待 Godot 4.7.1 安装后实测。
##
## 方法：_physics_process 累加 tick（整数帧，60Hz），记录"输入事件 tick"
## → "响应 tick" 差值，换算 ms，对照 GameConstants.LATENCY_BUDGET_KBM_MS=50
## / LATENCY_BUDGET_GAMEPAD_MS=80（sprint-01-plan 决策：SPIKE-1 先跑，因为
## 它是唯一可能推翻时间基准架构决策的风险）。
##
## 注：本脚本仅搭测量骨架。实际端到端延迟需 240fps 摄像机录屏 + 帧对齐，
## 无法在单元测试内闭环，见 docs/testing/test-plan.md SPIKE-1 小节。
## =========================================================================

var _tick_count: int = 0
var _input_tick: int = -1
var _response_tick: int = -1

func _physics_process(_delta: float) -> void:
	_tick_count += 1

## 记录输入 tick（由输入事件回调调用）。
func mark_input_tick() -> void:
	_input_tick = _tick_count

## 记录响应 tick（由玩法响应回调调用）。
func mark_response_tick() -> void:
	_response_tick = _tick_count

## 估算端到端延迟（帧 → ms，仅供展示，禁止用于玩法判定）。
func estimated_latency_msec() -> float:
	if _input_tick < 0 or _response_tick < 0:
		return -1.0
	var frames: int = _response_tick - _input_tick
	return float(frames) * 1000.0 / float(GameConstants.TICKS_PER_SECOND)
