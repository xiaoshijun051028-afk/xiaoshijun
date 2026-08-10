extends Node3D

## =========================================================================
## SPIKE-2 性能基线脚手架（占位）。待 Godot 4.7.1 安装后实测。
##
## 空跑 + 最小负载，挂 DebugOverlay 采样 FPS / 帧时间 / draw call，
## 对照 architecture.md §7.3 预算（draw≤1500 / tris≤2M / particles≤30k）。
## 本脚本仅提供基线采样钩子；实测值由 DebugOverlay 在运行时收集后回填
## docs/testing 的性能门记录表（见 test-plan.md SPIKE-2 小节）。
## =========================================================================

var _elapsed_frames: int = 0

func _physics_process(_delta: float) -> void:
	_elapsed_frames += 1

## 当前帧预算占用估算（占位：返回 0，待 DebugOverlay 接入真实采样）。
func current_draw_call_estimate() -> int:
	return 0

func current_triangle_estimate() -> int:
	return 0
