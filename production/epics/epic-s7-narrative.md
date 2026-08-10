# Epic E7 · S7 叙事·残响回声 (Narrative: Resonance Echoes)

- **系统**：S7 叙事·残响回声（残响节点 + 碎片化叙事）
- **依赖**：S3（节点触发 +10 池 / 5s cd）、S5（残响节点位）
- **目标**：兑现支柱 P3（精美即叙事）、SDT 关联（轻量情感连接）、美学 Narrative/Discovery。
- **出口**：节点 +10 正确；战斗中不卡输入；AC-S7-01..04 覆盖。
- **关联 ADR**：adr-002（节点增益经 `add` 入口）、adr-004（残响随神龛存档）。
- **GDD 验收覆盖**：AC-S7-01..04（见 `test-plan.md` §7）。

## 故事清单（4）

### ENG-S7-01 · EchoDirector + 节点触发 +10 池
- **GDD §⑦**：AC-S7-01（所有节点可触发且 +10 池正确）。
- **验收**：
  - [ ] `EchoDirector`（S0-ENG-05 占位）接管节点触发；玩家按 resonate → 节点 `RESONANCE_GLOW` 发光 + 残响播放。
  - [ ] 触发经 `ResonancePool.resonate_at_node()`（+10，5s cd，逻辑在 S3-ENG-03）。
  - [ ] 所有节点（每岛 2–3，S5-ENG-05 布置）均可触发。
- **测试路径**：`tests/integration/test_echo_node_trigger.gd`（注入节点触发，断言池+10 且节点发光）。
- **估算**：M ｜ **优先级 🟡**（依赖 S3-ENG-03 / S5-ENG-05）

### ENG-S7-02 · 残响收集计入发现进度
- **GDD §⑦**：AC-S7-02（残响收集计入发现进度）。
- **验收**：
  - [ ] 每次触发标记 `echoCollected[]`，计入「发现」进度（Explorer/Bartle）。
  - [ ] 进度经 EventBus 广播给 S6（S6-ENG-01 进度更新）。
  - [ ] 随神龛存档（S8-ENG-01）。
- **测试路径**：`tests/integration/test_echo_collection.gd`（触发 N 节点，断言发现进度计数）。
- **估算**：S ｜ **优先级 🟡**

### ENG-S7-03 · 节点 5s cd 去重
- **GDD §⑦**：AC-S7-03（5s cd 内不重复增益）；AC-S3-04 共享。
- **验收**：
  - [ ] cd 内重复触发不二次增益（逻辑在 S3-ENG-03，本 Story 验证端到端）。
  - [ ] 残响可跳过（8–20s），跳过仍计收集。
- **测试路径**：`tests/integration/test_echo_node_cd.gd`（连续触发，断言仅首次 +10）。
- **估算**：S ｜ **优先级 🟡**（依赖 S3-ENG-03）

### ENG-S7-04 · 战斗中触发不卡输入
- **GDD §⑦**：AC-S7-04（战斗中触发不卡输入）。
- **验收**：
  - [ ] 战斗中触发残响：不暂停（保持流动），回声半透明叠加。
  - [ ] 触发期间输入链路（S1 FSM）不被阻塞；resonate verb 与战斗 verb 互斥经 FSM 单一入口。
  - [ ] 语言缺失回退文本，不阻断。
- **测试路径**：`tests/integration/test_echo_no_input_lock.gd`（战斗中触发，断言 FSM 仍响应斩/闪输入）。
- **估算**：S ｜ **优先级 🟡**（依赖 S1-ENG-02）

## 跨 Epic 接口（systems-index §3）
- → S3：节点 +10，cd 5s。
- → S5：节点位。
- → S6：发现进度。
- → S8：存档。
