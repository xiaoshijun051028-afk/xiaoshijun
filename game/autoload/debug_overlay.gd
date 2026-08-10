extends CanvasLayer
## DebugOverlay · Autoload #8
##
## 职责（ENG-S0-05 第 8 项 / ENG-S0-12 / control-checklist §L / test-plan §4 出口 8）：
##   F3 切换；显示帧时间、物理 tick 占用、draw call、三角数、粒子实例数、
##   **当前状态机状态名**、**共鸣池值**；任一项超 architecture.md §7.3 预算 → 红字告警。
##
## 依赖：1 GameConstants、2 EventBus、3 ResonancePool、5 InputManager。位列第 8，依赖全部就绪。
## release 剥离：`OS.has_feature("debug_overlay")` 为假且非 debug 构建时，`_ready()` 直接
##   `queue_free()` 自身内容并停止 `_process` —— 发行包里不留任何运行时开销。
##
## 纪律：
##   - 只读游戏状态，**绝不写**。不改共鸣池、不发 EventBus 信号。
##   - 刷新走 `_process`（表现层），不占 `_physics_process` 帧预算。
##   - 状态机状态名走 EventBus.player_state_entered 被动接收，**不主动搜场景树**。

## 面板刷新间隔（渲染帧）。不需要每帧刷字符串。
const REFRESH_EVERY_FRAMES: int = 6

## 超预算高亮色 Token 名（不写 hex —— 走 ColorTokens）。
const TOKEN_ALERT: StringName = &"DAMAGE_WARN"
const TOKEN_NORMAL: StringName = &"PLAYER_ALLY_MAIN"
const TOKEN_PANEL_BG: StringName = &"UI_BG"

var _enabled: bool = false
var _stripped: bool = false
var _frame_accum: int = 0
var _label: RichTextLabel = null
var _panel: PanelContainer = null

## 由 EventBus 被动接收的状态机状态名（test-plan 出口 8 要求可见）。
var _fsm_state: StringName = &"<none>"

## 帧时间滑窗（毫秒），长度 = 1 秒。
var _frame_ms_window: PackedFloat32Array = PackedFloat32Array()


var is_visible_overlay: bool:
	get:
		return _enabled


func _ready() -> void:
	# —— release 剥离 ——
	if not _should_exist():
		_stripped = true
		set_process(false)
		set_process_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128  # 永远在最上层
	_build_ui()
	visible = false
	set_process(true)
	EventBus.player_state_entered.connect(_on_player_state_entered)


func _should_exist() -> bool:
	if OS.has_feature("editor"):
		return true
	if OS.is_debug_build():
		return true
	# 自定义 feature tag：导出预设里勾 `debug_overlay` 才在 release 保留。
	return OS.has_feature("debug_overlay")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	var bg: Color = ColorTokens.get_token(TOKEN_PANEL_BG)
	bg.a = 0.78
	style.bg_color = bg
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(360, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ux-spec F3：调试面板不受 HUD 字号底线约束，但保持可读。
	_label.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_label)
	add_child(_panel)


func _input(event: InputEvent) -> void:
	if _stripped:
		return
	if event.is_action_pressed(InputManager.ACTION_DEBUG_OVERLAY):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _stripped:
		return
	_enabled = not _enabled
	visible = _enabled
	if _enabled:
		_refresh()


func _process(_delta: float) -> void:
	if _stripped or not _enabled:
		return
	_frame_accum += 1
	if _frame_accum < REFRESH_EVERY_FRAMES:
		return
	_frame_accum = 0
	_refresh()


func _on_player_state_entered(state_name: StringName) -> void:
	_fsm_state = state_name


## ─────────────────────────────────────────────────────────────
## 采样与渲染
## ─────────────────────────────────────────────────────────────

func _refresh() -> void:
	var m: Dictionary = sample_metrics()
	_label.text = _format(m)


## 采样一份指标快照。**公开**，供 tools/perf_report.gd 与 test_debug_overlay.gd 复用，
## 避免性能脚本与面板各写一套采样口径（第二真相源）。
func sample_metrics() -> Dictionary:
	var frame_ms: float = 1000.0 / maxf(1.0, Engine.get_frames_per_second())
	_frame_ms_window.append(frame_ms)
	if _frame_ms_window.size() > GameConstants.TICKS_PER_SECOND:
		_frame_ms_window.remove_at(0)

	return {
		"fps": Engine.get_frames_per_second(),
		"frame_ms": frame_ms,
		"frame_ms_p99": _percentile(_frame_ms_window, 0.99),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"triangles": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"audio_latency_ms": AudioServer.get_output_latency() * 1000.0,
		# —— test-plan 出口 8 硬性两项 ——
		"fsm_state": String(_fsm_state),
		"resonance": ResonancePool.current,
	}


func _percentile(arr: PackedFloat32Array, q: float) -> float:
	if arr.is_empty():
		return 0.0
	var copy: Array[float] = []
	for v: float in arr:
		copy.append(v)
	copy.sort()
	var idx: int = clampi(int(floor(q * float(copy.size() - 1))), 0, copy.size() - 1)
	return copy[idx]


func _format(m: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Aetherfall · DebugOverlay[/b]  (F3)")
	lines.append(_row(
		"FPS / frame",
		"%d  /  %.2f ms (p99 %.2f)" % [int(m["fps"]), float(m["frame_ms"]), float(m["frame_ms_p99"])],
		float(m["frame_ms"]) > GameConstants.BUDGET_FRAME_MS
	))
	lines.append(_row(
		"physics tick",
		"%.2f ms" % float(m["physics_ms"]),
		float(m["physics_ms"]) > GameConstants.BUDGET_CPU_MS
	))
	lines.append(_row("process", "%.2f ms" % float(m["process_ms"]), false))
	lines.append(_row(
		"draw calls",
		"%d / %d" % [int(m["draw_calls"]), GameConstants.BUDGET_DRAW_CALLS],
		int(m["draw_calls"]) > GameConstants.BUDGET_DRAW_CALLS
	))
	lines.append(_row(
		"triangles",
		"%d / %d" % [int(m["triangles"]), GameConstants.BUDGET_TRIANGLES],
		int(m["triangles"]) > GameConstants.BUDGET_TRIANGLES
	))
	lines.append(_row("nodes / objects", "%d / %d" % [int(m["nodes"]), int(m["objects"])], false))
	lines.append(_row("static mem", "%.1f MB" % float(m["static_mem_mb"]), false))
	lines.append("")
	# —— 出口 8 两项，单列强调 ——
	lines.append(_row("FSM state", String(m["fsm_state"]), false))
	lines.append(_row(
		"Resonance",
		"%d / %d   (gate %d ｜ finisher %d)" % [
			int(m["resonance"]),
			GameConstants.RESONANCE_MAX,
			GameConstants.GATE_COST,
			GameConstants.FINISHER_COST,
		],
		false
	))
	# [GAP-PERF-1] 粒子实例数：Godot 4.7 Performance 无内建 monitor，
	# 需 tools/perf_report.gd 遍历 GPUParticles3D 汇总 amount。待 SPIKE-2 实测接入。
	lines.append(_row("particles", "n/a  [GAP-PERF-1]", false))
	return "\n".join(lines)


func _row(key: String, value: String, over_budget: bool) -> String:
	var token: StringName = TOKEN_ALERT if over_budget else TOKEN_NORMAL
	var hex: String = ColorTokens.get_token(token).to_html(false)
	var mark: String = "  ▲OVER" if over_budget else ""
	return "%-16s [color=#%s]%s%s[/color]" % [key, hex, value, mark]


## gdUnit4 隔离用。
func reset_for_test() -> void:
	_enabled = false
	_fsm_state = &"<none>"
	_frame_accum = 0
	_frame_ms_window = PackedFloat32Array()
	if not _stripped:
		visible = false
