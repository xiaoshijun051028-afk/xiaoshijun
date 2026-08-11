extends GdUnitTestSuite
## S1/S9 专项第一步 · attack_power 接入伤害公式（deferred 专项的安全子集，不碰 S1 FSM 核心）。
## 验证 SkillController.compute_damage 消费 PlayerCombat.attack_power（基准 100）
## + 技能攻击增益(_attack_buff) + 敌人易伤(_enemy_vuln) 乘区，
## 且默认参数(attack_power=100 / 无增益 / 无易伤)下数值不变（向后兼容 S1 手感）。
##
## 注：核心「玩家基础攻击命中结算」(slash/leap/grapple → 敌人) 仍为独立 deferred 任务，
## 此处只让 attack_power 在已有技能伤害路径上生效。

func _make_sc(attack_power: int = 100) -> SkillController:
	var sc := SkillController.new()
	var pc := PlayerCombat.new()
	pc.initialize()
	pc.attack_power = attack_power
	# active_inst=null → 不构技能集、不连信号；仅注入 _player 供 compute_damage 读取攻击力。
	sc.setup(null, pc, null)
	add_child(sc)
	add_child(pc)
	return sc


## 默认 attack_power=100、无增益、无易伤 → 与改动前硬编码 20 完全一致（零回归）。
func test_default_attack_power_passthrough() -> void:
	assert_int(_make_sc(100).compute_damage(20)).is_equal(20)


## attack_power 线性缩放：150 → ×1.5 = 30；50 → ×0.5 = 10。
func test_attack_power_scales_damage() -> void:
	assert_int(_make_sc(150).compute_damage(20)).is_equal(30)
	assert_int(_make_sc(50).compute_damage(20)).is_equal(10)


## 技能攻击增益(乘区)生效：_attack_buff=1.5 → 20×1.5 = 30。
func test_attack_buff_multiplies() -> void:
	var sc := _make_sc(100)
	sc._attack_buff = 1.5
	assert_int(sc.compute_damage(20)).is_equal(30)


## 敌人易伤(乘区)生效：_enemy_vuln=2.0 → 20×2.0 = 40。
func test_enemy_vuln_multiplies() -> void:
	var sc := _make_sc(100)
	sc._enemy_vuln = 2.0
	assert_int(sc.compute_damage(20)).is_equal(40)


## 多乘区叠加：attack_power=150(×1.5) × 攻击增益 1.5 × 易伤 2.0 → 20×4.5 = 90。
func test_multipliers_stack() -> void:
	var sc := _make_sc(150)
	sc._attack_buff = 1.5
	sc._enemy_vuln = 2.0
	assert_int(sc.compute_damage(20)).is_equal(90)
