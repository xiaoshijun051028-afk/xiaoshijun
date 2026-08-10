extends Node
## InputManager · Autoload #5
##
## 职责（ENG-S0-09 / architecture.md §8 / control-checklist §H / ux-spec §1）：
##   1. 保证 InputMap 中全部动作存在（运行时自愈注册，测试不依赖 project.godot 是否被编辑器改坏）。
##   2. 键鼠 + 手柄双套默认映射。
##   3. 设备仲裁：区分 DEVICE_ID_KEYBOARD / DEVICE_ID_MOUSE / 手柄 device_id；摇杆死区防漂移。
##   4. 输入缓冲 ≤6 帧（GameConstants.INPUT_BUFFER_FRAMES）。
##   5. 优先级裁决 **格 > 闪 > 斩**——裁决在本单例完成，FSM 只问「这一帧该吃哪个动词」。
##   6. `E`/`A` 情境仲裁：有锚点 → verb_grapple；面向神龛/残响节点 → ui_interact。
##
## 纪律：
##   - 整数帧计时。缓冲寿命用 `_tick`（物理 tick 绝对值）差，不用秒、不用 Timer。
##   - 本单例 **不持有游戏状态**，只持有输入意图；不改共鸣池、不改 FSM。
##   - 不发 EventBus 信号（输入不是「已发生的事实」，是「玩家意图」，属 L1/L3）。
##   - 依赖：1 GameConstants。**不依赖** 2..8（可在 #5 位安全初始化）。
##
## 时间基准：1 tick ≡ 1 帧 ≡ 1/60s（architecture.md §3）。

## ─────────────────────────────────────────────────────────────
## 动作名（唯一真相源：design/ux/ux-spec.md §1.1）
## ─────────────────────────────────────────────────────────────

const ACTION_SLASH: StringName = &"verb_slash"
const ACTION_DASH: StringName = &"verb_dash"
const ACTION_GRAPPLE: StringName = &"verb_grapple"
const ACTION_LEAP: StringName = &"verb_leap"
const ACTION_PARRY: StringName = &"verb_parry"
const ACTION_RESONATE: StringName = &"verb_resonate"
const ACTION_LOCKON: StringName = &"verb_lockon"

const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"

const ACTION_UI_PAUSE: StringName = &"ui_pause"
const ACTION_UI_INTERACT: StringName = &"ui_interact"
const ACTION_UI_MAP: StringName = &"ui_map"
const ACTION_DEBUG_OVERLAY: StringName = &"debug_overlay"

## 6 动词 + lock-on + ui_interact —— 本单例做缓冲与仲裁的动作集合。
const BUFFERED_ACTIONS: Array[StringName] = [
	ACTION_SLASH,
	ACTION_DASH,
	ACTION_GRAPPLE,
	ACTION_LEAP,
	ACTION_PARRY,
	ACTION_RESONATE,
	ACTION_LOCKON,
	ACTION_UI_INTERACT,
]

## 优先级裁决顺序（control-checklist §H：格 > 闪 > 斩）。
## 同一帧多动词同时在缓冲中时，`consume_buffered_verb()` 按本表顺序取第一个。
## 未列入者（grapple/leap/resonate/lockon/interact）按「更早入缓冲者优先」兜底。
const VERB_PRIORITY: Array[StringName] = [
	ACTION_PARRY,
	ACTION_DASH,
	ACTION_SLASH,
]

## 设备类别（对外只暴露类别，不暴露 raw device id）。
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

## Godot 4.7 保留设备 ID（architecture.md §8.2）。
## 4.7 起 `InputEvent.device` 对键盘/鼠标使用这两个常量而非 0。
const DEVICE_ID_KEYBOARD: int = -1
const DEVICE_ID_MOUSE: int = -2

## ─────────────────────────────────────────────────────────────
## 状态（仅输入意图，非游戏状态）
## ─────────────────────────────────────────────────────────────

## 物理 tick 绝对计数。缓冲寿命全靠它做整数差。
var _tick: int = 0

## action -> 按下时的 tick 绝对值。过期由 `_is_fresh()` 判定，不做逐帧清扫。
var _buffer: Dictionary = {}

## 当前活跃设备类别（最后一次产生非噪声输入的设备）。
var _active_device: DeviceKind = DeviceKind.KEYBOARD_MOUSE

## 最后一次手柄输入的 device id（-1 表示尚未出现手柄）。
var _last_gamepad_id: int = -1

## E/A 情境仲裁的外部提示：由 CameraRig / 交互射线每帧写入。
## InputManager 自己不做射线（不持有世界知识），只做裁决。
var _context_has_anchor: bool = false
var _context_has_interactable: bool = false

## 测试用：为 true 时 `_input()` 不再改写 `_active_device`（避免 SceneRunner 注入干扰）。
var _device_lock_for_test: bool = false


## 只读：当前活跃设备类别。
var active_device: DeviceKind:
	get:
		return _active_device


## 只读：物理 tick 绝对计数（供测试对齐帧）。
var tick: int:
	get:
		return _tick


func _ready() -> void:
	# CONCERN-B 逃生门之一（architecture.md §7.5）：关闭输入累积，降低感知延迟。
	# SPIKE-1 若实测超标，此处是第一道可调项。
	Input.set_use_accumulated_input(false)
	_ensure_input_map()
	# InputManager 需要在暂停时仍能收 ui_pause / debug_overlay。
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	_tick += 1
	_poll_buffered_actions()


func _input(event: InputEvent) -> void:
	if _device_lock_for_test:
		return
	_arbitrate_device(event)


## ─────────────────────────────────────────────────────────────
## 设备仲裁
## ─────────────────────────────────────────────────────────────

## 判定「这条事件是否代表玩家真的在用这个设备」，避免摇杆漂移把活跃设备抢过去。
func _arbitrate_device(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		_set_device(DeviceKind.KEYBOARD_MOUSE)
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		# 鼠标微抖不算切换设备（手柄玩家桌面震动会误触发）。
		if motion.relative.length() > 2.0:
			_set_device(DeviceKind.KEYBOARD_MOUSE)
		return
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event as InputEventJoypadButton
		_last_gamepad_id = jb.device
		_set_device(DeviceKind.GAMEPAD)
		return
	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event as InputEventJoypadMotion
		# 死区防漂移：低于 STICK_DEADZONE 的轴动一律视为噪声，不切设备。
		if absf(jm.axis_value) < GameConstants.STICK_DEADZONE:
			return
		_last_gamepad_id = jm.device
		_set_device(DeviceKind.GAMEPAD)


func _set_device(kind: DeviceKind) -> void:
	if _active_device == kind:
		return
	_active_device = kind
	# 设备切换是「UI 提示图标要换」的事实，但按 architecture §5.1，
	# 提示图标属 UI 层投影，走 L3 查询 `InputManager.active_device`，不占 EventBus。


## 供 SPIKE-1 / 单测使用：判断一条事件是否来自键鼠保留 ID。
static func is_keyboard_mouse_device(device_id: int) -> bool:
	return device_id == DEVICE_ID_KEYBOARD or device_id == DEVICE_ID_MOUSE


## ─────────────────────────────────────────────────────────────
## 输入缓冲（≤6 帧）
## ─────────────────────────────────────────────────────────────

func _poll_buffered_actions() -> void:
	for action: StringName in BUFFERED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if Input.is_action_just_pressed(action):
			_buffer[action] = _tick


## 一条缓冲是否仍在窗口内。窗口 = INPUT_BUFFER_FRAMES 帧（含按下当帧）。
func _is_fresh(action: StringName) -> bool:
	if not _buffer.has(action):
		return false
	var age: int = _tick - int(_buffer[action])
	return age >= 0 and age < GameConstants.INPUT_BUFFER_FRAMES


## 只看不吃：该动作是否有有效缓冲。
func has_buffered(action: StringName) -> bool:
	return _is_fresh(action)


## 缓冲已存在多少帧（无缓冲返回 -1）。供 FSM 做「先到先服务」兜底比较。
func buffered_age(action: StringName) -> int:
	if not _is_fresh(action):
		return -1
	return _tick - int(_buffer[action])


## 吃掉一条缓冲（消费即失效，防止一次输入触发两次动作）。
func consume_buffered(action: StringName) -> bool:
	if not _is_fresh(action):
		return false
	_buffer.erase(action)
	return true


## 优先级裁决唯一入口：返回本帧 FSM 应当执行的动词，无则返回 &""。
## 规则（control-checklist §H）：
##   1. 先按 VERB_PRIORITY 顺序（格 > 闪 > 斩）扫，命中即消费并返回。
##   2. 其余动词按「入缓冲更早者优先」兜底。
## FSM **不得**自行遍历缓冲；否则优先级会有第二个真相源。
func consume_buffered_verb() -> StringName:
	for action: StringName in VERB_PRIORITY:
		if _is_fresh(action):
			_buffer.erase(action)
			return action

	var best: StringName = &""
	var best_age: int = -1
	for action: StringName in BUFFERED_ACTIONS:
		if VERB_PRIORITY.has(action):
			continue
		var age: int = buffered_age(action)
		if age > best_age:
			best_age = age
			best = action
	if best != &"":
		_buffer.erase(best)
	return best


## 手动写入一条缓冲（供 SceneRunner 集成测试与 SPIKE-1 harness 注入）。
func push_buffer_for_test(action: StringName) -> void:
	_buffer[action] = _tick


## ─────────────────────────────────────────────────────────────
## E / A 情境仲裁（ux-spec §1.2 注）
## ─────────────────────────────────────────────────────────────

## 由交互射线每帧调用。InputManager 不做射线，只吃结论。
func set_interaction_context(has_anchor: bool, has_interactable: bool) -> void:
	_context_has_anchor = has_anchor
	_context_has_interactable = has_interactable


## 把「按了 E/A」解析为具体动作。锚点优先（ux-spec §1.2：显式锚点优先）。
## 无锚点且面前有神龛/残响节点 → ui_interact；两者皆无 → &""。
func resolve_context_action() -> StringName:
	if _context_has_anchor:
		return ACTION_GRAPPLE
	if _context_has_interactable:
		return ACTION_UI_INTERACT
	return &""


## ─────────────────────────────────────────────────────────────
## 移动轴（死区在此统一处理，业务侧不得自行 deadzone）
## ─────────────────────────────────────────────────────────────

func get_move_vector() -> Vector2:
	if not InputMap.has_action(ACTION_MOVE_RIGHT):
		return Vector2.ZERO
	var raw: Vector2 = Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	if raw.length() < GameConstants.STICK_DEADZONE:
		return Vector2.ZERO
	return raw


## ─────────────────────────────────────────────────────────────
## 测试隔离
## ─────────────────────────────────────────────────────────────

## gdUnit4 `before_test()` 必调，隔离全局缓冲状态。
func reset_for_test() -> void:
	_tick = 0
	_buffer.clear()
	_active_device = DeviceKind.KEYBOARD_MOUSE
	_last_gamepad_id = -1
	_context_has_anchor = false
	_context_has_interactable = false


## 单测无物理帧时手动推进 tick。
func advance_ticks_for_test(count: int) -> void:
	_tick += maxi(0, count)


func lock_device_for_test(locked: bool) -> void:
	_device_lock_for_test = locked


func set_active_device_for_test(kind: DeviceKind) -> void:
	_active_device = kind


## ─────────────────────────────────────────────────────────────
## InputMap 自愈注册（双套默认映射）
## ─────────────────────────────────────────────────────────────
##
## 说明：project.godot 里也写了同一套映射（供编辑器与非 Autoload 路径可用）。
## 这里做的是「缺什么补什么」，保证 headless 单测与 CI 不因 project.godot
## 被编辑器改动而红。**两处必须同源**——由 test_input_actions_registered.gd 守。

func _ensure_input_map() -> void:
	_ensure_action(ACTION_SLASH, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_DASH, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_GRAPPLE, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_LEAP, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_PARRY, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_RESONATE, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_LOCKON, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_MOVE_FORWARD, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_MOVE_BACK, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_MOVE_LEFT, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_MOVE_RIGHT, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_UI_MAP, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_DEBUG_OVERLAY, GameConstants.STICK_DEADZONE)
	# ui_pause / ui_interact：Godot 内建 ui_* 里没有这两个名字，需自建。
	_ensure_action(ACTION_UI_PAUSE, GameConstants.STICK_DEADZONE)
	_ensure_action(ACTION_UI_INTERACT, GameConstants.STICK_DEADZONE)

	# —— 键鼠默认（ux-spec §1.2） ——
	_bind_mouse(ACTION_SLASH, MOUSE_BUTTON_LEFT)
	_bind_mouse(ACTION_DASH, MOUSE_BUTTON_RIGHT)
	_bind_key(ACTION_DASH, KEY_SHIFT)
	_bind_key(ACTION_GRAPPLE, KEY_E)
	_bind_key(ACTION_LEAP, KEY_SPACE)
	_bind_key(ACTION_PARRY, KEY_Q)
	_bind_key(ACTION_RESONATE, KEY_F)
	_bind_mouse(ACTION_LOCKON, MOUSE_BUTTON_MIDDLE)
	_bind_key(ACTION_UI_INTERACT, KEY_E)
	_bind_key(ACTION_MOVE_FORWARD, KEY_W)
	_bind_key(ACTION_MOVE_BACK, KEY_S)
	_bind_key(ACTION_MOVE_LEFT, KEY_A)
	_bind_key(ACTION_MOVE_RIGHT, KEY_D)
	_bind_key(ACTION_UI_PAUSE, KEY_ESCAPE)
	_bind_key(ACTION_UI_MAP, KEY_M)
	_bind_key(ACTION_DEBUG_OVERLAY, KEY_F3)

	# —— 手柄默认（Xbox 布局，ux-spec §1.2） ——
	_bind_pad(ACTION_SLASH, JOY_BUTTON_X)
	_bind_pad(ACTION_SLASH, JOY_BUTTON_RIGHT_SHOULDER)
	_bind_pad(ACTION_DASH, JOY_BUTTON_A)
	_bind_pad(ACTION_LEAP, JOY_BUTTON_B)
	_bind_pad(ACTION_RESONATE, JOY_BUTTON_Y)
	_bind_pad(ACTION_LOCKON, JOY_BUTTON_LEFT_SHOULDER)
	_bind_pad(ACTION_UI_INTERACT, JOY_BUTTON_A)
	_bind_pad(ACTION_UI_PAUSE, JOY_BUTTON_START)
	_bind_pad(ACTION_UI_MAP, JOY_BUTTON_BACK)
	# 扳机为轴：RT = TRIGGER_RIGHT（荡）、LT = TRIGGER_LEFT（格）。
	_bind_pad_axis(ACTION_GRAPPLE, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_pad_axis(ACTION_PARRY, JOY_AXIS_TRIGGER_LEFT, 1.0)
	# 左摇杆 → move_*
	_bind_pad_axis(ACTION_MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_bind_pad_axis(ACTION_MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_bind_pad_axis(ACTION_MOVE_FORWARD, JOY_AXIS_LEFT_Y, -1.0)
	_bind_pad_axis(ACTION_MOVE_BACK, JOY_AXIS_LEFT_Y, 1.0)


func _ensure_action(action: StringName, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _bind_key(action: StringName, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	_add_if_absent(action, ev)


func _bind_mouse(action: StringName, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	_add_if_absent(action, ev)


func _bind_pad(action: StringName, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	_add_if_absent(action, ev)


func _bind_pad_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	_add_if_absent(action, ev)


func _add_if_absent(action: StringName, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	if InputMap.action_has_event(action, ev):
		return
	InputMap.action_add_event(action, ev)


## 全部动作名（供 test_input_actions_registered.gd 与重映射 UI 遍历）。
static func all_action_names() -> Array[StringName]:
	return [
		ACTION_SLASH,
		ACTION_DASH,
		ACTION_GRAPPLE,
		ACTION_LEAP,
		ACTION_PARRY,
		ACTION_RESONATE,
		ACTION_LOCKON,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACK,
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_UI_PAUSE,
		ACTION_UI_INTERACT,
		ACTION_UI_MAP,
		ACTION_DEBUG_OVERLAY,
	]
