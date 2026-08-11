class_name ArenaMin
extends Node3D
## 最小可玩竞技场（design/gdd/ux/opening-ui.md）。把 S0/S1/S4/S9 已有系统在一个场景里接通：
## 出战角色数值注入 → 样本模型 → 6 动词战斗 → 训练木桩 telegraph/格挡 → 共鸣池 → 角色技能。
##
## 本类是**宿主（host）**，不是新系统。纪律：
##   1. 战斗 FSM / 敌人 FSM 的推进只经各自 `physics_tick()`，本类不直接改任何状态。
##   2. 输入不自行仲裁——只吃 `InputManager.consume_buffered_verb()` 的裁决结果
##      （格 > 闪 > 斩 的唯一真相源在 InputManager，architecture §8）。
##   3. 伤害乘区只经 `SkillController.compute_damage()` 单点，不在本类复制公式。
##   4. 共鸣增益只经 `ResonancePool.add()`；扣池由 ResonateState 自理，本类不碰。
##   5. 不硬编码任何颜色——一律 `ColorTokens.*`（design/color-tokens.md v1.1）。
##   6. 不改任何窗口帧（CANCEL_WINDOW / PARRY_WINDOW / DASH_IFRAMES）。

# ─────────────────────────────────────────────────────────────
# 场景常量（表现层参数，非 GDD 数值真相源）
# ─────────────────────────────────────────────────────────────

const FLOOR_SIZE: float = 40.0
## 数值 → 世界单位换算：move_speed 100（基准）→ 6.0 m/s。
const MOVE_UNITS_PER_STAT: float = 0.06
const GRAVITY: float = 24.0
const LEAP_VELOCITY: float = 8.5
const DASH_SPEED: float = 18.0
const ATTACK_RANGE: float = 2.8
const SLASH_BASE_DAMAGE: int = 12
const FINISHER_BASE_DAMAGE: int = 60
## 木桩起手周期（秒）。Idle 满这么久就起 telegraph，给玩家练格挡。
const DUMMY_ATTACK_PERIOD: float = 4.0
const DUMMY_RESPAWN_DELAY: float = 2.0
const DUMMY_SPAWN_POS: Vector3 = Vector3(0.0, 0.0, -6.0)
const PLAYER_SPAWN_POS: Vector3 = Vector3(0.0, 0.0, 2.5)
const CAM_OFFSET: Vector3 = Vector3(0.0, 6.2, 8.4)
## 背击判定阈值：玩家→敌人向量与敌人面朝方向的点积超过此值即算绕到背后。
const BACK_HIT_DOT: float = 0.35
const RARITY_LABEL: Array[String] = ["N", "R", "SR", "SSR"]

# ─────────────────────────────────────────────────────────────
# 运行时
# ─────────────────────────────────────────────────────────────

var _rig: CharacterBody3D = null
var _player: PlayerCombat = null
var _model: CharacterModel = null
var _enemy: EnemyCombat = null
var _enemy_model: EnemyModel = null
var _skills: SkillController = null
var _cam: Camera3D = null
var _active: CharacterInstance = null

var _dash_frames_left: int = 0
var _dash_dir: Vector3 = Vector3.ZERO
var _dummy_clock: float = 0.0
var _respawn_clock: float = 0.0
var _last_enemy_state: StringName = &""
var _toast_clock: float = 0.0

var _lbl_char: Label = null
var _lbl_stats: Label = null
var _lbl_hp: Label = null
var _lbl_reso: Label = null
var _lbl_state: Label = null
var _lbl_skill: Label = null
var _lbl_enemy: Label = null
var _lbl_toast: Label = null


func _ready() -> void:
	# 「任何人打开就能玩」：空存档在此自动获得 N 档启动角色并出战（不消耗货币、不动保底）。
	_active = RosterAutoload.ensure_playable()
	_build_world()
	_build_player()
	_spawn_dummy()
	_build_camera()
	_build_hud()

	_skills = SkillController.new()
	_skills.name = "SkillController"
	add_child(_skills)
	_skills.request_dash.connect(_on_skill_dash)
	_skills.setup(_active, _player, _enemy)

	EventBus.enemy_died.connect(_on_enemy_died)
	_toast("R = 角色技能 · Q = 格挡 · F = 共鸣终结技")


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	# 场景切走时若仍在完美格慢动作里，必须复原时间缩放，否则主菜单会以 0.3× 运行。
	if _player != null:
		_player.end_time_dilation()


func _physics_process(delta: float) -> void:
	_route_input()
	_tick_movement(delta)
	_player.physics_tick(delta)
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.physics_tick(delta)
	_skills.tick(delta)
	_tick_dummy(delta)
	_update_camera(delta)
	_update_hud(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")
		return
	# 角色主动技能 = R。刻意不复用 6 动词键位：Q 已是完美格挡、F 已是共鸣终结技，
	# 技能是 S9 叠加层，不许挤占 S1 动词语义。
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		if _skills.activate():
			_toast("技能发动 · " + _skill_name())
		else:
			_toast("技能冷却中")


# ─────────────────────────────────────────────────────────────
# 输入路由（只消费 InputManager 的裁决结果）
# ─────────────────────────────────────────────────────────────

func _route_input() -> void:
	var verb: StringName = InputManager.consume_buffered_verb()
	if verb == &"":
		return
	match verb:
		InputManager.ACTION_PARRY:
			_player.input_parry()
		InputManager.ACTION_DASH:
			if _player.input_dash():
				_begin_dash(Vector3.ZERO)
		InputManager.ACTION_SLASH:
			if _player.input_slash():
				_resolve_slash()
		InputManager.ACTION_LEAP:
			if _player.input_leap():
				_rig.velocity.y = LEAP_VELOCITY
		InputManager.ACTION_GRAPPLE:
			_player.input_grapple()
		InputManager.ACTION_RESONATE:
			# 池不足时 input_resonate() 自己发 resonance_spend_rejected 并返回 false，
			# 扣池在 ResonateState._enter()——本类不碰池。
			if _player.input_resonate():
				_resolve_finisher()
			else:
				_toast("共鸣不足（需 %d）" % GameConstants.FINISHER_COST)


# ─────────────────────────────────────────────────────────────
# 移动
# ─────────────────────────────────────────────────────────────

func _tick_movement(delta: float) -> void:
	var mv: Vector2 = InputManager.get_move_vector()
	var dir: Vector3 = Vector3(mv.x, 0.0, mv.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var speed: float = _player.move_speed * MOVE_UNITS_PER_STAT * _skills.move_speed_modifier()
	var vel: Vector3 = _rig.velocity
	if _dash_frames_left > 0:
		_dash_frames_left -= 1
		vel.x = _dash_dir.x * DASH_SPEED
		vel.z = _dash_dir.z * DASH_SPEED
	else:
		vel.x = dir.x * speed
		vel.z = dir.z * speed

	if not _rig.is_on_floor():
		vel.y -= GRAVITY * delta
	elif vel.y < 0.0:
		vel.y = 0.0
	_rig.velocity = vel
	_rig.move_and_slide()

	if dir.length() > 0.05:
		# 模型正面朝 -Z，故用 (-x, -z) 求偏航。
		var yaw: float = atan2(-dir.x, -dir.z)
		_rig.rotation.y = lerp_angle(_rig.rotation.y, yaw, clampf(delta * 12.0, 0.0, 1.0))


func _begin_dash(forced_dir: Vector3) -> void:
	var d: Vector3 = forced_dir
	if d.length() < 0.01:
		var mv: Vector2 = InputManager.get_move_vector()
		d = Vector3(mv.x, 0.0, mv.y)
	if d.length() < 0.1:
		d = -_rig.global_transform.basis.z   # 无方向输入时朝正面冲
	_dash_dir = d.normalized()
	# 位移持续帧对齐无敌帧，让「闪避 = 穿过攻击」在观感上自洽（不修改 DASH_IFRAMES 本身）。
	_dash_frames_left = GameConstants.DASH_IFRAMES


func _on_skill_dash(impulse: Vector3) -> void:
	# 技能位移：impulse 在角色本地空间给出，转到世界再冲。
	var world: Vector3 = _rig.global_transform.basis * impulse
	world.y = 0.0
	_begin_dash(world)


# ─────────────────────────────────────────────────────────────
# 命中结算（arena 层；S1 战斗 FSM 与 PlayerCombat 未改一行）
# ─────────────────────────────────────────────────────────────

func _resolve_slash() -> void:
	if not _enemy_alive():
		return
	var to_enemy: Vector3 = _enemy.global_position - _rig.global_position
	to_enemy.y = 0.0
	if to_enemy.length() > ATTACK_RANGE:
		return
	# 背击 = 弱点：玩家→敌人的方向与敌人面朝同向时，说明玩家绕到了背后。
	var enemy_fwd: Vector3 = -_enemy.global_transform.basis.z
	var back_hit: bool = enemy_fwd.dot(to_enemy.normalized()) > BACK_HIT_DOT
	var dealt: int = _enemy.take_damage(_skills.compute_damage(SLASH_BASE_DAMAGE), back_hit)
	ResonancePool.add(GameConstants.GAIN_HIT, ResonancePool.SOURCE_HIT)
	ResonancePool.notify_combat_contact()
	if back_hit:
		_toast("弱点命中 ×%.1f  -%d" % [_enemy.definition.weakpoint_multiplier, dealt])
	else:
		_toast("命中 -%d" % dealt)


func _resolve_finisher() -> void:
	if not _enemy_alive():
		_toast("共鸣终结技 · 空挥")
		return
	var d: Vector3 = _enemy.global_position - _rig.global_position
	d.y = 0.0
	if d.length() > ATTACK_RANGE * 2.0:
		_toast("共鸣终结技 · 未命中")
		return
	var dealt: int = _enemy.take_damage(_skills.compute_damage(FINISHER_BASE_DAMAGE))
	_toast("共鸣终结技！-%d" % dealt)


## 木桩挥出攻击的那一帧。先问完美格（PARRY_WINDOW 内且 armed 才算），
## 不成立再按定义伤害结算——训练木桩 attack_damage = 0，故失败也不掉血，可反复练。
func _resolve_enemy_strike() -> void:
	if _player.parry_incoming(_enemy):
		_toast("完美格挡！+%d 共鸣 · 破防 %d 帧"
			% [GameConstants.GAIN_PERFECT_PARRY, GameConstants.ENEMY_STAGGER_FRAMES])
		return
	var dmg: int = 0
	if _enemy.definition != null:
		dmg = _enemy.definition.attack_damage
	if dmg <= 0:
		_toast("木桩挥空（训练弹 0 伤害，可反复练格挡）")
		return
	var taken: int = _player.take_damage(dmg)
	if taken > 0:
		_player.take_hit(GameConstants.HITSTUN_MAX_FRAMES)
		_toast("受击 -%d" % taken)
	else:
		_toast("无敌帧免疫")


# ─────────────────────────────────────────────────────────────
# 训练木桩
# ─────────────────────────────────────────────────────────────

func _tick_dummy(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.hp <= 0:
		_respawn_clock -= delta
		if _respawn_clock <= 0.0:
			_replace_dummy()
		return

	var st: StringName = _enemy.current_state_name()
	# Telegraph 自然收尽会转 Attack；捕捉「刚进 Attack」这一帧做格挡/伤害结算。
	if st == EnemyCombat.STATE_ATTACK and _last_enemy_state != EnemyCombat.STATE_ATTACK:
		_resolve_enemy_strike()
	_last_enemy_state = st

	if st == EnemyCombat.STATE_IDLE:
		_dummy_clock += delta
		if _dummy_clock >= DUMMY_ATTACK_PERIOD:
			_dummy_clock = 0.0
			_enemy.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)
	else:
		_dummy_clock = 0.0


func _on_enemy_died(who: Node3D) -> void:
	if who != _enemy:
		return
	_respawn_clock = DUMMY_RESPAWN_DELAY
	_toast("木桩已破坏 · %.0f 秒后重置" % DUMMY_RESPAWN_DELAY)


## Dead 是终态（邻接表无出边），故重置木桩 = 换一个新实例，而不是把死态硬拽回 Idle。
func _replace_dummy() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null
	_spawn_dummy()
	_skills.set_enemy(_enemy)
	_last_enemy_state = &""
	_dummy_clock = 0.0


func _spawn_dummy() -> void:
	var def := load("res://game/resources/enemy_defs/dummy.tres") as EnemyDefinition
	_enemy = EnemyCombat.new()
	_enemy.name = "Dummy"
	# 必须在入树前灌定义：EnemyCombat._ready() 会用空定义抢先 initialize()（幂等自锁）。
	_enemy.initialize(def)
	_enemy.position = DUMMY_SPAWN_POS
	# 面朝 +Z（玩家出生方向），这样「绕到背后」才是玩家要主动做的事。
	_enemy.rotation.y = PI
	add_child(_enemy)

	_enemy_model = EnemyModel.new()
	_enemy_model.name = "Model"
	_enemy.add_child(_enemy_model)
	_enemy_model.build(&"dummy")


func _enemy_alive() -> bool:
	return _enemy != null and is_instance_valid(_enemy) and _enemy.hp > 0


# ─────────────────────────────────────────────────────────────
# 场景搭建
# ─────────────────────────────────────────────────────────────

func _build_world() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ColorTokens.UI_BG.lightened(0.12)
	mat.roughness = 0.92
	ground.material_override = mat
	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(col)
	add_child(body)

	# 攻击距离参考环（贴地）。用中性 INACTIVE，绝不用 THREAT——那是敌意专属色。
	var ring := MeshInstance3D.new()
	ring.name = "RangeRing"
	var torus := TorusMesh.new()
	torus.inner_radius = ATTACK_RANGE - 0.06
	torus.outer_radius = ATTACK_RANGE
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = ColorTokens.INACTIVE
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color.a = 0.55
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.position = DUMMY_SPAWN_POS + Vector3(0.0, 0.02, 0.0)
	add_child(ring)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _build_player() -> void:
	_rig = CharacterBody3D.new()
	_rig.name = "PlayerRig"
	_rig.position = PLAYER_SPAWN_POS
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	_rig.add_child(col)
	add_child(_rig)

	_model = CharacterModel.new()
	_model.name = "Model"
	_rig.add_child(_model)
	var model_id: StringName = &"__player__"
	if _active != null:
		model_id = _active.character_id
	_model.build(model_id)

	_player = PlayerCombat.new()
	_player.name = "PlayerCombat"
	_rig.add_child(_player)
	if _active != null:
		_player.apply_character_stats(_active)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = 62.0
	_cam.current = true
	add_child(_cam)
	# 首帧直接吸附，避免 look_at 与自身位置重合报错。
	_cam.global_position = _rig.global_position + CAM_OFFSET
	_cam.look_at(_rig.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _update_camera(delta: float) -> void:
	var target: Vector3 = _rig.global_position + CAM_OFFSET
	_cam.global_position = _cam.global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	_cam.look_at(_rig.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)


# ─────────────────────────────────────────────────────────────
# HUD（复用 S1 既有信号语义，不新增 HUD 元素类型）
# ─────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_lbl_char = _hud_label(layer, ColorTokens.FRIENDLY_GOLD, 26, Vector2(24.0, 18.0))
	_lbl_stats = _hud_label(layer, ColorTokens.PLAYER_ALLY_MAIN, 16, Vector2(24.0, 54.0))
	_lbl_hp = _hud_label(layer, ColorTokens.PLAYER_ALLY_MAIN, 20, Vector2(24.0, 82.0))
	_lbl_reso = _hud_label(layer, ColorTokens.RESONANCE_GLOW, 20, Vector2(24.0, 112.0))
	_lbl_state = _hud_label(layer, ColorTokens.INACTIVE, 15, Vector2(24.0, 142.0))
	_lbl_skill = _hud_label(layer, ColorTokens.FRIENDLY_CORAL, 17, Vector2(24.0, 166.0))
	# 敌人信息独占 THREAT 语义色（敌意专属，design/color-tokens.md v1.1 锁定）。
	_lbl_enemy = _hud_label(layer, ColorTokens.THREAT, 20, Vector2(24.0, 200.0))
	_lbl_toast = _hud_label(layer, ColorTokens.FRIENDLY_GOLD, 22, Vector2(24.0, 240.0))

	var help := _hud_label(layer, ColorTokens.INACTIVE, 15, Vector2(24.0, 632.0))
	help.text = "WASD 移动 · 左键 斩 · Shift/右键 闪 · 空格 跃 · Q 格挡 · E 荡 · F 共鸣终结技 · R 角色技能 · Esc 返回菜单"


func _hud_label(layer: CanvasLayer, color: Color, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", ColorTokens.UI_BG)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l


func _update_hud(delta: float) -> void:
	if _active != null:
		_lbl_char.text = "%s · %s(%s)" % [
			_active.display_name,
			GachaConstants.RARITY_NAME[_active.rarity],
			RARITY_LABEL[_active.rarity],
		]
		_lbl_stats.text = "HP %d  攻 %d  防 %d  速 %d  共鸣亲和 %d   |  roll 攻%.1f%% 防%.1f%% 亲和%.1f%%" % [
			_active.final_hp, _active.final_attack, _active.final_defense,
			_active.final_move_speed, _active.final_affinity,
			_active.roll_atk_milli / 10.0, _active.roll_def_milli / 10.0, _active.roll_aff_milli / 10.0,
		]
	else:
		_lbl_char.text = "未选出战角色（默认数值）"
		_lbl_stats.text = ""

	_lbl_hp.text = "生命 %d / %d" % [_player.hp, _player.max_hp]

	# 共鸣三态配色（GDD S6 §⑤）：≥终结 / ≥门 / 其余，颜色全部取自 ColorTokens。
	var cur: int = ResonancePool.current
	var reso_color: Color = ColorTokens.INACTIVE
	if cur >= GameConstants.FINISHER_COST:
		reso_color = ColorTokens.RESONANCE_GLOW
	elif cur >= GameConstants.GATE_COST:
		reso_color = ColorTokens.GATE_READY
	_lbl_reso.add_theme_color_override("font_color", reso_color)
	_lbl_reso.text = "共鸣 %d   (门 %d / 终结 %d — 同池互斥)" % [
		cur, GameConstants.GATE_COST, GameConstants.FINISHER_COST
	]

	_lbl_state.text = "状态 %s" % String(_player.current_state_name())
	_lbl_skill.text = "R · %s   %s" % [_skill_name(), _skill_cd_text()]

	if _enemy != null and is_instance_valid(_enemy):
		_lbl_enemy.text = "训练木桩 %d / %d   [%s]" % [
			_enemy.hp, _enemy.max_hp, String(_enemy.current_state_name())
		]
	else:
		_lbl_enemy.text = ""

	if _toast_clock > 0.0:
		_toast_clock -= delta
		if _toast_clock <= 0.0:
			_lbl_toast.text = ""


func _skill_name() -> String:
	if _active == null:
		return "无（未选角色）"
	var s := CharacterSkillSet.of(_active.character_id)
	if s == null:
		return "无"
	return s.active_name


func _skill_cd_text() -> String:
	var cd: float = _skills.cooldown_remaining()
	if cd <= 0.0:
		return "就绪"
	return "冷却 %.1fs" % cd


func _toast(msg: String) -> void:
	if _lbl_toast == null:
		return
	_lbl_toast.text = msg
	_toast_clock = 1.8
