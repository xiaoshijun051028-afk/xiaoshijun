## Autoload #4 · 存档写盘与读档（ADR-004）。
##
## 依赖 1,2,3（GameConstants / EventBus / ResonancePool）。
## 职责边界：**只做序列化与 IO**，不含游戏逻辑（architecture.md §4.3 「禁止：游戏逻辑」）。
## 纯逻辑部分在 src/meta/save_model.gd，本类只负责原子写盘与生命周期。
##
## 原子写盘（ADR-004 决策 4）：
##   写 .tmp → flush/close → 重新读回并校验 checksum
##     ├ 通过 → 现有存档改名为 .bak → rename(.tmp → .json)   ← 单一原子步
##     └ 失败 → 删除 .tmp，保留原存档，emit save_completed(false)，HUD 提示「未保存」
## 断电/崩溃最坏情况只会丢**本次**存档，绝不会产生半截损坏文件。
extends Node

const SAVE_DIR: String = "user://saves"
const SLOT_FILENAME: String = "slot_1.json"
const GAME_VERSION: String = "0.5.0-sprint1"

## 内存中的当前存档快照。写盘前由各系统贡献。
var _state: Dictionary = {}

## 最近一次 IO 错误描述，供 HUD / DebugOverlay 展示。
var _last_error: String = ""


var last_error: String:
	get:
		return _last_error


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_state = SaveModel.new_save(GAME_VERSION)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_load_settings()


func save_path() -> String:
	return SAVE_DIR + "/" + SLOT_FILENAME


func backup_path() -> String:
	return save_path() + ".bak"


func temp_path() -> String:
	return save_path() + ".tmp"


## 在神龛存档（S5→S8 唯一存档点）。返回是否成功。
## GDD S8 §⑥：写盘失败保留内存状态、提示「未保存」、**不崩溃**。
func save_at_shrine(shrine_id: StringName) -> bool:
	_collect_snapshot(shrine_id)
	var ok: bool = _write_atomic(SaveModel.serialize(_state))
	EventBus.save_completed.emit(ok)
	if ok:
		EventBus.shrine_activated.emit(shrine_id)
	return ok


## 启动 / 主动读档。**复活不走这里**（复活是内存态复位 + 传送，architecture.md §10.4）。
func load_game() -> bool:
	_last_error = ""
	if not FileAccess.file_exists(save_path()):
		# 文件不存在 → 新游戏（池 = INITIAL）。这不是错误。
		_state = SaveModel.new_save(GAME_VERSION)
		_apply_snapshot()
		return true

	var result: SaveModel.ParseResult = _read_and_parse(save_path())
	if not result.ok:
		# 主档坏 → 尝试 .bak（ADR-004 决策 5）。
		push_warning("SaveManager: 主存档不可用（%s），尝试 .bak" % result.error)
		if FileAccess.file_exists(backup_path()):
			result = _read_and_parse(backup_path())
	if not result.ok:
		_last_error = result.error
		# 不覆盖、不崩溃 —— 保留损坏文件供玩家自救 / 报 bug 时附上。
		return false

	_state = result.data
	_apply_snapshot()
	return true


## 从各系统收集快照。**只收集玩家造成的差异**，不含任何可推导数据与常量。
func _collect_snapshot(shrine_id: StringName) -> void:
	_state["game_version"] = GAME_VERSION
	_state["saved_at_unix"] = int(Time.get_unix_time_from_system())

	var player: Dictionary = _state.get("player", {}) as Dictionary
	player["last_shrine_id"] = String(shrine_id)
	_state["player"] = player

	# ★ 池只存 current 一个字段（ADR-002 / ADR-004 决策 3）。
	_state["resonance"] = ResonancePool.capture_save_state()

	# 用 get_node_or_null 而非直接引用 EchoDirector 全局名：EchoDirector 是 Autoload #7，
	# 晚于本单例（#4）初始化。直接引用在极早期调用路径上会拿到未就绪的单例。
	var echo: Node = get_node_or_null(^"/root/EchoDirector")
	if echo != null:
		var narrative: Dictionary = _state.get("narrative", {}) as Dictionary
		narrative["echoes_collected"] = echo.call("capture_save_state")
		_state["narrative"] = narrative

	# ★ 花名册（S9 抽卡）：经 get_node_or_null 取 RosterAutoload，避免 autoload 初始化顺序依赖。
	var roster_node: Node = get_node_or_null(^"/root/RosterAutoload")
	if roster_node != null:
		_state["roster"] = roster_node.call("to_dict")


func _apply_snapshot() -> void:
	ResonancePool.apply_save_state(_state.get("resonance", {}) as Dictionary)
	var echo: Node = get_node_or_null(^"/root/EchoDirector")
	if echo != null:
		var narrative: Dictionary = _state.get("narrative", {}) as Dictionary
		echo.call("apply_save_state", narrative.get("echoes_collected", []) as Array)

	# 花名册（S9）：恢复拥有角色 / 出战选择 / 保底计数。
	var roster_node: Node = get_node_or_null(^"/root/RosterAutoload")
	if roster_node != null:
		roster_node.call("from_dict", _state.get("roster", {}) as Dictionary)


func _read_and_parse(path: String) -> SaveModel.ParseResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var failed: SaveModel.ParseResult = SaveModel.ParseResult.new()
		failed.error = "无法打开 %s（错误码 %d）" % [path, FileAccess.get_open_error()]
		return failed
	var text: String = file.get_as_text()
	file.close()
	return SaveModel.deserialize(text)


## 原子写盘。任何一步失败都保留原档并返回 false。
func _write_atomic(text: String) -> bool:
	_last_error = ""
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	# 1. 写 .tmp
	var tmp: FileAccess = FileAccess.open(temp_path(), FileAccess.WRITE)
	if tmp == null:
		_last_error = "无法创建临时文件（错误码 %d）" % FileAccess.get_open_error()
		return false
	tmp.store_string(text)
	tmp.flush()
	tmp.close()

	# 2. 读回 .tmp 并校验 checksum —— 校验的是**已落盘的字节**，不是内存里的字符串。
	#    这一步才是「写成功」的定义；少了它，磁盘满/权限异常都会静默产生半截档。
	var verify: SaveModel.ParseResult = _read_and_parse(temp_path())
	if not verify.ok:
		_last_error = "写盘校验失败：%s" % verify.error
		DirAccess.remove_absolute(temp_path())
		return false

	# 3. 旧档轮转为 .bak
	if FileAccess.file_exists(save_path()):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		var bak_err: int = DirAccess.rename_absolute(save_path(), backup_path())
		if bak_err != OK:
			_last_error = "备份轮转失败（错误码 %d）" % bak_err
			DirAccess.remove_absolute(temp_path())
			return false

	# 4. rename 是同一文件系统上的原子操作
	var err: int = DirAccess.rename_absolute(temp_path(), save_path())
	if err != OK:
		_last_error = "原子改名失败（错误码 %d）" % err
		return false
	return true


## ─────────────────────────────────────────────────────────────
## 设置（ux-spec §4：存 user://settings.json，**与存档分离**——换档不丢按键/音量）
## ─────────────────────────────────────────────────────────────
##
## 设置不进 slot_*.json，因此不受 ADR-004 的 schema/迁移链约束，也不参与 checksum。
## 但同样禁止落任何 GameConstants 常量（ADR-002）——这里只存「玩家偏好」。

const SETTINGS_PATH: String = "user://settings.json"

var _settings: Dictionary = {}


## 只读副本。AudioDirector / CameraRig / ColorTokens 消费方按 key 取值。
func get_settings() -> Dictionary:
	return _settings.duplicate()


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return _settings.get(key, fallback)


## 写一项设置并广播。**不立即写盘**（避免滑块拖动逐帧 IO），由 flush_settings() 落盘。
func set_setting(key: String, value: Variant) -> void:
	if _settings.get(key) == value:
		return
	_settings[key] = value
	EventBus.settings_changed.emit(StringName(key))


func flush_settings() -> bool:
	var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		_last_error = "设置写盘失败（错误码 %d）" % FileAccess.get_open_error()
		return false
	f.store_string(JSON.stringify(_settings, "\t"))
	f.close()
	return true


func _load_settings() -> void:
	_settings = {}
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_settings = parsed as Dictionary
	else:
		# 设置损坏不阻塞进游戏：回退默认，保留坏文件供排查。
		_last_error = "settings.json 解析失败，已回退默认设置"


## 测试隔离用：清空内存态并删除测试产生的文件。
func reset_for_test() -> void:
	_state = SaveModel.new_save(GAME_VERSION)
	_settings = {}
	_last_error = ""
	for path: String in [temp_path(), save_path(), backup_path(), SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
