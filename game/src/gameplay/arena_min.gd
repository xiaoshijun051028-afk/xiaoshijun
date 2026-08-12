class_name ArenaMin
extends Node3D
## 最小可玩竞技场（design/gdd/ux/opening-ui.md）。把 S0/S1/S4/S9 已有系统在一个场景里接通：
## 出战角色数值注入 → 样本模型 → 6 动词战斗 → 真敌人波次（逼近/起手/格挡）→ 共鸣池 → 角色技能。
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
## RangeRing 参考环定位用（仅表现）。
const DUMMY_SPAWN_POS: Vector3 = Vector3(0.0, 0.0, -6.0)
const PLAYER_SPAWN_POS: Vector3 = Vector3(0.0, 0.0, 2.5)
const CAM_OFFSET: Vector3 = Vector3(0.0, 6.2, 8.4)
## 背击判定阈值：玩家→敌人向量与敌人面朝方向的点积超过此值即算绕到背后。
const BACK_HIT_DOT: float = 0.35
const RARITY_LABEL: Array[String] = ["N", "R", "SR", "SSR"]

## ── 波次 / 真敌人生存参数 ──
const WAVE_SIZE: int = 3
const WAVE_DELAY: float = 2.5
## 敌人进入此距离即起手攻击（xz 平面）。
const ENEMY_ATTACK_RANGE: float = 2.6
## 在攻击距离内 Idle 满此秒数则起手 telegraph。
const ENEMY_ATTACK_PERIOD: float = 2.2
const ENEMY_SPAWN_Z: float = -6.0
const ENEMY_SPAWN_X: Array[float] = [-3.0, 0.0, 3.0]
const ENEMY_TYPES: Array[StringName] = [&"brute", &"skirmisher", &"sentinel"]
## 竞技场半宽与边界留白（敌人 clamp / 墙定位用）。
const ARENA_HALF: float = FLOOR_SIZE * 0.5
const BOUND_MARGIN: float = 1.0

# ─────────────────────────────────────────────────────────────
# 运行时
# ─────────────────────────────────────────────────────────────

var _rig: CharacterBody3D = null
var _player: PlayerCombat = null
var _model: CharacterModel = null
## 场上所有存活敌人。
var _enemies: Array[EnemyCombat] = []
## 当前目标（最近存活敌人），供技能控制器 / 斩击 / HUD 使用。
var _enemy: EnemyCombat = null
## 每敌运行时状态：{idle: float, last: StringName}。键为 EnemyCombat 实例。
var _enemy_rt: Dictionary = {}
var _skills: SkillController = null
var _cam: Camera3D = null
var _active: CharacterInstance = null
## 轻量战斗特效层（CombatVFX）。
var _vfx: CombatVFX = null

var _dash_frames_left: int = 0
var _dash_dir: Vector3 = Vector3.ZERO
var _wave_clock: float = 0.0
var _wave_pending: bool = false
var _wave_count: int = 0
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
	_spawn_wave()
	_build_camera()
	_build_hud()

	_vfx = CombatVFX.new()
	_vfx.name = "CombatVFX"
	add_child(_vfx)

	_skills = SkillController.new()
	_skills.name = "SkillController"
	add_child(_skills)
	_skills.request_dash.connect(_on_skill_dash)
	_skills.setup(_active, _player, _enemy)
	_update_target()

	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_telegraph_started.connect(_on_enemy_telegraph_started)
	EventBus.perfect_parry_landed.connect(_on_perfect_parry_vfx)
	_toast("R = 角色技能 · Q = 格挡 · F = 共鸣终结技")


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.enemy_telegraph_started.is_connected(_on_enemy_telegraph_started):
		EventBus.enemy_telegraph_started.disconnect(_on_enemy_telegraph_started)
	if EventBus.perfect_parry_landed.is_connected(_on_perfect_parry_vfx):
		EventBus.perfect_parry_landed.disconnect(_on_perfect_parry_vfx)
	# 场景切走时若仍在完美格慢动作里，必须复原时间缩放，否则主菜单会以 0.3× 运行。
	if _player != null:
		_player.end_time_dilation()


func _physics_process(delta: float) -> void:
	_route_input()
	_tick_movement(delta)
	_player.physics_tick(delta)
	for e in _enemies:
		if is_instance_valid(e):
			e.physics_tick(delta)
	_skills.tick(delta)
	_tick_enemies(delta)
	_tick_waves(delta)
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
			if _vfx != null:
				_vfx.skill_cast(_rig.global_position + Vector3(0.0, 1.0, 0.0))
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

	# 边界兜底：玩家被不可见墙挡，这里再夹一次防墙缝（不能掉下台子）。
	var plim := ARENA_HALF - 0.5
	_rig.global_position.x = clampf(_rig.global_position.x, -plim, plim)
	_rig.global_position.z = clampf(_rig.global_position.z, -plim, plim)

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
	if _vfx != null:
		_vfx.dash_trail(_rig.global_position + Vector3(0.0, 1.0, 0.0))


func _on_skill_dash(impulse: Vector3) -> void:
	# 技能位移：impulse 在角色本地空间给出，转到世界再冲。
	var world: Vector3 = _rig.global_transform.basis * impulse
	world.y = 0.0
	_begin_dash(world)


## 玩家正前方的挥砍特效锚点（贴地、约腰高），让斩击弧光始终出现在「面前」。
func _slash_fx_pos() -> Vector3:
	var fwd := -_rig.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0.0, 0.0, -1.0)
	return _rig.global_position + fwd * 1.2 + Vector3(0.0, 1.0, 0.0)


# ─────────────────────────────────────────────────────────────
# 命中结算（arena 层；S1 战斗 FSM 与 PlayerCombat 未改一行）
# ─────────────────────────────────────────────────────────────

func _resolve_slash() -> void:
	# 挥砍弧光：无论命中与否都展示，给玩家明确的「我挥了」反馈（解决「没有普攻特效」）。
	if _vfx != null:
		_vfx.slash(_slash_fx_pos())
	var target := _pick_target(ATTACK_RANGE)
	if target == null:
		return
	var to_enemy: Vector3 = target.global_position - _rig.global_position
	to_enemy.y = 0.0
	if to_enemy.length() > ATTACK_RANGE:
		return
	# 背击 = 弱点：玩家→敌人的方向与敌人面朝同向时，说明玩家绕到了背后。
	var enemy_fwd: Vector3 = -target.global_transform.basis.z
	var back_hit: bool = enemy_fwd.dot(to_enemy.normalized()) > BACK_HIT_DOT
	var dealt: int = target.take_damage(_skills.compute_damage(SLASH_BASE_DAMAGE), back_hit)
	ResonancePool.add(GameConstants.GAIN_HIT, ResonancePool.SOURCE_HIT)
	ResonancePool.notify_combat_contact()
	if dealt > 0:
		var model: Node = target.get_node_or_null("Model")
		if model != null and model.has_method("flash_hit"):
			model.flash_hit()
		if _vfx != null:
			_vfx.hit_impact(target.global_position + Vector3(0.0, 1.0, 0.0), ColorTokens.RESONANCE_GLOW)
			_vfx.damage_popup(target.global_position + Vector3(0.0, 1.7, 0.0), dealt, ColorTokens.RESONANCE_GLOW)
	if back_hit:
		_toast("弱点命中 ×%.1f  -%d" % [target.definition.weakpoint_multiplier, dealt])
	else:
		_toast("命中 -%d" % dealt)


func _resolve_finisher() -> void:
	var target := _pick_target(ATTACK_RANGE * 2.0)
	if target == null:
		_toast("共鸣终结技 · 空挥")
		return
	var d: Vector3 = target.global_position - _rig.global_position
	d.y = 0.0
	if d.length() > ATTACK_RANGE * 2.0:
		_toast("共鸣终结技 · 未命中")
		return
	var dealt: int = target.take_damage(_skills.compute_damage(FINISHER_BASE_DAMAGE))
	_toast("共鸣终结技！-%d" % dealt)
	if _vfx != null:
		_vfx.finisher(target.global_position + Vector3(0.0, 1.0, 0.0))
		var model: Node = target.get_node_or_null("Model")
		if model != null and model.has_method("flash_hit"):
			model.flash_hit()
		_vfx.damage_popup(target.global_position + Vector3(0.0, 1.9, 0.0), dealt, ColorTokens.RESONANCE_GLOW)


## 敌人挥出攻击的那一帧。先问完美格（PARRY_WINDOW 内且 armed 才算），
## 不成立再按定义伤害结算——真敌人 attack_damage > 0，故会真正掉血。
func _resolve_enemy_strike_for(enemy: EnemyCombat) -> void:
	if _player.parry_incoming(enemy):
		_toast("完美格挡！+%d 共鸣 · 破防 %d 帧"
			% [GameConstants.GAIN_PERFECT_PARRY, GameConstants.ENEMY_STAGGER_FRAMES])
		return
	var dmg: int = 0
	if enemy.definition != null:
		dmg = enemy.definition.attack_damage
	if dmg <= 0:
		_toast("攻击落空（0 伤害）")
		return
	var taken: int = _player.take_damage(dmg)
	if taken > 0:
		_player.take_hit(GameConstants.HITSTUN_MAX_FRAMES)
		_toast("受击 -%d" % taken)
		if _vfx != null:
			_vfx.hit_impact(_rig.global_position + Vector3(0.0, 1.0, 0.0), ColorTokens.THREAT)
	else:
		_toast("无敌帧免疫")


# ─────────────────────────────────────────────────────────────
# 真敌人波次（替换原训练木桩：进场即有敌、会逼近、会起手、清场刷下一波）
# ─────────────────────────────────────────────────────────────

## 每物理帧推进所有敌人：逼近 / 起手 telegraph / 捕捉 Attack 帧结算。
func _tick_enemies(delta: float) -> void:
	for e in _enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var to_p: Vector3 = _rig.global_position - e.global_position
		to_p.y = 0.0
		var dist: float = to_p.length()
		var rt: Dictionary = _enemy_rt.get(e, {})
		var last: StringName = rt.get("last", &"")
		var idle_clock: float = rt.get("idle", 0.0)
		var st: StringName = e.current_state_name()

		# Telegraph 自然收尽转 Attack；捕捉「刚进 Attack」这一帧做格挡/伤害结算。
		if st == EnemyCombat.STATE_ATTACK and last != EnemyCombat.STATE_ATTACK:
			_resolve_enemy_strike_for(e)

		if dist > ENEMY_ATTACK_RANGE:
			if dist > 0.001:
				var step_len: float = e.definition.move_speed * delta
				e.global_position += to_p.normalized() * step_len
				e.rotation.y = atan2(-to_p.x, -to_p.z)
			idle_clock = 0.0
		else:
			# 在攻击距离内：Idle 满周期则起手 telegraph。
			if st == EnemyCombat.STATE_IDLE:
				idle_clock += delta
				if idle_clock >= ENEMY_ATTACK_PERIOD:
					idle_clock = 0.0
					e.state_machine.try_transition(EnemyCombat.STATE_TELEGRAPH)
			else:
				idle_clock = 0.0

		rt["idle"] = idle_clock
		rt["last"] = st
		_enemy_rt[e] = rt

		# 边界 clamp：敌人直驱 global_position 不走碰撞，手动限制在场地内（不能掉下台子）。
		var lim := ARENA_HALF - BOUND_MARGIN
		e.global_position.x = clampf(e.global_position.x, -lim, lim)
		e.global_position.z = clampf(e.global_position.z, -lim, lim)


## 清场后延迟刷新下一波。
func _tick_waves(delta: float) -> void:
	if not _wave_pending:
		return
	_wave_clock -= delta
	if _wave_clock <= 0.0:
		_wave_pending = false
		_spawn_wave()


## 刷一波混合真敌人（brute/skirmisher/sentinel 轮流），x 轴散开、z 轴前置。
func _spawn_wave() -> void:
	_wave_count += 1
	for i in range(WAVE_SIZE):
		var type_id: StringName = ENEMY_TYPES[i % ENEMY_TYPES.size()]
		var def := load("res://game/resources/enemy_defs/%s.tres" % type_id) as EnemyDefinition
		var en := EnemyCombat.new()
		en.name = "Enemy_%d_%d" % [_wave_count, i]
		# 必须在入树前灌定义：EnemyCombat._ready() 会用空定义抢先 initialize()（幂等自锁）。
		en.initialize(def)
		var x: float = ENEMY_SPAWN_X[i] if i < ENEMY_SPAWN_X.size() else 0.0
		en.position = Vector3(x, 0.0, ENEMY_SPAWN_Z)
		# 面朝 +Z（玩家出生方向），这样「绕到背后」才是玩家要主动做的事。
		en.rotation.y = PI
		add_child(en)

		var model := EnemyModel.new()
		model.name = "Model"
		en.add_child(model)
		model.build(type_id)

		_enemies.append(en)
		_enemy_rt[en] = {"idle": 0.0, "last": &""}
	_update_target()
	_toast("第 %d 波 · %d 敌来袭" % [_wave_count, _enemies.size()])


func _on_enemy_died(who: Node3D) -> void:
	if who is EnemyCombat and who in _enemies:
		_enemies.erase(who)
		_enemy_rt.erase(who)
		who.queue_free()
	_update_target()
	if _enemies.is_empty():
		_wave_pending = true
		_wave_clock = WAVE_DELAY
		_toast("清场！%.0f 秒后下一波" % WAVE_DELAY)


## 每帧重选最近存活敌人为当前目标（供技能控制器 / 斩击 / HUD 使用）。
func _update_target() -> void:
	var best: EnemyCombat = null
	var best_d: float = INF
	for e in _enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var d: float = _rig.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	# 仅当目标变化时才通知技能控制器。
	if best != _enemy:
		_enemy = best
		if _skills != null:
			_skills.set_enemy(_enemy)


## 选攻击距离内最近敌人（斩击 / 终结技命中判定）。
func _pick_target(range_limit: float) -> EnemyCombat:
	var best: EnemyCombat = null
	var best_d: float = range_limit
	for e in _enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var d: float = _rig.global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


# ─────────────────────────────────────────────────────────────
# VFX 钩子（消费 EventBus 信号 + 直接调用 CombatVFX）
# ─────────────────────────────────────────────────────────────

func _on_enemy_telegraph_started(enemy: Node3D, _frames: int) -> void:
	if _vfx != null:
		_vfx.enemy_telegraph(enemy.global_position + Vector3(0.0, 0.15, 0.0), float(_frames) / 60.0)


func _on_perfect_parry_vfx(_attacker: Node3D) -> void:
	if _vfx != null:
		_vfx.perfect_parry(_rig.global_position + Vector3(0.0, 1.0, 0.0))


# ─────────────────────────────────────────────────────────────
# 测试用调试接口（仅供无头冒烟测试读取私有状态）
# ─────────────────────────────────────────────────────────────

func debug_enemy_count() -> int:
	return _enemies.size()


func debug_target() -> EnemyCombat:
	return _enemy


func debug_player_pos() -> Vector3:
	return _rig.global_position if _rig != null else Vector3.ZERO


func debug_force_slash() -> void:
	_resolve_slash()


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
	mat.albedo_color = ColorTokens.ENV_GRASS
	mat.roughness = 1.0
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

	# 草原环境：苍穹蓝天 + 远端淡雾（边界虚化，营造草原延伸至远方的错觉）。
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = ColorTokens.SKY_AZURE
	env_res.fog_enabled = true
	env_res.fog_light_color = ColorTokens.SKY_AZURE.lightened(0.12)
	env_res.fog_density = 0.014
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnv"
	world_env.environment = env_res
	add_child(world_env)

	# 程序化草丛（MultiMesh 单 draw call，零外部资源）。
	_spawn_grass()

	# 不可见边界墙：挡玩家（CharacterBody3D 走 move_and_slide 被挡）。
	# 敌人因直驱 global_position 不走碰撞，另在 _tick_enemies 做坐标 clamp。
	_build_bounds()

# 草丛随风轻摆着色器：根部不动、越高摆幅越大，相位按世界坐标错开使每丛不同步。
# 草绿取自 ColorTokens.ENV_GRASS（着色器参数注入，本文件不出现颜色字面量）。
const GRASS_SWAY_SHADER := """shader_type spatial;
uniform vec3 u_grass_color : source_color;
uniform float u_wind_speed : hint_range(0.0, 4.0) = 1.6;
uniform float u_wind_amp : hint_range(0.0, 0.5) = 0.12;
uniform float u_blade_height : hint_range(0.1, 3.0) = 0.85;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * INSTANCE_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp((VERTEX.y + (u_blade_height * 0.5)) / u_blade_height, 0.0, 1.0);
	float phase = world_pos.x * 0.6 + world_pos.z * 0.35;
	float sway = sin(TIME * u_wind_speed + phase) * u_wind_amp * h;
	float sway2 = cos(TIME * u_wind_speed * 0.7 + phase * 1.3) * (u_wind_amp * 0.5) * h;
	VERTEX.x += sway;
	VERTEX.z += sway2;
}

void fragment() {
	float h = clamp((VERTEX.y + (u_blade_height * 0.5)) / u_blade_height, 0.0, 1.0);
	ALBEDO = u_grass_color * (0.7 + 0.3 * h);
}
"""

func _spawn_grass() -> void:
	var field := MultiMeshInstance3D.new()
	field.name = "GrassField"
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.05
	blade.height = 0.85
	blade.radial_segments = 4
	var sh := Shader.new()
	sh.code = GRASS_SWAY_SHADER
	var gmat := ShaderMaterial.new()
	gmat.shader = sh
	gmat.set_shader_parameter("u_grass_color", ColorTokens.ENV_GRASS)
	gmat.set_shader_parameter("u_blade_height", blade.height)
	field.material_override = gmat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var n := 1500
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var half := ARENA_HALF - 1.5
	for i in n:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var p := Vector3(x, 0.0, z)
		# 避开玩家/敌人出生密集区，防草挡视线或穿模。
		if p.distance_to(PLAYER_SPAWN_POS) < 2.4 or p.distance_to(DUMMY_SPAWN_POS) < 3.2:
			x = rng.randf_range(half - 5.0, half) * (1.0 if rng.randf() < 0.5 else -1.0)
			z = rng.randf_range(half - 5.0, half) * (1.0 if rng.randf() < 0.5 else -1.0)
		var s := rng.randf_range(0.7, 1.5)
		var t := Transform3D().scaled(Vector3(s, s, s))
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t = t.translated(Vector3(x, 0.425 * s, z))
		mm.set_instance_transform(i, t)
	field.multimesh = mm
	add_child(field)

func _build_bounds() -> void:
	var half := ARENA_HALF
	var wall_h := 4.0
	var wall_t := 1.0
	var specs := [
		[0.0, half, FLOOR_SIZE + 2.0, wall_t],
		[0.0, -half, FLOOR_SIZE + 2.0, wall_t],
		[half, 0.0, wall_t, FLOOR_SIZE + 2.0],
		[-half, 0.0, wall_t, FLOOR_SIZE + 2.0],
	]
	for s in specs:
		var sb := StaticBody3D.new()
		sb.name = "BoundWall"
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(s[2], wall_h, s[3])
		col.shape = box
		col.position = Vector3(s[0], wall_h * 0.5, s[1])
		sb.add_child(col)
		add_child(sb)

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
		_lbl_enemy.text = "%s  %d / %d   [%s]" % [
			String(_enemy.definition.enemy_id), _enemy.hp, _enemy.max_hp, String(_enemy.current_state_name())
		]
	elif _wave_pending:
		_lbl_enemy.text = "下一波来袭…"
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
