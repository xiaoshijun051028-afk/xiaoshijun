# Epic E1 · S1 核心战斗 (Combat)

- **系统**：S1 核心战斗（6 动词近战 + 取消窗 + 命中反馈 + 终结技）
- **依赖**：S0（FSM 基类 / InputManager / CameraRig）、S3（终结技扣池）
- **目标**：兑现支柱 P1「流动即正义」（≤8 帧取消窗连段手感）、P4「共鸣统一」（终结技共用池）、美学 Challenge（精确读招）。
- **出口**：取消 ≤8 帧集成测试全绿；**手感 SPIKE-3 通过**；AC-S1-01..05 覆盖。
- **关联 ADR**：adr-003（节点化 FSM + 整数帧计时 + 取消窗单点）、adr-002（终结技扣池）。
- **GDD 验收覆盖**：AC-S1-01..05（见 `test-plan.md` §7）。

## 故事清单（6）

### ENG-S1-01 · SPIKE-3 手感原型（P1 核心，最高价值验证）
- **依据**：control-checklist §N-SPIKE-3；architecture.md §13（S1 出口含「手感 spike 通过」）。
- **验收**：
  - [ ] 斩/闪/跃三动词 + 8 帧取消窗在最小场景跑通。
  - [ ] 主观手感确认（程基岩 + 主理人 + 严守真试玩）；中断感可接受。
  - [ ] 若手感不达标，回 architecture.md §3 时间基准或 verb 帧数（数据驱动，改 `.tres` 不改代码）。
- **测试路径**：手动试玩 + `tests/integration/test_cancel_window.gd` 作为客观旁证。
- **估算**：M ｜ **优先级 🔴**（全项目最高价值验证）

### ENG-S1-02 · FSM 动词态与取消窗逻辑
- **GDD §⑦**：AC-S1-01（任意两动词间取消延迟 ≤8 帧）、AC-S2-03（跃→闪→斩 ≤8 帧，跨 S2）。
- **验收**：
  - [ ] `StateMachine` 含 idle → {slash, dash, grapple, leap, parry, resonate} 状态节点。
  - [ ] 任意动作收招在 `CANCEL_WINDOW=8f` 内可接续另一动作（经 `State.is_cancellable()` 单点判定）。
  - [ ] 取消计时为整数 tick（对齐 §3），确定性。
  - [ ] 闪可取消斩收招、跃可取消闪、格可接斩反击——全部经同一 `try_transition()` 入口。
- **测试路径**：`tests/integration/test_cancel_window.gd`（第 8 帧可取消、第 9 帧不可；斩→闪、跃→闪→斩 链式）。
- **估算**：L ｜ **优先级 🔴**

### ENG-S1-03 · 命中/伤害结算与闪无敌帧
- **GDD §⑦**：AC-S1-05（闪 iframes 期间 0 伤害）。
- **验收**：
  - [ ] `DASH_IFRAMES=10f` 期间 `iframe=1`，注入攻击命中 `hp` 不变。
  - [ ] 多敌围攻：单次闪 iframes 对所有敌人生效，不区分来源。
  - [ ] 命中反馈：hit-stop 60–90ms + 轻微震屏（在 CameraRig/全局，非 `_process` 改状态）。
  - [ ] 伤害数值来自 `VerbDefinition.tres`（斩 8–12/段、重击 18–25），非字面量。
- **测试路径**：`tests/integration/test_iframes_zero_damage.gd`（注入攻击帧 + 断言 hp）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S1-04 · 完美格 → 破防 + 慢动作
- **GDD §⑦**：AC-S1-03（完美格触发慢动作 + 敌人硬直 ≥1s）；AC-S4-02（共享 S4 破防）。
- **验收**：
  - [ ] 在 `PARRY_WINDOW=6f` 内挡下 telegraph 攻击 → 敌人 `Stagger` 硬直 ≥1.2s + 慢动作 0.3s + 共鸣 +5（`ResonancePool.add(5,"parry")`）。
  - [ ] 完美格触发 hitstun 拒绝转移（架构 §4.4 `try_transition` 含 hitstun 拒绝）。
  - [ ] 慢动作实现不破坏 §3 物理 tick 基准（用 `Engine.time_scale` 或等效，不在 `_process` 改状态）。
- **测试路径**：`tests/integration/test_parry_stagger.gd`（注入 telegraph 命中 + 断言敌人硬直帧 + 池+5）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S1-05 · 共鸣终结技（池不足锁定）
- **GDD §⑦**：AC-S1-04（共鸣不足时终结技不可释放且 HUD 灰显）。
- **验收**：
  - [ ] 池 ≥ `FINISHER_COST=40` 时，斩终段接续 resonate → 触发终结技（高伤 + 击退 + 全屏谐波）。
  - [ ] 池 < 40 时终结技态禁用，`try_spend` 失败，emit `resonance_spend_rejected`；HUD 灰显（S6-ENG-02）。
  - [ ] 终结技扣费经 `ResonancePool.try_spend(40,"finisher")` 唯一入口。
- **测试路径**：`tests/integration/test_finisher_lockout.gd`（池=39 不可释放；池=40 可释放且扣 40）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S1-06 · 连段中断率 <5%（人工）
- **GDD §⑦**：AC-S1-02（连段中断率 <5%，20 名玩家原型测试）。
- **验收**：
  - [ ] 20 名玩家原型测试，记录连段中断次数 / 总连段数。
  - [ ] 中断率 <5%；超标则回 SPIKE-3 / verb 帧数调参（数据驱动）。
  - [ ] 结果写入 `docs/testing/playtest-combat.md`。
- **测试路径**：人工/录像（交严守真），不在 CI（见 `test-plan.md` §7 人工层）。
- **估算**：M ｜ **优先级 🟡**（依赖 SPIKE-3 与 S1-02/03/04 完成）

## 跨 Epic 接口（systems-index §3）
- → S3：终结技扣 40，不足禁用（S3-ENG-01/02/04）。
- ↔ S4：敌人 telegraph 显 THREAT；格挡联动破防（S4-ENG-04）。
- → S2：闪/跃为移动动词，共享取消窗（S2-ENG-03）。
- → S6：暴露 hp/combo/iframe/resonance（S6-ENG-01/02）。
- → S8：技能树可改取消窗/伤害/完美闪奖励（Should，S8-ENG-05）。
