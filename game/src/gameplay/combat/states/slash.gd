class_name SlashState
extends CombatState
## Slash · 斩（架构 §4.4 / ADR-003 §1）。
##
## ⚠ 4 段连段**不是 4 个状态**：全项目只有一个 &"Slash"，段号走 `combo:int`
## （EventBus.player_state_entered 闭集约定 1 / ADR-003 §1）。**不存在 Slash1..Slash4。**
##
## 连段序列在**离开斩态时**清零：斩→斩 保持累加，斩→闪→斩 视为新序列。
## v1 先取这条最简规则；「闪取消后保段」属手感调参，等 SPIKE-3 结论再定（[GAP-VERB-1]）。

## 取消窗开启帧。第 0 帧（起手同帧）刻意不开窗，杜绝零帧空取消（按下即可换招 = 无重量感）；
## 第 1–8 帧共 CANCEL_WINDOW(8) 帧为窗内，第 9 帧起锁死到收招结束。
## 这让 AC-S1-01「任意两动词间取消延迟 ≤8 帧」在 VerbDefinition 落地前即可硬断言。
const CANCEL_OPEN_FRAME: int = 1

## 单段斩总帧数（v1 占位，[GAP-VERB-1] 待 SPIKE-3 调参后迁入 .tres）。
const TOTAL_FRAMES: int = 24

## 连段段数上限（GDD S1「4 段连段」）。到顶回到第 1 段，形成 4 段循环。
const MAX_COMBO: int = 4

## 当前连段段号（1..MAX_COMBO）。ADR-003 §1：连段由此整数驱动，不新增状态。
var combo: int = 0


func _enter() -> void:
	super._enter()
	cancel_open_at_frame = CANCEL_OPEN_FRAME
	duration_frames = TOTAL_FRAMES
	neutral = false
	combo = combo % MAX_COMBO + 1
	EventBus.combo_advanced.emit(combo)


func _exit() -> void:
	# 离开斩态即结束本次连段序列。下次起手从第 1 段重新计。
	combo = 0
