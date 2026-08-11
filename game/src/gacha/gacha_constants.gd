class_name GachaConstants
extends RefCounted
## 星轨召唤（S9）常量单一真相源（design/gdd/systems/gacha.md）。
## 本文件自包含，不污染 GameConstants（避免改动 CI 的 test_constants_match_gdd）。
## 后续 Cross-Doc 一致性收尾：将 S9 常量登记进 GameConstants + systems-index §2（文策渊待办）。

## 稀有度档（值即枚举序）。
enum RARITY { N, R, SR, SSR }

## 稀有度显示名。
const RARITY_NAME: Dictionary = {
	RARITY.N: "尘",
	RARITY.R: "铁",
	RARITY.SR: "辉",
	RARITY.SSR: "星",
}

## 稀有度总权力预算乘子（千分比）。N=1.00 / R=1.15 / SR=1.35 / SSR=1.60。
const RARITY_MULT_MILLI: Dictionary = {
	RARITY.N: 1000,
	RARITY.R: 1150,
	RARITY.SR: 1350,
	RARITY.SSR: 1600,
}

## 维度权重（千分比）—— 稀有度乘区经此分配到五维。
## hp/affinity 1.0；defense 0.7；attack 0.5（P1 守卫：压制攻击膨胀）；move_speed 0.1（P2 守卫：关卡间距基准）。
const WEIGHT_MILLI: Dictionary = {
	&"hp": 1000,
	&"resonance_affinity": 1000,
	&"defense": 700,
	&"attack": 500,
	&"move_speed": 100,
}

## 基础抽取概率（保底前，千分比，和=100000=100%）。
## N 50000 / R 35000 / SR 13000 / SSR 2000。
const BASE_RATE_MILLI: Dictionary = {
	RARITY.N: 50000,
	RARITY.R: 35000,
	RARITY.SR: 13000,
	RARITY.SSR: 2000,
}

## SSR 保底。
const PITY_SSR_SOFT: int = 74   # 软保底起点：此后 SSR 概率线性爬升
const PITY_SSR_HARD: int = 90   # 硬保底：必出 SSR（曲线的自然收敛点，clamp 到 10000）
const SSR_PITY_STEP_MILLI: int = 500  # 每抽 SSR 概率增量（千分比），使 90 抽达 100%

## SR 保底（十连保障）。pity_sr 连续未出 SR/SSR 抽数；≥9 时本抽强制 SR。
const PITY_SR_HARD: int = 10

## 副属性 roll（千分比）。attack/defense/affinity 各独立 roll 一次；hp/move_speed 不 roll（恒 1000）。
const ROLL_MIN_MILLI: int = 950
const ROLL_MAX_MILLI: int = 1050
const ROLL_STEP_MILLI: int = 5
const ROLL_STEPS: int = (ROLL_MAX_MILLI - ROLL_MIN_MILLI) / ROLL_STEP_MILLI  # 20 → 21 档

## 抽取成本（双货币均游玩获取，预留字段不接支付 —— Steam 买断单机安全默认）。
const COST_DUST_PER_PULL: int = 160
const COST_DUST_TEN: int = 1600
const COST_ASTRAL_PER_PULL: int = 1
const COST_ASTRAL_TEN: int = 10

## 重复角色返还（尘）+ 重掷权。
const DUST_PER_DUPLICATE: int = 40
