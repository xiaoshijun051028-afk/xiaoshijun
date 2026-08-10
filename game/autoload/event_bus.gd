## Autoload #2 · 纯信号容器（L2 系统级通信）。
##
## 硬性约束（architecture.md §4.3 / §5.2）：**无状态、无逻辑、无 _process**。
## 本文件除 signal 声明与注释外不得出现任何可执行代码 —— 一旦有人往这里加逻辑，
## 「谁改了状态」就会变得不可追踪，这正是 EventBus 最常见的腐化方式。
##
## 命名铁律：**一律过去式** —— 只陈述已发生的事实，不用于请求动作。
## 要改状态一律调用权威者的方法（如 ResonancePool.try_spend()），不能靠发信号请求。
## 这条规则杜绝了「两个监听者都以为对方会处理」的经典 bug（architecture.md §5.1）。
##
## 信号总数 = **27**（test_event_bus_signals.gd 硬断言该数字与每一条签名）。
extends Node

# =========================================================================
# S3 共鸣（3）
# =========================================================================

## 池值已变化。唯一发出方 = ResonancePool._set_value()。
signal resonance_changed(new_value: int, old_value: int)

## 扣费被拒（余额不足）。**仅失败时**发出。
signal resonance_spend_rejected(cost: int, reason: StringName)

## 共鸣节点已被消费（进入 cd）。S7 残响据此触发叙事。
signal resonance_node_consumed(node_id: StringName)

# =========================================================================
# S1 战斗（6）
# =========================================================================

signal player_hp_changed(new_hp: int, old_hp: int)

## 玩家 FSM 进入新状态。唯一发出方 = StateMachine（ADR-003 §4 转移裁决第 5 步）。
## state_name 是**闭集**，取值必为下列 9 个之一：
##   &"Idle" &"Slash" &"SlashHeavy" &"Dash" &"Grapple"
##   &"Leap" &"Parry" &"Resonate" &"Hitstun"
## 命名规则：PascalCase，state_name == 状态节点的 node.name，与 architecture §4.4 /
## ADR-003 §1 的节点树 1:1 对应。新增状态必须同时改这三处，否则视为破坏契约。
## 三条防误接线约定：
##   1) 斩的 4 段连段**不是 4 个状态** —— 只有一个 &"Slash"，段号走 combo_advanced()。
##      **不存在 &"Slash1".. &"Slash4"**。
##   2) 本信号**仅玩家**。敌人状态集不经此信号，一律走 enemy_* 系列。
##   3) S2 移动不另立状态机：grounded/airborne/grappling 是**标志位**。
signal player_state_entered(state_name: StringName)

signal combo_advanced(count: int)
signal perfect_parry_landed(target: Node3D)
signal finisher_executed(damage: int)

## 战斗状态翻转。唯一发出方 = ResonancePool（脱战计时权威已在此）。
## 仅在布尔值**翻转**时发，不每帧广播。
## 消费方：AudioDirector（Explore↔Combat 切段）/ EchoDirector（战斗中降级残响）/ HUD。
signal combat_state_changed(in_combat: bool)

# =========================================================================
# S4 敌人（5）
# =========================================================================

signal enemy_telegraph_started(enemy: Node3D, frames: int)
signal enemy_telegraph_cleared(enemy: Node3D)
signal enemy_staggered(enemy: Node3D, frames: int)
signal enemy_died(enemy: Node3D)
signal boss_phase_changed(phase: int)

# =========================================================================
# S5 世界 / S8 神龛（4）
# =========================================================================

signal gate_opened(gate_id: StringName)
signal shrine_activated(shrine_id: StringName)
signal player_respawned(shrine_id: StringName)
signal island_entered(island_id: StringName)

# =========================================================================
# S7 残响（3）
# =========================================================================

signal echo_triggered(echo_id: StringName)

## 残响播完 / 被新残响顶替。唯一发出方 = EchoDirector。
## 与 echo_triggered **严格配对**；被打断也必须发，否则音乐永久压在 L0、字幕永不消失。
signal echo_finished(echo_id: StringName)

signal echo_collected(echo_id: StringName, total: int)

# =========================================================================
# 系统（4）
# =========================================================================

signal save_completed(success: bool)
signal settings_changed(key: StringName)

## 已暂停。唯一发出方 = 暂停菜单控制器（写 Engine.time_scale = 0 的**同帧**）。
## ⚠ Engine.time_scale = 0 **不会停音频**（architecture.md §5.4.1，已核实的引擎事实）。
## 本信号是全项目**唯一**的暂停事实来源。
## 消费方：AudioDirector（duck/mute gameplay 总线）/ InputManager（清缓冲、切 UI 上下文）
##        / DebugOverlay（冻结帧时间曲线采样）。
signal game_paused()

## 已恢复。与 game_paused **严格配对且不可重入**：已暂停时再进子菜单不得重复发。
signal game_resumed()

# =========================================================================
# 时间膨胀（2）—— 慢动作 / hit-stop，architecture.md §5.2 AUD 批次
# =========================================================================

## 时间膨胀已开始。唯一发出方 = 战斗 FSM 中**实际写 Engine.time_scale 的那一处**
## （v1 = 完美格挡分支，scale = PARRY_SLOWMO_SCALE、duration_frames = PARRY_SLOWMO_FRAMES），
## 与赋值**同帧**发出。
## ⚠ duration_frames 是**名义**时长，仅供表现层规划包络；
##    **禁止**据此倒计时判定结束 —— 慢动作可被提前打断（敌人死亡 / 玩家受击）。
## 消费方：AudioDirector（SFX/Ambience 低通下潜 + Music duck）/ CameraRig / Compositor 栈。
signal time_dilation_started(scale: float, duration_frames: int)

## 时间膨胀已结束。同上发出方，恢复 time_scale = 1.0 的同帧。
## **必须显式发出**：若消费方靠 duration_frames 自行倒计时，低通会卡死在下潜态。
signal time_dilation_ended()
