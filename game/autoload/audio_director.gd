extends Node
## AudioDirector · Autoload #6
##
## 职责（ENG-S0-05 第 6 项 / design/audio/audio-direction.md §5、§7.3、§7.4、§8）：
##   1. 建立总线树骨架（9 总线 + Reverb send），挂效果器：
##      Master → AudioEffectHardLimiter（ceiling −1 dBTP）
##      SFX     → AudioEffectLowPassFilter（idx 0，默认 20500Hz 透明，供慢动作下潜）
##      Ambience→ AudioEffectLowPassFilter（idx 0，默认 20500Hz 透明）
##   2. 订阅 EventBus 状态级/系统级信号（§7.4），翻译为播放请求。
##   3. `play_event()` 为公开 API，供 L1（AnimationPlayer Method Call Track / 局部信号）直调帧级音效。
##   4. `_ready()` 用 L3 权威查询 `ResonancePool.current` 建立共鸣听觉床初始三态。
##
## 依赖：**2 EventBus + 3 ResonancePool**（audio-direction §7.3 已请求把 architecture §4.3 的
##       「依赖 2」修订为「依赖 2,3」——ResonancePool 在第 3 位、早于本单例第 6 位，不破坏顺序）。
##       [DECISION-ENG-S1-01] 程基岩确认采纳：依赖 2,3。
## 绝不做：不改游戏状态、不写存档、**不发 EventBus 信号**（只订阅）、
##        不依赖 EchoDirector(#7) / DebugOverlay(#8)。
##
## Sprint 1 范围：**总线与接线骨架 + 事件路由表**。实际音频资产（.ogg/.wav）由阮和鸣在
## 后续 Sprint 交付；本单例此时对未注册的事件做安静降级（不报错、可选 verbose 日志）。

## ─────────────────────────────────────────────────────────────
## 总线名（唯一真相源：audio-direction.md §5.1）
## ─────────────────────────────────────────────────────────────

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_SFX_COMBAT: StringName = &"SFX_Combat"
const BUS_SFX_WORLD: StringName = &"SFX_World"
const BUS_SFX_RESONANCE: StringName = &"SFX_Resonance"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_UI: StringName = &"UI"
const BUS_VO: StringName = &"VO"
const BUS_REVERB: StringName = &"Reverb"

## 总线树：子 → 父。Master 无父。构建顺序 = 本表顺序（父必先于子）。
const BUS_TREE: Array[Dictionary] = [
	{"name": BUS_MUSIC, "parent": BUS_MASTER, "db": -8.0},
	{"name": BUS_SFX, "parent": BUS_MASTER, "db": -3.0},
	{"name": BUS_SFX_COMBAT, "parent": BUS_SFX, "db": 0.0},
	{"name": BUS_SFX_WORLD, "parent": BUS_SFX, "db": -4.0},
	{"name": BUS_SFX_RESONANCE, "parent": BUS_SFX, "db": -5.0},
	{"name": BUS_AMBIENCE, "parent": BUS_MASTER, "db": -18.0},
	{"name": BUS_UI, "parent": BUS_MASTER, "db": -6.0},
	{"name": BUS_VO, "parent": BUS_MASTER, "db": -3.0},
	{"name": BUS_REVERB, "parent": BUS_MASTER, "db": -6.0},
]

## 低通默认（透明）与慢动作值（audio-direction §8 表）。
const LOWPASS_TRANSPARENT_HZ: float = 20500.0
const LOWPASS_SLOWMO_SFX_HZ: float = 1800.0
const LOWPASS_SLOWMO_AMBIENCE_HZ: float = 1200.0
const LOWPASS_SLOWMO_RESONANCE: float = 0.6

## Master 限制器真峰上限（audio-direction §5.6）。
const MASTER_CEILING_DB: float = -1.0

## 慢动作期间 Music 额外让路量（audio-direction §8 ④）。
const SLOWMO_MUSIC_DUCK_DB: float = -3.0

## 暂停时的显式处理（不靠 time_scale，不靠 PROCESS_MODE 副作用）。
const PAUSE_MUSIC_DUCK_DB: float = -12.0
const PAUSE_AMBIENCE_DUCK_DB: float = -24.0

## 共鸣听觉床三态（audio-direction §4；阈值与 HUD 三态同源 GameConstants）。
enum ResonanceBed { INACTIVE, GATE_READY, FINISHER_READY }

## ─────────────────────────────────────────────────────────────
## 状态（仅音频侧状态，非游戏状态）
## ─────────────────────────────────────────────────────────────

var _bus_idx: Dictionary = {}
var _nominal_db: Dictionary = {}
var _bed_state: int = ResonanceBed.INACTIVE
var _sfx_lowpass: AudioEffectLowPassFilter = null
var _ambience_lowpass: AudioEffectLowPassFilter = null
var _is_paused: bool = false
var _in_slowmo: bool = false

## Sprint 1：事件 → 总线 的路由表（资产未到位时只记录路由，不播放）。
## key: event_id(StringName) -> bus(StringName)
var _event_routes: Dictionary = {}

## 未注册事件的观测（供 阮和鸣 对齐 audio-event-list.md，非报错）。
var _missing_events: Dictionary = {}


var resonance_bed: int:
	get:
		return _bed_state


func _ready() -> void:
	# 暂停菜单需要 UI 音与 duck 生效 → 本单例必须 ALWAYS。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bus_tree()
	_attach_effects()
	_register_default_routes()
	_connect_event_bus()
	# L3 权威查询：开局池值决定听觉床初始态，避免开局 50 点却听到「不足」层。
	_apply_resonance_bed(_bed_for_value(ResonancePool.current), true)


## ─────────────────────────────────────────────────────────────
## 总线树构建
## ─────────────────────────────────────────────────────────────

func _build_bus_tree() -> void:
	_bus_idx[BUS_MASTER] = 0
	_nominal_db[BUS_MASTER] = 0.0
	for spec: Dictionary in BUS_TREE:
		var bus_name: StringName = spec["name"] as StringName
		var parent_name: StringName = spec["parent"] as StringName
		var db: float = float(spec["db"])
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, String(bus_name))
		AudioServer.set_bus_send(idx, String(parent_name))
		AudioServer.set_bus_volume_db(idx, db)
		_bus_idx[bus_name] = idx
		_nominal_db[bus_name] = db


func _attach_effects() -> void:
	# Master：限制器安全网。
	var master_idx: int = 0
	if not _has_effect_of_type(master_idx, "AudioEffectHardLimiter"):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = MASTER_CEILING_DB
		AudioServer.add_bus_effect(master_idx, limiter, 0)

	# SFX：**S0 即预挂**低通，idx = 0（audio-direction §8 ①，慢动作直接改 cutoff）。
	_sfx_lowpass = _ensure_lowpass(bus_index(BUS_SFX))
	_ambience_lowpass = _ensure_lowpass(bus_index(BUS_AMBIENCE))


func _ensure_lowpass(idx: int) -> AudioEffectLowPassFilter:
	if idx < 0:
		return null
	var existing: AudioEffect = AudioServer.get_bus_effect(idx, 0)
	if existing is AudioEffectLowPassFilter:
		var lp0: AudioEffectLowPassFilter = existing as AudioEffectLowPassFilter
		lp0.cutoff_hz = LOWPASS_TRANSPARENT_HZ
		return lp0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = LOWPASS_TRANSPARENT_HZ
	AudioServer.add_bus_effect(idx, lp, 0)
	return lp


func _has_effect_of_type(bus: int, type_name: String) -> bool:
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == type_name:
			return true
	return false


func bus_index(bus_name: StringName) -> int:
	if _bus_idx.has(bus_name):
		return int(_bus_idx[bus_name])
	return AudioServer.get_bus_index(bus_name)


## 供 test_audio_bus_tree.gd 断言：9 总线全部存在且父子正确。
func bus_names() -> Array[StringName]:
	var names: Array[StringName] = [BUS_MASTER]
	for spec: Dictionary in BUS_TREE:
		names.append(spec["name"] as StringName)
	return names


## ─────────────────────────────────────────────────────────────
## EventBus 订阅（§7.4：一次性 connect，全程不解绑）
## ─────────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	# S3
	EventBus.resonance_changed.connect(_on_resonance_changed)
	EventBus.resonance_spend_rejected.connect(_on_resonance_spend_rejected)
	EventBus.resonance_node_consumed.connect(_on_resonance_node_consumed)
	# S1
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.player_state_entered.connect(_on_player_state_entered)
	EventBus.combo_advanced.connect(_on_combo_advanced)
	EventBus.perfect_parry_landed.connect(_on_perfect_parry_landed)
	EventBus.finisher_executed.connect(_on_finisher_executed)
	EventBus.combat_state_changed.connect(_on_combat_state_changed)
	# S4
	EventBus.enemy_telegraph_started.connect(_on_enemy_telegraph_started)
	EventBus.enemy_telegraph_cleared.connect(_on_enemy_telegraph_cleared)
	EventBus.enemy_staggered.connect(_on_enemy_staggered)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	# S5 / S8
	EventBus.gate_opened.connect(_on_gate_opened)
	EventBus.shrine_activated.connect(_on_shrine_activated)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.island_entered.connect(_on_island_entered)
	# S7
	EventBus.echo_triggered.connect(_on_echo_triggered)
	EventBus.echo_collected.connect(_on_echo_collected)
	# 系统
	EventBus.save_completed.connect(_on_save_completed)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	# 时间膨胀（audio-direction §8）
	EventBus.time_dilation_started.connect(_on_time_dilation_started)
	EventBus.time_dilation_ended.connect(_on_time_dilation_ended)


## ─────────────────────────────────────────────────────────────
## 共鸣听觉床（三态，阈值同源 GameConstants，无第二真相源）
## ─────────────────────────────────────────────────────────────

func _bed_for_value(value: int) -> int:
	if value >= GameConstants.FINISHER_COST:
		return ResonanceBed.FINISHER_READY
	if value >= GameConstants.GATE_COST:
		return ResonanceBed.GATE_READY
	return ResonanceBed.INACTIVE


func _apply_resonance_bed(next_state: int, force: bool) -> void:
	if next_state == _bed_state and not force:
		return
	_bed_state = next_state
	match next_state:
		ResonanceBed.FINISHER_READY:
			play_event(&"resonance_bed_finisher", BUS_SFX_RESONANCE)
		ResonanceBed.GATE_READY:
			play_event(&"resonance_bed_gate", BUS_SFX_RESONANCE)
		_:
			play_event(&"resonance_bed_inactive", BUS_SFX_RESONANCE)


## ─────────────────────────────────────────────────────────────
## 信号处理（Sprint 1：路由到事件 id，资产后续接）
## ─────────────────────────────────────────────────────────────

func _on_resonance_changed(new_value: int, _old_value: int) -> void:
	_apply_resonance_bed(_bed_for_value(new_value), false)


func _on_resonance_spend_rejected(_cost: int, _reason: StringName) -> void:
	play_event(&"resonance_denied", BUS_UI)


func _on_resonance_node_consumed(_node_id: StringName) -> void:
	play_event(&"resonance_node_absorb", BUS_SFX_RESONANCE)


func _on_player_hp_changed(new_hp: int, old_hp: int) -> void:
	if new_hp < old_hp:
		play_event(&"player_hurt", BUS_SFX_COMBAT)


func _on_player_state_entered(state_name: StringName) -> void:
	# §7.4 关键结论：6 动词的动作音效唯一 L2 挂点就是这里，按 state_name 分派。
	play_event(StringName("state_" + String(state_name).to_snake_case()), BUS_SFX_COMBAT)


func _on_combo_advanced(count: int) -> void:
	play_event(StringName("combo_%d" % count), BUS_SFX_COMBAT)


func _on_perfect_parry_landed(_target: Node3D) -> void:
	play_event(&"perfect_parry", BUS_SFX_COMBAT)


func _on_finisher_executed(_damage: int) -> void:
	play_event(&"finisher", BUS_SFX_COMBAT)


func _on_combat_state_changed(in_combat: bool) -> void:
	play_event(&"music_combat_enter" if in_combat else &"music_combat_exit", BUS_MUSIC)


func _on_enemy_telegraph_started(_enemy: Node3D, _frames: int) -> void:
	# telegraph 独占 2–5kHz，最高优先级，不可裁减（§5.4）。
	play_event(&"enemy_telegraph", BUS_SFX_COMBAT)


func _on_enemy_telegraph_cleared(_enemy: Node3D) -> void:
	pass


func _on_enemy_staggered(_enemy: Node3D, _frames: int) -> void:
	play_event(&"enemy_stagger", BUS_SFX_COMBAT)


func _on_enemy_died(_enemy: Node3D) -> void:
	play_event(&"enemy_death", BUS_SFX_COMBAT)


func _on_boss_phase_changed(phase: int) -> void:
	play_event(StringName("boss_phase_%d" % phase), BUS_MUSIC)


func _on_gate_opened(_gate_id: StringName) -> void:
	play_event(&"gate_open", BUS_SFX_WORLD)


func _on_shrine_activated(_shrine_id: StringName) -> void:
	play_event(&"shrine_activate", BUS_SFX_WORLD)


func _on_player_respawned(_shrine_id: StringName) -> void:
	play_event(&"respawn", BUS_SFX_WORLD)


func _on_island_entered(_island_id: StringName) -> void:
	play_event(&"ambience_island", BUS_AMBIENCE)


func _on_echo_triggered(_echo_id: StringName) -> void:
	# VO 驱动侧链 duck Music/Ambience（§5.3）。
	play_event(&"echo_vo", BUS_VO)


func _on_echo_collected(_echo_id: StringName, _total: int) -> void:
	play_event(&"echo_collected", BUS_UI)


func _on_save_completed(success: bool) -> void:
	play_event(&"save_ok" if success else &"save_fail", BUS_UI)


func _on_settings_changed(_key: StringName) -> void:
	apply_settings_from_save()


## 暂停：**显式** duck/mute，不依赖 Engine.time_scale 或节点 process_mode 的副作用。
func _on_game_paused() -> void:
	if _is_paused:
		return
	_is_paused = true
	_set_bus_db(BUS_MUSIC, float(_nominal_db[BUS_MUSIC]) + PAUSE_MUSIC_DUCK_DB)
	_set_bus_db(BUS_AMBIENCE, float(_nominal_db[BUS_AMBIENCE]) + PAUSE_AMBIENCE_DUCK_DB)
	AudioServer.set_bus_mute(bus_index(BUS_SFX), true)
	AudioServer.set_bus_mute(bus_index(BUS_VO), true)
	# UI 总线绝不静音——暂停菜单要有反馈音。


func _on_game_resumed() -> void:
	if not _is_paused:
		return
	_is_paused = false
	_set_bus_db(BUS_MUSIC, float(_nominal_db[BUS_MUSIC]))
	_set_bus_db(BUS_AMBIENCE, float(_nominal_db[BUS_AMBIENCE]))
	AudioServer.set_bus_mute(bus_index(BUS_SFX), false)
	AudioServer.set_bus_mute(bus_index(BUS_VO), false)


## 时间膨胀（慢动作）：只动低通 cutoff，不动 pitch（§8 决策 4：零额外语音、保节拍对齐）。
func _on_time_dilation_started(_scale: float, _duration_frames: int) -> void:
	_in_slowmo = true
	if _sfx_lowpass != null:
		_sfx_lowpass.cutoff_hz = LOWPASS_SLOWMO_SFX_HZ
		_sfx_lowpass.resonance = LOWPASS_SLOWMO_RESONANCE
	if _ambience_lowpass != null:
		_ambience_lowpass.cutoff_hz = LOWPASS_SLOWMO_AMBIENCE_HZ
	_set_bus_db(BUS_MUSIC, float(_nominal_db[BUS_MUSIC]) + SLOWMO_MUSIC_DUCK_DB)


func _on_time_dilation_ended() -> void:
	_in_slowmo = false
	if _sfx_lowpass != null:
		_sfx_lowpass.cutoff_hz = LOWPASS_TRANSPARENT_HZ
	if _ambience_lowpass != null:
		_ambience_lowpass.cutoff_hz = LOWPASS_TRANSPARENT_HZ
	if not _is_paused:
		_set_bus_db(BUS_MUSIC, float(_nominal_db[BUS_MUSIC]))


## ─────────────────────────────────────────────────────────────
## 公开 API
## ─────────────────────────────────────────────────────────────

## L1 直调入口（AnimationPlayer Method Call Track / 局部信号）。
## Sprint 1：无资产则安静降级并计数，供 阮和鸣 对齐 audio-event-list.md。
func play_event(event_id: StringName, bus_override: StringName = &"") -> void:
	var bus: StringName = bus_override
	if bus == &"":
		bus = _event_routes.get(event_id, BUS_SFX) as StringName
	if not _event_routes.has(event_id):
		_missing_events[event_id] = int(_missing_events.get(event_id, 0)) + 1
	# [GAP-AUDIO-1] 资产库未交付：此处仅确定路由，不实例化 AudioStreamPlayer。
	# 待 design/audio/audio-event-list.md 对应 .ogg/.wav 入库后补 §7.2 音源池实现。


## 从 SaveManager 读设置并应用（audio-direction §7.3 第 4 条）。
func apply_settings_from_save() -> void:
	var sm: Node = get_node_or_null(^"/root/SaveManager")
	if sm == null:
		return
	var settings: Dictionary = sm.call("get_settings") as Dictionary
	for bus_name: StringName in bus_names():
		var key: String = "volume_" + String(bus_name).to_lower()
		if settings.has(key):
			_set_bus_db(bus_name, float(settings[key]))
			_nominal_db[bus_name] = float(settings[key])


func _set_bus_db(bus_name: StringName, db: float) -> void:
	var idx: int = bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


## 供 test 与 阮和鸣 排查：哪些事件被调用过但没有路由/资产。
func get_missing_events() -> Dictionary:
	return _missing_events.duplicate()


func _register_default_routes() -> void:
	# Sprint 1 骨架路由表。真实清单以 design/audio/audio-event-list.md 为准，
	# 由 阮和鸣 在 Sprint 2 用 .tres 数据驱动替换（届时本函数删除）。
	_event_routes = {
		&"resonance_bed_inactive": BUS_SFX_RESONANCE,
		&"resonance_bed_gate": BUS_SFX_RESONANCE,
		&"resonance_bed_finisher": BUS_SFX_RESONANCE,
		&"resonance_node_absorb": BUS_SFX_RESONANCE,
		&"resonance_denied": BUS_UI,
		&"enemy_telegraph": BUS_SFX_COMBAT,
		&"enemy_stagger": BUS_SFX_COMBAT,
		&"enemy_death": BUS_SFX_COMBAT,
		&"perfect_parry": BUS_SFX_COMBAT,
		&"finisher": BUS_SFX_COMBAT,
		&"player_hurt": BUS_SFX_COMBAT,
		&"gate_open": BUS_SFX_WORLD,
		&"shrine_activate": BUS_SFX_WORLD,
		&"respawn": BUS_SFX_WORLD,
		&"echo_vo": BUS_VO,
		&"echo_collected": BUS_UI,
		&"save_ok": BUS_UI,
		&"save_fail": BUS_UI,
	}


## gdUnit4 隔离用。
func reset_for_test() -> void:
	_missing_events.clear()
	_is_paused = false
	_in_slowmo = false
	_bed_state = ResonanceBed.INACTIVE
	for bus_name: StringName in _nominal_db.keys():
		var idx: int = bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, float(_nominal_db[bus_name]))
