## 语义色单一真相源（工程落点）。
##
## 取值权威 = design/color-tokens.md v1.1（林绘澄定稿，CONCERN-A 已收口）。
## 本文件是**全项目唯一**允许出现颜色数值的地方；其余任何 .gd / .gdshader / .tscn
## 出现 hex 字面量或裸 Color(...) 均视为违规，由 tools/lint/lint_hex_literals.gd 拦截。
##
## 双形态设计（刻意为之，非冗余）：
##   1. `const` 段 —— 权威取值，可静态访问 `ColorTokens.THREAT`，无需实例化、无需 Autoload。
##      GameConstants 与游戏代码一律走这一层，按 **Token 名**引用。
##   2. `@export var` 段 —— 供 resources/colors/*.tres 承载 Normal / CVD 两套调色板，
##      运行时热切换（architecture.md §9「色盲模式天然全覆盖」）。
##
## 别名策略（color-tokens.md §1.1 裁决 T5-ART-b / T5-ART-c）：
##   FRIENDLY_AMBER 是 FRIENDLY_GOLD 的**代码侧别名**，UI_BASE 是 UI_BG 的代码侧别名。
##   两者均为合法引用、**不是退役名**、不进 lint 拒绝名单。新增引用优先用本名。
class_name ColorTokens
extends Resource

## 取值权威文档。改色必须先改该文档，再改此处，否则 test_color_tokens.gd 红灯。
const SOURCE_OF_TRUTH: String = "design/color-tokens.md#1"

# ---------------------------------------------------------------------------
# 1. 权威 Token（const，静态可访问）—— design/color-tokens.md §1 表
#    浮点值直接抄自该表「Godot Color(r,g,b)」列，不做二次换算，避免舍入漂移。
# ---------------------------------------------------------------------------

## 玩家/友方主色·星辉青 #5FD2C8。玩家身份、友方/共鸣基色、HUD 友方强调。
const PLAYER_ALLY_MAIN: Color = Color(0.373, 0.824, 0.784)

## 共振辉光·青白 #9FF7E8（emissive + Bloom）。共鸣节点/终结技/星刃辉光。
## 与 PLAYER_ALLY_MAIN 是「基色 vs 自发光态」两 Token，非冲突（color-tokens.md §4）。
const RESONANCE_GLOW: Color = Color(0.624, 0.969, 0.910)

## 友方支撑·青 #5FD2C8（与玩家主色同 hue）。
const FRIENDLY_TEAL: Color = Color(0.373, 0.824, 0.784)

## 友方支撑·暖金 #F2C15E。可交互/线索、希望点缀、暖光。**本名**。
const FRIENDLY_GOLD: Color = Color(0.949, 0.757, 0.369)

## 友方支撑·珊瑚 #FF8A65。友方暖点缀、植被/魔法暖强调。
const FRIENDLY_CORAL: Color = Color(1.0, 0.541, 0.396)

## 威胁品红 #A62C6B —— **不可变常量（mandated）**，仅敌人/混沌专属。
## 铁律：任何模式不得外溢到中立/友方；低血与受击一律用 DAMAGE_WARN。
const THREAT: Color = Color(0.651, 0.173, 0.420)

## 伤害/警告·炽红 #E5484D。受击、危险区、低血闪（替代 THREAT 守铁律）。
const DAMAGE_WARN: Color = Color(0.898, 0.282, 0.302)

## 治疗/增益·绿 #7BD16A。回血、buff。
const HEAL_BUFF: Color = Color(0.482, 0.820, 0.416)

## UI 底·深空 #1A2233。面板/遮罩底色、文本托底。**本名**。
const UI_BG: Color = Color(0.102, 0.133, 0.200)

## 苍穹蓝·品牌 #3E6FB0。天空/水体/远景基色。
const SKY_AZURE: Color = Color(0.243, 0.435, 0.690)

# --- 别名（不另立 hex，一律解析到本名；color-tokens.md §1.1）---

## 语义别名 → FRIENDLY_GOLD。拾取/机关/路标。
const INTERACT: Color = FRIENDLY_GOLD

## 代码侧别名 → FRIENDLY_GOLD（architecture.md L720 `@export var` 沿用名）。
const FRIENDLY_AMBER: Color = FRIENDLY_GOLD

## 代码侧别名 → UI_BG（architecture.md L793 `@export var` 沿用名）。
const UI_BASE: Color = UI_BG

# --- 共鸣三态附属色（HUD S6 §⑤：≥40 / ≥30 / <30）---

## [GAP-COLOR-1] `GATE_READY`（可开门态）在 systems-index §2 有名无 hex，
## color-tokens.md v1.1 §1 表**未收录取值**。此处**临时**解析到 FRIENDLY_GOLD
## （语义为「可交互/线索」，与开门提示同义），待林绘澄定稿后单行替换。
## 已列入 Sprint 1 回传的待裁决项，勿视为已定稿取值。
const GATE_READY: Color = FRIENDLY_GOLD

## [GAP-COLOR-1] `INACTIVE`（灰，未就绪）同上：有名无 hex。
## 此处临时取 UI_BG 提亮后的中性灰（与 UI 底同色族，保证面板上可读），待定稿。
const INACTIVE: Color = Color(0.451, 0.482, 0.549)

# ---------------------------------------------------------------------------
# 2. CVD（色盲）替代色 —— design/color-tokens.md §2 表
#    铁律：色相替换只是辅助，形状/图标/明度编码为**强制**（可访问性 F1）。
# ---------------------------------------------------------------------------

## Tritan 型下的玩家青替代 #4FD0C0。
const CVD_PLAYER_ALLY_MAIN_TRITAN: Color = Color(0.310, 0.816, 0.753)

## Tritan 型下的威胁品红替代 #8E2C7A（更紫）。Deutan/Protan 保持原色。
const CVD_THREAT_TRITAN: Color = Color(0.557, 0.173, 0.478)

## 红绿型下的伤害红替代 #FF5A36（鲜橙红）。
const CVD_DAMAGE_WARN: Color = Color(1.0, 0.353, 0.212)

## 红绿型下的治疗绿替代 #3E8FD0（CVD 安全蓝）。
const CVD_HEAL_BUFF: Color = Color(0.243, 0.561, 0.816)

## 红绿型下的珊瑚替代 #FF9E40（更橙）。
const CVD_FRIENDLY_CORAL: Color = Color(1.0, 0.620, 0.251)

# ---------------------------------------------------------------------------
# 3. 调色板实例字段 —— 供 resources/colors/color_tokens.tres 与
#    color_tokens_cvd.tres 承载，运行时热切换（architecture.md §9）。
#    字段名与上方 const 同名，便于 `palette.get(token_name)` 与
#    `ColorTokens.get_token(token_name)` 交叉校验（见 test_color_tokens.gd）。
# ---------------------------------------------------------------------------

@export var palette_id: StringName = &"normal"
@export var player_ally_main: Color = PLAYER_ALLY_MAIN
@export var resonance_glow: Color = RESONANCE_GLOW
@export var friendly_teal: Color = FRIENDLY_TEAL
@export var friendly_gold: Color = FRIENDLY_GOLD
@export var friendly_coral: Color = FRIENDLY_CORAL
@export var threat: Color = THREAT
@export var damage_warn: Color = DAMAGE_WARN
@export var heal_buff: Color = HEAL_BUFF
@export var ui_bg: Color = UI_BG
@export var sky_azure: Color = SKY_AZURE
@export var gate_ready: Color = GATE_READY
@export var inactive: Color = INACTIVE


## 按 Token 名取权威色。给 lint / 测试 / 数据驱动资源用；
## 游戏代码请直接写 `ColorTokens.THREAT`（静态、零查表开销）。
static func get_token(token_name: StringName) -> Color:
	match token_name:
		&"PLAYER_ALLY_MAIN":
			return PLAYER_ALLY_MAIN
		&"RESONANCE_GLOW":
			return RESONANCE_GLOW
		&"FRIENDLY_TEAL":
			return FRIENDLY_TEAL
		&"FRIENDLY_GOLD", &"FRIENDLY_AMBER", &"INTERACT":
			return FRIENDLY_GOLD
		&"FRIENDLY_CORAL":
			return FRIENDLY_CORAL
		&"THREAT":
			return THREAT
		&"DAMAGE_WARN":
			return DAMAGE_WARN
		&"HEAL_BUFF":
			return HEAL_BUFF
		&"UI_BG", &"UI_BASE":
			return UI_BG
		&"SKY_AZURE":
			return SKY_AZURE
		&"GATE_READY":
			return GATE_READY
		&"INACTIVE":
			return INACTIVE
	push_error("ColorTokens: 未知 Token 名 '%s'（权威表见 %s）" % [token_name, SOURCE_OF_TRUTH])
	return Color.MAGENTA


## 全部合法 Token 名（含别名）。lint 与一致性测试用。
static func all_token_names() -> PackedStringArray:
	return PackedStringArray([
		"PLAYER_ALLY_MAIN", "RESONANCE_GLOW", "FRIENDLY_TEAL", "FRIENDLY_GOLD",
		"FRIENDLY_CORAL", "THREAT", "DAMAGE_WARN", "HEAL_BUFF", "UI_BG",
		"SKY_AZURE", "GATE_READY", "INACTIVE",
		# 别名（合法引用，非退役名）
		"FRIENDLY_AMBER", "UI_BASE", "INTERACT",
	])


## 已退役 hex 字面量拒绝名单（color-tokens.md §4）。lint 直接消费本表。
## 注意：只收**退役 hex**，不收别名 Token 名。
static func retired_hex_denylist() -> PackedStringArray:
	return PackedStringArray(["2BB6A8", "F4B740"])
