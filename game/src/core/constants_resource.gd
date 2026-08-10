@tool
class_name ConstantsResource
extends Resource
## ConstantsResource · `resources/constants/game_constants.tres` 的承载类（ENG-S0-07）。
##
## 为什么既有 `GameConstants`（Autoload const）又有这份 `.tres`：
##   - **const 段是唯一真相源**（ADR-002：常量不落地、不入档、不可运行时改）。
##   - `.tres` 只是**给设计侧（文策渊）在编辑器里看/调的镜像**，以及给数据驱动资源
##     （VerbDefinition / EnemyDefinition）做默认值引用。
##   - 二者若漂移 → `test/unit/test_constants_match_gdd.gd` **红**。这条测试是架构承重墙，
##     它同时守「.tres ↔ const」和「const ↔ systems-index §2」两道边。
##
## 因此：**改数值只改 systems-index §2 → 改 game_constants.gd → 再同步本 .tres**，
## 不允许反向（编辑器改 .tres 覆盖代码）。运行时**没有任何系统读这份 .tres 做玩法判定**。

## —— 时间基准 ——
@export var ticks_per_second: int = 60

## —— S1 战斗 ——
@export var cancel_window: int = 8
@export var parry_window: int = 6
@export var dash_iframes: int = 10
@export var cancel_window_min: int = 5
@export var cancel_window_assist: int = 10
@export var parry_slowmo_frames: int = 18
@export var parry_slowmo_msec: int = 300
@export var parry_slowmo_scale: float = 0.3
@export var hitstop_frames_min: int = 4
@export var hitstop_frames_max: int = 6
@export var finisher_uses_slowmo: bool = false

## —— S3 共鸣 ——
@export var resonance_max: int = 100
@export var resonance_initial: int = 50
@export var gate_cost: int = 30
@export var finisher_cost: int = 40
@export var gain_hit: int = 1
@export var gain_perfect_parry: int = 5
@export var gain_kill: int = 15
@export var gain_node: int = 10
@export var gain_out_of_combat_per_sec: int = 2
@export var node_cooldown_frames: int = 300
@export var out_of_combat_frames: int = 180
@export var gain_node_upgraded: int = 15
@export var gain_out_of_combat_per_sec_upgraded: int = 3

## —— 输入 ——
@export var input_buffer_frames: int = 6
@export var stick_deadzone: float = 0.2

## —— 派生 / 系统 ——
@export var hitstun_max_frames: int = 30
@export var enemy_stagger_frames: int = 72
@export var telegraph_frames_normal_min: int = 36
@export var telegraph_frames_normal_max: int = 72
@export var telegraph_frames_hard_min: int = 24
@export var telegraph_frames_hard_max: int = 48
@export var resonance_tide_period_frames_min: int = 5400
@export var resonance_tide_period_frames_max: int = 7200
@export var resonance_tide_period_frames_default: int = 6300

## —— 性能预算（architecture.md §7.3） ——
@export var budget_fps_target: int = 60
@export var budget_cpu_ms: float = 9.0
@export var budget_gpu_ms: float = 15.0
@export var budget_draw_calls: int = 1500
@export var budget_triangles: int = 2000000
@export var budget_particles: int = 30000
@export var budget_audio_voices: int = 64
@export var latency_budget_kbm_ms: int = 50
@export var latency_budget_gamepad_ms: int = 80


## 与 Autoload const 段逐字段比对。返回不一致字段名列表（空 = 一致）。
## 被 test_constants_match_gdd.gd 直接调用，避免测试里再抄一遍字段表（第三真相源）。
func diff_against_autoload(gc: Node) -> PackedStringArray:
	var mismatches: PackedStringArray = PackedStringArray()
	var pairs: Dictionary = {
		"TICKS_PER_SECOND": ticks_per_second,
		"CANCEL_WINDOW": cancel_window,
		"PARRY_WINDOW": parry_window,
		"DASH_IFRAMES": dash_iframes,
		"CANCEL_WINDOW_MIN": cancel_window_min,
		"CANCEL_WINDOW_ASSIST": cancel_window_assist,
		"PARRY_SLOWMO_FRAMES": parry_slowmo_frames,
		"PARRY_SLOWMO_MSEC": parry_slowmo_msec,
		"PARRY_SLOWMO_SCALE": parry_slowmo_scale,
		"HITSTOP_FRAMES_MIN": hitstop_frames_min,
		"HITSTOP_FRAMES_MAX": hitstop_frames_max,
		"FINISHER_USES_SLOWMO": finisher_uses_slowmo,
		"RESONANCE_MAX": resonance_max,
		"RESONANCE_INITIAL": resonance_initial,
		"GATE_COST": gate_cost,
		"FINISHER_COST": finisher_cost,
		"GAIN_HIT": gain_hit,
		"GAIN_PERFECT_PARRY": gain_perfect_parry,
		"GAIN_KILL": gain_kill,
		"GAIN_NODE": gain_node,
		"GAIN_OUT_OF_COMBAT_PER_SEC": gain_out_of_combat_per_sec,
		"NODE_COOLDOWN_FRAMES": node_cooldown_frames,
		"OUT_OF_COMBAT_FRAMES": out_of_combat_frames,
		"GAIN_NODE_UPGRADED": gain_node_upgraded,
		"GAIN_OUT_OF_COMBAT_PER_SEC_UPGRADED": gain_out_of_combat_per_sec_upgraded,
		"INPUT_BUFFER_FRAMES": input_buffer_frames,
		"STICK_DEADZONE": stick_deadzone,
		"HITSTUN_MAX_FRAMES": hitstun_max_frames,
		"ENEMY_STAGGER_FRAMES": enemy_stagger_frames,
		"TELEGRAPH_FRAMES_NORMAL_MIN": telegraph_frames_normal_min,
		"TELEGRAPH_FRAMES_NORMAL_MAX": telegraph_frames_normal_max,
		"TELEGRAPH_FRAMES_HARD_MIN": telegraph_frames_hard_min,
		"TELEGRAPH_FRAMES_HARD_MAX": telegraph_frames_hard_max,
		"RESONANCE_TIDE_PERIOD_FRAMES_MIN": resonance_tide_period_frames_min,
		"RESONANCE_TIDE_PERIOD_FRAMES_MAX": resonance_tide_period_frames_max,
		"RESONANCE_TIDE_PERIOD_FRAMES_DEFAULT": resonance_tide_period_frames_default,
		"BUDGET_FPS_TARGET": budget_fps_target,
		"BUDGET_CPU_MS": budget_cpu_ms,
		"BUDGET_GPU_MS": budget_gpu_ms,
		"BUDGET_DRAW_CALLS": budget_draw_calls,
		"BUDGET_TRIANGLES": budget_triangles,
		"BUDGET_PARTICLES": budget_particles,
		"BUDGET_AUDIO_VOICES": budget_audio_voices,
		"LATENCY_BUDGET_KBM_MS": latency_budget_kbm_ms,
		"LATENCY_BUDGET_GAMEPAD_MS": latency_budget_gamepad_ms,
	}
	for const_name: String in pairs.keys():
		var expected: Variant = pairs[const_name]
		var actual: Variant = gc.get(const_name)
		if actual == null:
			mismatches.append("%s: Autoload 缺该常量" % const_name)
			continue
		if typeof(expected) == TYPE_FLOAT or typeof(actual) == TYPE_FLOAT:
			if not is_equal_approx(float(expected), float(actual)):
				mismatches.append("%s: tres=%s autoload=%s" % [const_name, expected, actual])
		elif expected != actual:
			mismatches.append("%s: tres=%s autoload=%s" % [const_name, expected, actual])
	return mismatches
