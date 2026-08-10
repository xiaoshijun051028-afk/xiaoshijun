# Epic E4 · S4 敌人 AI (Enemy AI)

- **系统**：S4 敌人 AI（3 原型 + 1 Boss，telegraph 预警 + 破防）
- **依赖**：S0（EnemyDefinition / 敌人 FSM 复用基类）、S1（动词/预警联动、破防）、S3（击杀 +15、终结技伤害）
- **目标**：兑现美学 Challenge（读招精度）+ 防认知过载（统一预警语言）+ 支柱 P3（造物造型可读）。
- **出口**：telegraph 100% 覆盖；Sentinel 弱点 x2；Boss 阶段切换无即死；AC-S4-01..04 覆盖。
- **关联 ADR**：adr-003（复用同一 FSM 基类）、adr-002（击杀 +15 经 `add` 入口）。
- **GDD 验收覆盖**：AC-S4-01..04（见 `test-plan.md` §7）。

## 故事清单（5）

### ENG-S4-01 · EnemyDefinition + 敌人 FSM 复用
- **依据**：architecture.md §4.5；control-checklist §E/F。
- **验收**：
  - [ ] 敌人 `StateMachine` 复用 `src/core/state.gd` 基类，状态集 `Idle/Telegraph/Attack/Recover/Stagger/Dead`。
  - [ ] `EnemyDefinition.tres` 驱动 HP / telegraph 帧数 / dmg / 移速 / 弱点。
  - [ ] 状态迁移写环形日志（架构 §11.4 `src/ai/**` 可调试）。
- **测试路径**：`tests/unit/test_enemy_state_machine.gd`（状态转移合法序列）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S4-02 · 3 原型 + telegraph 配置
- **GDD §⑦**：AC-S4-01（所有攻击 100% 有 THREAT 色 telegraph + 音效）。
- **验收**：
  - [ ] Brute（HP120, telegraph 0.8–1.2s, dmg25–35）、Skirmisher（HP60, 0.4–0.6s, dmg12–18）、Sentinel（HP80, 0.5s, dmg10–15）。
  - [ ] 每次攻击前 wind-up 显 `THREAT=#A62C6B` 脉冲 + 音效（语义色来自 `ColorTokens`，非字面量）。
  - [ ] 多 telegraph 叠加：同一敌人不同招式不重叠；硬直中禁新 telegraph。
- **测试路径**：`tests/integration/test_telegraph_threat.gd`（每个原型每个攻击断言 telegraph 帧有 THREAT 信号 + 音效触发）。
- **估算**：L ｜ **优先级 🔴**

### ENG-S4-03 · Sentinel 弱点 x2
- **GDD §⑦**：AC-S4-03（Sentinel 弱点受击伤害 ≈ 非弱点 x2，±5%）。
- **验收**：
  - [ ] Sentinel 弱点(核心)受击伤害 ≈ 非弱点 ×2（±5%）。
  - [ ] 弱点判定来自 `EnemyDefinition.weakpoint_multiplier`，非字面量。
- **测试路径**：`tests/unit/test_sentinel_weakpoint.gd`（注入弱点/非弱点命中，断言比值 2.0±0.1）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S4-04 · 完美格破防联动（共享 S1）
- **GDD §⑦**：AC-S4-02（完美格 100% 触发破防硬直 ≥1s）。
- **验收**：
  - [ ] 玩家在 `PARRY_WINDOW` 内格挡敌人 telegraph → 敌人进入 `Stagger` 硬直 ≥1.2s。
  - [ ] 破防触发经由 S1 的 `try_transition(Stagger)` 唯一入口（与 S1-ENG-04 共用逻辑）。
  - [ ] 破防期间禁新 telegraph（架构 §4.5 约束）。
- **测试路径**：`tests/integration/test_parry_stagger.gd`（复用 S1 测试，断言敌人硬直帧）。
- **估算**：S ｜ **优先级 🔴**（依赖 S1-ENG-04）

### ENG-S4-05 · Boss 阶段切换无即死
- **GDD §⑦**：AC-S4-04（Boss 阶段切换无即死：清 telegraph + 无敌 0.5s）。
- **验收**：
  - [ ] Boss HP 800–1200，2–3 阶段，阶段切换显 THREAT 全屏脉冲。
  - [ ] 阶段血线切换时清空当前 telegraph + 无敌 0.5s（防即死）。
  - [ ] 阶段切换不造成非法状态（池/HP 不变负）。
- **测试路径**：`tests/integration/test_boss_phase_switch.gd`（注入阶段血线，断言 telegraph 清空 + 0.5s 无敌 + 无即死）。
- **估算**：M ｜ **优先级 🟡**

## 跨 Epic 接口（systems-index §3）
- ↔ S1：telegraph 显 THREAT；格挡联动破防；承受斩/终结技伤害。
- → S3：被击杀 `add(15,"kill")`；终结技消耗池（S1 触发）。
- → S6：HUD 威胁标记 / Boss 血条（S6-ENG-03）。
- → S5：巡逻范围绑定关卡区域。
