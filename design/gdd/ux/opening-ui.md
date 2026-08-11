# UX 规格 · 开头 UI 与主菜单（Opening UI）

> 版本 v0.1 ｜ 作者 文策渊（主理人降级直写，因 agent 网络中断）
> 引擎 Godot 4.7-stable ｜ 工程根 `game/`
> 上游：`design/gdd/systems/gacha.md`、`production/epics/epic-s1-combat.md`（HUD 信号）、`design/color-tokens.md`
> **本文件 = 用户需求「开头 UI 做出来」的可审阅蓝图，供程基岩实现。**

---

## §1 目标与最小可玩定义

- 任何人打开游戏 → **标题屏** → **主菜单** → 一键进入**最小可玩场景**（竞技场 + 训练假人），即"能玩"。
- 不设计完整关卡；一个竞技场 + 一个假人敌人即可构成"可玩闭环"（验证移动/斩/闪/格/共鸣全动词）。
- 战斗中 HUD 复用 S1 已定义信号，**零新增元素**（守 gacha.md 认知过载红线）。

---

## §2 屏幕流（Title → Menu → Play / Gacha）

```
启动
  └─ TitleScreen（游戏名 + "按任意键 / 点击开始"）
        └─ 点击 → MainMenu（Control 全屏，UI_BG 底色）
              ├─ [开始游戏] → 载入 Arena 场景（含 1 训练假人）
              ├─ [星轨召唤] → 实例化 GachaPanel（res://game/src/gacha/gacha_panel.gd）
              ├─ [设置]     → SettingsPanel（音量滑条 + 返回）
              └─ [退出]     → 退出应用（get_tree().quit()）
```

### 2.1 标题屏 TitleScreen
- 全屏 `ColorRect`（底色 `UI_BG` `#1A2233`）。
- 居中游戏名 **星陨之境 / Aetherfall**（大字，描边 `RESONANCE_GLOW` 自发光青白）。
- 副标小字：「按 Enter 或点击开始」。
- 行为：监听 `gui_input` 或 `InputEventKey`（Enter/Space）或鼠标点击 → 切到 MainMenu。
- 可选：背景缓慢旋转的星点粒子（低开销，纯装饰）。

### 2.2 主菜单 MainMenu
- `Control` 全屏，底色 `UI_BG`。
- 四个 `Button` 竖直排列居中（描边 `FRIENDLY_GOLD` `#F2C15E` 作为"可交互"语义色，非 THREAT）。
- 按钮行为：
  - **开始游戏**（`_on_play_pressed`）：`get_tree().change_scene_to_file("res://game/scenes/arena_min.tscn")`。
  - **星轨召唤**（`_on_gacha_pressed`）：`add_child(GachaPanel 实例)` 并 `show()`；GachaPanel 自带关闭按钮返回菜单。
  - **设置**（`_on_settings_pressed`）：实例化/显示 SettingsPanel。
  - **退出**（`_on_quit_pressed`）：`get_tree().quit()`。
- 顶部可显示当前出战角色名（从 `RosterAutoload.get_active()` 读；为空则"默认旅人"）。

### 2.3 设置 SettingsPanel
- 音量主滑条（写入 `AudioServer` 或 `SaveManager` 音量字段）→ 返回主菜单。
- 不接完整设置系统，够用即可（v1 验证可玩性）。

---

## §3 最小可玩场景 Arena（竞技场 + 训练假人）

- 文件：`game/scenes/arena_min.tscn`（新建）+ 驱动脚本 `game/src/gameplay/arena_min.gd`（可选，简单）。
- 内容：
  - 一个平面 `MeshInstance3D`（Floor，大号 Box/Plane）+ 天空 `WorldEnvironment`（基础环境光，够亮即可）。
  - **玩家**：`PlayerCombat`（注入 `RosterAutoload` 当前出战角色五维；若 `active_id` 空 → 回落默认 100 标量，见 gacha.md §6.1）。
  - **训练假人**：用 `EnemyDefinition` 加载 `brute.tres`（hp120）或专门 `dummy.tres`（hp 高、不反击、不移动），挂 `EnemyCombat` + FSM（仅 Idle/Stagger/Dead）。假人只接伤害、播放受击/死亡，不发射 telegraph。
  - 摄像机：第三人称跟随（简单 `SpringArm3D` 或固定偏移 `Camera3D`）。
- 控制（复用 S1 输入映射）：移动 WASD、斩 鼠标左/ J、闪 Shift、格 K、共鸣/终结技 L（按 S1 已有映射）。
- 顶部返回按钮（Esc → 回 MainMenu），便于试玩往返。

### 3.1 HUD（复用 S1 信号，零新增）
- 血条（监听 `EventBus` 的 hp 变化信号）、连段数（combo 信号）、共鸣条（resonance 信号）。
- 这些信号在 `epic-s1-combat.md` 的跨 Epic 接口已定义；HUD 仅订阅，不新增控件。
- 若 S1 信号名未最终定，本场景 HUD 先以 `PlayerCombat` 直接读 `hp/max_hp` + `combo` 属性轮询方式兜底（最简实现）。

---

## §4 转场与可访问性

- 屏幕切换用 `CanvasLayer` + `Tween` 淡入淡出（0.2s），避免硬切。
- 按钮满足 `accessibility-tier F1`：文字 + 明确焦点框（Godot 默认 `Button` focus 模式），不靠纯颜色区分。
- 退出前不弹确认（单机本地，无未保存进度风险；存档已自动持久化）。

---

## §5 工程交付清单（程基岩）

| 产出 | 路径 | 说明 |
|---|---|---|
| 标题屏 | `game/scenes/title_screen.tscn` + `game/src/ui/title_screen.gd` | 监听输入切菜单 |
| 主菜单 | `game/scenes/main_menu.tscn` + `game/src/ui/main_menu.gd` | 四按钮 → play/gacha/settings/quit |
| 召唤入口 | 复用 `game/src/gacha/gacha_panel.gd` | 主菜单实例化，自带关闭 |
| 设置 | `game/scenes/settings_panel.tscn` + 脚本 | 音量 + 返回 |
| 竞技场 | `game/scenes/arena_min.tscn` + `game/src/gameplay/arena_min.gd` | 地板 + 玩家 + 假人 + 摄像机 |
| 训练假人 | `game/resources/enemy_defs/dummy.tres` + 轻量 `EnemyCombat` 配置 | 不反击、不移动 |
| 启动场景 | `project.godot` 的 `run/main_scene` → `title_screen.tscn` | 改为标题屏为首屏 |

> 变更记录：v0.1 — 依用户「开头 UI 做出来」需求，由主理人降级直写（agent 网络中断）。
