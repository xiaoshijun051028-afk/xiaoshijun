class_name EnemyDefinition
extends Resource
## 敌人静态定义（ENG-S4-01 / architecture.md §4.5）。
## 数据驱动：HP / telegraph 帧 / 攻击伤害 / 移速 / 弱点倍率全部来自本资源；
## 各原型（Brute/Skirmisher/Sentinel）的 .tres 在 ENG-S4-02 创建并填值。
## 逻辑代码只读此处，不硬编码数值（architecture §4.3「禁止：任何逻辑」的同款纪律）。

@export var enemy_id: StringName = &"unnamed"
## 最大生命。EnemyCombat 初始化时读此值定 hp。
@export var max_hp: int = 100
## 预警（wind-up）帧数。真实取值数据驱动，存 .tres；此处为校验默认。
@export var telegraph_frames: int = 48
## 攻击伤害（解析后单值；GDD 给范围，.tres 取其一）。
@export var attack_damage: int = 20
## 移动速度（单位/秒）。
@export var move_speed: float = 3.0
## 弱点倍率（Sentinel=2.0，其余=1.0）。受击伤害 × 此值（ENG-S4-03）。
@export var weakpoint_multiplier: float = 1.0
