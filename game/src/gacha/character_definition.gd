class_name CharacterDefinition
extends Resource
## 角色静态定义（S9）。数据驱动五维基线 + 稀有度 + 美术引用 + 文本。
## 实际出战数值 = 基线经稀有度乘区(维度加权) × roll，由 GachaEngine.compute_stat 计算。

@export var character_id: StringName = &""
@export var display_name: String = ""
## 职阶代号：BLADE / BULWARK / WINDCHASER / RESONANT（基线五维和恒=500）。
@export var archetype: StringName = &"BLADE"
## 稀有度（GachaConstants.RARITY）。
@export var rarity: int = 0

## 五维基线（职阶给定，和=500）。
@export var base_hp: int = 100
@export var base_attack: int = 100
@export var base_defense: int = 100
@export var base_move_speed: int = 100
@export var base_affinity: int = 100

## 美术引用（占位，v1 用共用骨骼动画集；实际 3D 模型由美术后续产出）。
@export var art_ref: String = ""
@export var lore_text: String = ""
