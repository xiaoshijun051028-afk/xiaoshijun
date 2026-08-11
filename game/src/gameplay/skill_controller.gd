class_name SkillController
extends Node
## 技能运行时（最小可用，arena 内演示）。读取出战角色技能集，处理主动 CD 与被动钩子。
## 主动效果为表现侧增益 / 治疗 / 共鸣 / 位移。
##
## 与伤害公式的边界（守 gacha.md §6.1 红线）：
##   - 绝不修改任何窗口帧（CANCEL_WINDOW / PARRY_WINDOW / DASH_IFRAMES）。
##   - 共鸣池只经 ResonancePool.add() 入口；不改动 GATE_COST / FINISHER_COST。
##   - 攻击增益以「乘区」形式暴露给 arena，由 arena 结算命中时乘入，不写死进 PlayerCombat。
##   - attack_power（S9 注入 PlayerCombat.attack_power，基准 100）经 `_compute_damage()` 乘入技能伤害；
##     核心「玩家基础攻击命中结算」(slash/leap/grapple → 敌人) 仍 deferred（触碰 S1 FSM 核心，需 arena 层 + 试玩），
##     本运行时只让 attack_power 在已有伤害路径上生效，不新增命中判定。

signal request_dash(impulse: Vector3)

var _set: CharacterSkillSet = null
var _player: PlayerCombat = null
var _enemy: EnemyCombat = null

var _cd_remaining: float = 0.0
var _attack_buff: float = 1.0
var _attack_buff_t: float = 0.0
var _defense_buff: float = 1.0
var _defense_buff_t: float = 0.0
var _enemy_vuln: float = 1.0
var _enemy_vuln_t: float = 0.0
var _base_defense: int = 100
var _low_hp: bool = false
var _move_mult: float = 1.0


func setup(active_inst: CharacterInstance, player: PlayerCombat, enemy: EnemyCombat) -> void:
	_player = player
	_enemy = enemy
	if active_inst != null:
		_set = CharacterSkillSet.of(active_inst.character_id)
	if _set == null:
		return
	if _set.passive_type == CharacterSkillSet.PassiveType.LOW_HP_DEFENSE:
		_base_defense = _player.defense
	EventBus.perfect_parry_landed.connect(_on_perfect_parry)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)


## 换绑当前目标敌人（arena 重置木桩后调用）。不重连信号——EventBus 订阅与具体敌人无关。
func set_enemy(enemy: EnemyCombat) -> void:
	_enemy = enemy


## 每物理帧推进 CD 与增益计时。
func tick(delta: float) -> void:
	if _set == null:
		return
	if _cd_remaining > 0.0:
		_cd_remaining = maxf(0.0, _cd_remaining - delta)
	if _attack_buff_t > 0.0:
		_attack_buff_t -= delta
		if _attack_buff_t <= 0.0:
			_attack_buff = 1.0
	if _defense_buff_t > 0.0:
		_defense_buff_t -= delta
		if _defense_buff_t <= 0.0:
			_defense_buff = 1.0
			_apply_defense()
	if _enemy_vuln_t > 0.0:
		_enemy_vuln_t -= delta
		if _enemy_vuln_t <= 0.0:
			_enemy_vuln = 1.0


## 触发主动技能（Q）。CD 就绪才生效，返回是否成功触发。
func activate() -> bool:
	if _set == null or _cd_remaining > 0.0:
		return false
	_cd_remaining = _set.active_cd_seconds
	match _set.active_type:
		CharacterSkillSet.ActiveType.BUFF_ATTACK:
			_attack_buff = 1.0 + _set.active_magnitude
			_attack_buff_t = _set.active_duration
		CharacterSkillSet.ActiveType.BUFF_DEFENSE:
			_defense_buff = 1.0 + _set.active_magnitude
			_defense_buff_t = _set.active_duration
			_apply_defense()
		CharacterSkillSet.ActiveType.DASH:
			request_dash.emit(Vector3(0, 0, -3.0))
		CharacterSkillSet.ActiveType.AOE_KNOCKBACK:
			request_dash.emit(Vector3(0, 0, 2.0))
			if _enemy != null and _enemy.hp > 0:
				_enemy.take_damage(compute_damage(20))
		CharacterSkillSet.ActiveType.ADD_RESONANCE:
			ResonancePool.add(int(roundf(_set.active_magnitude)), ResonancePool.SOURCE_NODE)
		CharacterSkillSet.ActiveType.VULN_ENEMY:
			_enemy_vuln = 1.0 + _set.active_magnitude
			_enemy_vuln_t = _set.active_duration
	return true


func attack_modifier() -> float:
	return _attack_buff


func move_speed_modifier() -> float:
	return _move_mult


func enemy_vuln() -> float:
	return _enemy_vuln


## 伤害结算：基础值 × 攻击增益(技能) × 敌人易伤(技能) × 出战攻击力系数。
## 出战攻击力系数 = PlayerCombat.attack_power / 100（S9 注入，基准 100）；
## 默认 attack_power=100、无增益、无易伤时 = base（向后兼容，不撼动 S1 手感）。
##
## **全局唯一的伤害乘区计算点**：arena 层的基础斩击 / 终结技命中也走这里，不另开第二份公式。
## 守红线：只消费乘区，不写死进 PlayerCombat（S1 战斗 FSM 未改一行），
## 不触碰任何窗口帧（CANCEL_WINDOW / PARRY_WINDOW / DASH_IFRAMES）。
## _set == null（未选角色）时依然可用：各乘区为 1.0，退化为 base × attack_power/100。
func compute_damage(base: int) -> int:
	var atk_factor: float = 1.0
	if _player != null:
		atk_factor = float(_player.attack_power) / 100.0
	return int(roundf(float(base) * _attack_buff * _enemy_vuln * atk_factor))


func cooldown_remaining() -> float:
	return _cd_remaining


func _apply_defense() -> void:
	if _player == null:
		return
	var d: float = float(_base_defense) * _defense_buff
	if _low_hp:
		d *= 1.2
	_player.defense = int(roundf(d))


func _on_perfect_parry(_target: Node3D) -> void:
	if _set == null or _set.passive_type != CharacterSkillSet.PassiveType.PARRY_HEAL:
		return
	if _player != null:
		_player.hp = mini(_player.max_hp, _player.hp + int(_set.passive_magnitude))


func _on_enemy_died(_e: Node3D) -> void:
	if _set == null or _set.passive_type != CharacterSkillSet.PassiveType.KILL_RESONANCE:
		return
	ResonancePool.add(int(roundf(_set.passive_magnitude)), ResonancePool.SOURCE_KILL)


func _on_player_hp_changed(new_hp: int, _old: int) -> void:
	if _set == null or _set.passive_type != CharacterSkillSet.PassiveType.LOW_HP_DEFENSE:
		return
	_low_hp = new_hp < int(float(_player.max_hp) * 0.3)
	_apply_defense()


func _exit_tree() -> void:
	if _set == null:
		return
	if EventBus.perfect_parry_landed.is_connected(_on_perfect_parry):
		EventBus.perfect_parry_landed.disconnect(_on_perfect_parry)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.player_hp_changed.is_connected(_on_player_hp_changed):
		EventBus.player_hp_changed.disconnect(_on_player_hp_changed)
