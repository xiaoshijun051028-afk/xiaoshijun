extends Node
## EchoDirector · Autoload #7
##
## 职责（ENG-S0-05 第 7 项；S7 残响叙事，Sprint 1 仅骨架）：
##   1. 管理「残响节点」的触发与收集进度（AC-S7-01/02/03/04 的落点）。
##   2. 触发残响 → 走 ResonancePool.resonate_at_node()（**+10 与 5s cd 的判定不在此**，
##      在 ResonancePool，保证共鸣数学只有一个真相源 —— ADR-002）。
##   3. 广播 echo_triggered / echo_finished / echo_collected（过去式事实）。
##   4. 向 SaveManager 提供 capture_save_state() / apply_save_state()。
##
## 依赖：2 EventBus、3 ResonancePool。不依赖 DebugOverlay(#8)。
## 绝不做：**不暂停游戏、不锁输入**（AC-S7-04：战斗中触发不卡输入）——
##        本单例只发信号与计时，UI 层自行做非模态字幕。
##
## 时间基准：整数帧。残响播放时长以帧计（`_frames_left`），不用 Timer、不用秒。

## 残响播放的占位时长（帧）。真实时长由 VO 音频长度决定，Sprint 1 用占位值。
## [GAP-NARR-1] 待 文策渊 的残响文本 + 阮和鸣 的 VO 资产入库后，改为读 EchoDefinition.tres。
const PLACEHOLDER_ECHO_FRAMES: int = 240

## 单条残响播放中的运行时记录。
var _active_echo: StringName = &""
var _frames_left: int = 0

## 已收集残响 id 集合（值恒为 true，仅作 set 用）。
var _collected: Dictionary = {}


## 只读：已收集残响总数（HUD 发现进度用，L3 查询）。
var collected_count: int:
	get:
		return _collected.size()


## 只读：当前是否有残响在播（不影响输入，仅供 UI 判断字幕显隐）。
var is_playing: bool:
	get:
		return _active_echo != &""


func _ready() -> void:
	# 残响可在战斗中播放且不受暂停影响的部分由 UI 决定；本单例跟随默认暂停语义。
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	if _active_echo == &"":
		return
	_frames_left -= 1
	if _frames_left <= 0:
		var finished: StringName = _active_echo
		_active_echo = &""
		_frames_left = 0
		EventBus.echo_finished.emit(finished)


## ─────────────────────────────────────────────────────────────
## 触发
## ─────────────────────────────────────────────────────────────

## 玩家在残响节点按 verb_resonate / ui_interact 时调用。
## 返回是否产生了共鸣增益（cd 内二次触发返回 false —— AC-S7-03 / AC-S3-04 同一判定源）。
##
## 注意：即使 cd 未到、无增益，**残响叙事仍可重播**（叙事与增益解耦）；
##      本函数返回值只表达「有没有加池」，不表达「有没有播叙事」。
func trigger_echo(echo_id: StringName) -> bool:
	if echo_id == &"":
		push_error("EchoDirector.trigger_echo: 空 echo_id")
		return false

	# 增益判定唯一入口 —— 不在此复制 +10 / cd 逻辑（ADR-002 单一真相源）。
	var gained: bool = ResonancePool.resonate_at_node(echo_id)

	# 叙事播放：不锁输入、不暂停（AC-S7-04）。
	_active_echo = echo_id
	_frames_left = PLACEHOLDER_ECHO_FRAMES
	EventBus.echo_triggered.emit(echo_id)

	# 首次触达才计入发现进度（AC-S7-02）。
	if not _collected.has(echo_id):
		_collected[echo_id] = true
		EventBus.echo_collected.emit(echo_id, _collected.size())

	return gained


func is_collected(echo_id: StringName) -> bool:
	return _collected.has(echo_id)


## 提前打断（例如玩家离开区域）。仍发 echo_finished，保证订阅方状态归零。
func stop_echo() -> void:
	if _active_echo == &"":
		return
	var finished: StringName = _active_echo
	_active_echo = &""
	_frames_left = 0
	EventBus.echo_finished.emit(finished)


## ─────────────────────────────────────────────────────────────
## 存档接口（由 SaveManager 通过 /root/EchoDirector 反射调用）
## ─────────────────────────────────────────────────────────────

## 只存「收集了哪些」，不存任何 GameConstants 常量（ADR-002/ADR-004）。
func capture_save_state() -> Array[String]:
	var out: Array[String] = []
	for key: StringName in _collected.keys():
		out.append(String(key))
	out.sort()  # 稳定序 → checksum 可复现
	return out


func apply_save_state(ids: Array) -> void:
	_collected.clear()
	for raw: Variant in ids:
		var id_str: String = str(raw)
		if id_str.is_empty():
			continue
		_collected[StringName(id_str)] = true


## gdUnit4 隔离用。
func reset_for_test() -> void:
	_collected.clear()
	_active_echo = &""
	_frames_left = 0


func advance_ticks_for_test(count: int) -> void:
	for _i: int in maxi(0, count):
		_physics_process(0.0)
