# GDD · 敌人 AI 系统 (Enemy AI)
> 系统编号 S4 ｜ 版本 v0.2 ｜ 依赖 S1(动词/预警), S3(共鸣伤害) ｜ 上游 概念文档 v0.2

## ① 概述与目标
3 原型 + 1 Boss 的混沌侵蚀造物，全部攻击经 telegraph 预警并显 `THREAT=#A62C6B`（概念 v0.2 语义色）。目标：兑现美学 Challenge（读招精度）+ 防认知过载（统一预警语言）+ 支柱 P3（精美即叙事：造物造型可读）。

## ② 核心机制/规则
- Telegraph 协议：每次攻击前 wind-up，显 `THREAT` 色脉冲 + 音效；窗口随难度缩放（Normal 0.6–1.2s，Hard 0.4–0.8s）。
- 可格挡：在 `PARRY_WINDOW` 内玩家格挡 → 破防硬直。
- 3 原型：
  - Brute 重击型：HP 120，慢速重砸，telegraph 0.8–1.2s，dmg 25–35，可被跃落地震波打断。
  - Skirmisher 突进型：HP 60，dash 突进，telegraph 0.4–0.6s，dmg 12–18，高频但脆。
  - Sentinel 远程型：HP 80，发射 projectile，telegraph 0.5s，dmg 10–15，弱点(核心)受击 x2。
- Boss：HP 800–1200，2–3 阶段，阶段切换显 `THREAT` 全屏脉冲；含以上原型招式组合。

## ③ 状态与数据流
- 状态：hp、state(idle/telegraph/attack/recover/stagger/dead)、telegraphing(0/1)、weakpoint(0/1)。
- 数据流：感知玩家 → 决策（距离/类型）→ telegraph → 攻击判定 → 命中玩家(S1 HP↓)/被格挡(破防) → 死亡(S3 +15) → 掉落/叙事。
- 共鸣伤害：玩家终结技（S1）造成 S3 池相关高伤。

## ④ 与其他系统接口
- ↔ S1：telegraph 显 `THREAT`；格挡联动破防；承受斩/终结技伤害。
- → S3：被击杀 +15；终结技消耗池。
- → S6：HUD 威胁标记 / Boss 血条。
- → S5：巡逻范围绑定关卡区域。

## ⑤ 数值/参数初值
- Brute：HP 120，telegraph 0.8–1.2s，dmg 25–35。
- Skirmisher：HP 60，telegraph 0.4–0.6s，dmg 12–18，移速 8 m/s。
- Sentinel：HP 80，telegraph 0.5s，dmg 10–15，弹速 18 m/s，弱点 x2。
- Boss：HP 800–1200，阶段 2–3，阶段切换脉冲 1s。
- 破防硬直 1.2s（与 S1 一致）。
- `THREAT=#A62C6B` 全局预警色。

## ⑥ 边界与失败处理
- 多 telegraph 叠加：同一敌人不同招式不重叠 telegraph；硬直中禁新 telegraph。
- 卡地形：寻路失败 → 退回 lastKnown 点，超时 2s 重置。
- 玩家脱战：敌人返回巡逻，不穿墙追击。
- Boss 阶段血线：阶段切换时清空当前 telegraph，防即死。

## ⑦ 可测试性
- [ ] 所有攻击 100% 有 `THREAT` 色 telegraph + 音效。
- [ ] 完美格 100% 触发破防硬直 ≥1s。
- [ ] Sentinel 弱点受击伤害 ≈ 非弱点 x2（±5%）。
- [ ] Boss 阶段切换无即死（清 telegraph + 无敌 0.5s）。

## ⑧ 开放问题
- 敌人是否共享"警觉链"（一只发现全员警觉）？
- 第 2 个 Boss（Should）的招式集？
