class_name CharacterSkillSet
extends RefCounted
## 角色技能数据（design/gdd/systems/gacha-characters.md）。
## 纯数据 + 表现侧描述符，由 game/src/gameplay/skill_controller.gd 解释执行。
## 不进入核心伤害公式（attack_power 仍 deferred）；仅做表现侧增益 / 治疗 / 共鸣 / 位移。

enum ActiveType {
	BUFF_ATTACK,       # 攻击乘区增益（持续）
	BUFF_DEFENSE,      # 减伤（等效防御乘区增益，持续）
	DASH,              # 位移冲刺
	AOE_KNOCKBACK,     # 范围击退 + 打断敌人 telegraph
	ADD_RESONANCE,     # 直接注入共鸣池点数
	VULN_ENEMY,       # 敌人易伤（受伤倍率提升，持续）
}

enum PassiveType {
	PARRY_SLASH_BONUS, # 完美格挡 → 下次斩击 +25%（需连段钩子，Phase 6 接入）
	LOW_HP_DEFENSE,    # HP < 30% → 防御 +20%
	MOVE_SPEED,        # 移速 +X%
	DASH_KEEPS_COMBO,  # 冲刺不中断连段（需连段钩子，Phase 6 接入）
	PARRY_HEAL,        # 完美格挡 → 治疗 +N
	FINISHER_BONUS,    # 终结技输出 +N%（需终结技钩子，Phase 6 接入）
	KILL_RESONANCE,    # 击杀 → 共鸣池 +N（独立于 ADR-002 的 +15 常量）
}

var character_id: StringName
var active_name: String
var active_cd_seconds: float
var active_type: ActiveType
var active_magnitude: float
var active_duration: float
var passive_name: String
var passive_type: PassiveType
var passive_magnitude: float


func _init(cid: StringName, a_name: String, a_cd: float, a_type: ActiveType, a_mag: float, a_dur: float,
		p_name: String, p_type: PassiveType, p_mag: float) -> void:
	character_id = cid
	active_name = a_name
	active_cd_seconds = a_cd
	active_type = a_type
	active_magnitude = a_mag
	active_duration = a_dur
	passive_name = p_name
	passive_type = p_type
	passive_magnitude = p_mag


## 按 character_id 取技能集；未知 → 返回 null（无技能，仅基础数值）。
static func of(id: StringName) -> CharacterSkillSet:
	match id:
		&"ash_acolyte":
			return CharacterSkillSet.new(&"ash_acolyte", "余烬斩", 8.0, ActiveType.BUFF_ATTACK, 0.15, 6.0,
				"灰烬余温", PassiveType.PARRY_SLASH_BONUS, 0.25)
		&"oath_guard":
			return CharacterSkillSet.new(&"oath_guard", "誓锁壁垒", 12.0, ActiveType.BUFF_DEFENSE, 1.0, 4.0,
				"不屈", PassiveType.LOW_HP_DEFENSE, 0.20)
		&"swift_ranger":
			return CharacterSkillSet.new(&"swift_ranger", "迅羽突袭", 7.0, ActiveType.DASH, 0.0, 0.0,
				"疾风之翼", PassiveType.MOVE_SPEED, 0.08)
		&"gale_echo":
			return CharacterSkillSet.new(&"gale_echo", "回响疾风", 9.0, ActiveType.DASH, 0.0, 2.5,
				"风追节拍", PassiveType.DASH_KEEPS_COMBO, 0.0)
		&"bulwark_heart":
			return CharacterSkillSet.new(&"bulwark_heart", "磐心脉冲", 10.0, ActiveType.AOE_KNOCKBACK, 1.2, 0.0,
				"守护共鸣", PassiveType.PARRY_HEAL, 8.0)
		&"resonant_hierophant":
			return CharacterSkillSet.new(&"resonant_hierophant", "谐律圣咏", 15.0, ActiveType.ADD_RESONANCE, 30.0, 0.0,
				"主祭恩泽", PassiveType.FINISHER_BONUS, 0.30)
		&"voidblade_lord":
			return CharacterSkillSet.new(&"voidblade_lord", "断空", 6.0, ActiveType.DASH, 0.0, 0.0,
				"虚空回响", PassiveType.FINISHER_BONUS, 0.20)
		&"resonant_singer":
			return CharacterSkillSet.new(&"resonant_singer", "共鸣歌", 11.0, ActiveType.VULN_ENEMY, 0.20, 5.0,
				"和声", PassiveType.KILL_RESONANCE, 5.0)
	return null
