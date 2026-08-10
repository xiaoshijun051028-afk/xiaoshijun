extends Node3D

## =========================================================================
## Sprint 1 垂直切片：证明支柱 P4「共鸣统一」最小可玩核心循环。
##
## 全用占位 Mesh（blockout），不依赖美术资产。串联：
##   命中 dummy +1 → 踩共鸣节点 +10(5s cd) → 池≥30 可开门（解谜路径）
##                                    → 池≥40 可放终结技（战斗路径，与开门互斥）
##
## 待 Godot 4.7.1 + gdUnit4 安装后加载验证（本切片加载即证明核心循环可玩）。
## =========================================================================

@onready var _label: Label = $CanvasLayer/Hud/Label

func _ready() -> void:
	ResonancePool.reset_for_test(GameConstants.RESONANCE_INITIAL)
	EventBus.resonance_changed.connect(_on_resonance_changed)
	_refresh_hud()

func _on_resonance_changed(_new: int, _old: int) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	if _label != null:
		_label.text = "Resonance: %d / %d" % [ResonancePool.current, GameConstants.RESONANCE_MAX]

## 玩家命中 dummy：+GAIN_HIT。
func on_player_hit() -> void:
	ResonancePool.add(GameConstants.GAIN_HIT, ResonancePool.SOURCE_HIT)

## 踩共鸣节点：+GAIN_NODE（受 NODE_COOLDOWN_FRAMES 约束）。
func on_touch_node(node_id: StringName) -> void:
	ResonancePool.resonate_at_node(node_id)

## 尝试开门（解谜路径，消耗 GATE_COST）。
func try_open_gate(gate_id: StringName) -> bool:
	return ResonancePool.try_spend_gate(gate_id)

## 尝试终结技（战斗路径，消耗 FINISHER_COST）—— 与开门共享池 → 互斥。
func try_finisher() -> bool:
	return ResonancePool.try_spend_finisher(GameConstants.GAIN_KILL)
