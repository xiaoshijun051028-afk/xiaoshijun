# Epic E3 · S3 共鸣能量池 (Resonance Pool)

- **系统**：S3 共鸣能量池（根资源，无前置依赖）
- **依赖**：S0（GameConstants / EventBus / ResonancePool 单例 / 测试脚手架）
- **目标**：实现单一共享池的全部数学与互斥逻辑，使 S1（终结技）、S5（闸门）、S7（节点）可消费；兑现支柱 P4「共鸣统一」。
- **出口**：S3 四条 GDD 验收单测全绿（`tests/unit/test_resonance_pool.gd` 等）。
- **关联 ADR**：adr-002（单例单一真相源）、adr-004（常量不落盘）。
- **GDD 验收覆盖**：AC-S3-01..04（见 `test-plan.md` §7）。

## 故事清单（4）

### ENG-S3-01 · 池核心数学与上限钳制
- **GDD §⑦**：AC-S3-01（池上限严格 100，不溢出）、AC-S3-02（恰扣 40 / 30）。
- **验收**：
  - [ ] `ResonancePool` 私有 `_current`，初始 50，上限 `MAX=100`。
  - [ ] `add(amount)` 后 `clampi` 到 [0,100]，溢出部分丢弃（不保留）。
  - [ ] `try_spend(cost, reason)` 余额不足返回 `false` 且不扣；充足则扣减并返回 `true`，emit `resonance_spend_rejected`（仅失败时）。
  - [ ] 终结技恰扣 `FINISHER_COST=40`、闸门恰扣 `GATE_COST=30`（数值来自 `GameConstants`，非字面量）。
- **测试路径**：`tests/unit/test_resonance_pool.gd`（`test_cap_no_overflow`、`test_spend_exact_40_30`）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S3-02 · 互斥消耗（P4 支柱核心）
- **GDD §⑦**：AC-S3-03（池=35 时可开门不可终结技）。
- **验收**：
  - [ ] 池=35 时 `try_spend(30,"gate")` 成功、`try_spend(40,"finisher")` 失败。
  - [ ] 同一帧「开门 + 终结技」竞争：优先玩家主动输入（终结技），闸门排队（adr-002 决策）。
  - [ ] 扣费/增益唯一入口（`try_spend`/`add`），无其它代码路径改 `_current`。
- **测试路径**：`tests/unit/test_resonance_pool.gd`（`test_mutex_35_gate_ok_finisher_no`、`test_double_spend_priority`）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S3-03 · 节点共鸣增益与 5s 冷却
- **GDD §⑦**：AC-S3-04（节点 5s cd 内重复触发不二次增益）。
- **验收**：
  - [ ] `resonate_at_node()` 触发 `+10` 并启动 5s cd。
  - [ ] cd 内重复调用不二次增益（返回 `false` 或忽略）。
  - [ ] cd 用整数帧计时（5s ≈ 300 tick，对齐 §3 时间基准），确定性、与刷新率无关。
- **测试路径**：`tests/unit/test_resonance_node_cd.gd`（`test_node_gain`、`test_node_cd_blocks_repeat`）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S3-04 · 扣费/增益入口与 EventBus 广播
- **GDD §③/§④ 接口契约**：S1→S3 终结技扣 40 且不足禁用；S5→S3 闸门扣 30 不够不解锁；S3→S6 广播池量。
- **验收**：
  - [ ] 每次 `add`/`try_spend` 后 emit `resonance_changed(current, delta, source)`。
  - [ ] 失败时 emit `resonance_spend_rejected(reason)`。
  - [ ] HUD 桩（S6）可订阅并刷新；无其它系统直接读写 `_current`。
  - [ ] **断言**：任何增益来源（命中+1/完美格+5/击杀+15/脱战+2s）经统一 `add()` 入口，分离到对应 Epic 的集成测试（S1/S4/S7）。
- **测试路径**：`tests/integration/test_resonance_events.gd`（`test_event_on_change`、`test_event_on_reject`）。
- **估算**：S ｜ **优先级 🟡**

## 跨 Epic 接口（systems-index §3）
- → S1：`try_spend(40,"finisher")`，不足则 S1 终结技态禁用（HUD 灰显，见 S1-ENG-04 / S6-ENG-02）。
- → S5：闸门 `try_spend(30,"gate")`，不够不解锁（见 S5-ENG-03）。
- → S7：节点 `resonate_at_node()` +10 与 5s cd（见 S7-ENG-01）。
- → S8：存档/读档同步当前值（不存常量，见 adr-004 / S8-ENG-01）。
