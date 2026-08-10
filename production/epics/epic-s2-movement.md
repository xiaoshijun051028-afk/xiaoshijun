# Epic E2 · S2 移动与垂直穿越 (Movement & Vertical Traversal)

- **系统**：S2 移动与垂直穿越（闪 / 荡 / 跃 + 轻重力 + 锚点）
- **依赖**：S0（CharacterBody3D 基类 / 输入）、S5（锚点数据契约；本 Epic 先读「占位锚点源」，S5 后续填充真实锚点）
- **目标**：兑现支柱 P2「垂直即世界」——浮空群岛以空中为主场的垂直移动，与战斗共享取消窗保持流动。
- **出口**：跃→闪→斩 ≤8 帧集成测试绿；越界复活 100%；AC-S2-01..04 覆盖（可达比/纯空中路线由 S5 工具层最终核验）。
- **关联 ADR**：adr-005（CharacterBody3D + 手动积分 + 绳约束投影，非 RigidBody/关节）。
- **GDD 验收覆盖**：AC-S2-01..04（见 `test-plan.md` §7）。

## 顺序张力处理（CONCERN-C）
`systems-index` §1 标注 S2 依赖 S5(锚点)，但 DAG 把 S2 排在 S5 前。处理：**S0 建立「锚点数据契约 `AnchorSource` 接口 + 占位锚点源」**，S2 只依赖契约读取 `get_anchors_in_range(pos, 15m)`；S5（ENG-S5-02）后续填充真实锚点，不改 S2 代码。此张力已在 architecture-review CONCERN-C 登记，S0 完成后立即建性能基线验证。

## 故事清单（6）

### ENG-S2-01 · SPIKE-4 荡索约束求解（ADR-005）
- **依据**：control-checklist §N-SPIKE-4；adr-005。
- **验收**：
  - [ ] 摆荡手感达标（拉向锚点 + 连续荡动量守恒）。
  - [ ] 脱钩自然滑落（保留当前速度，不瞬移）。
  - [ ] 绳约束用投影法（非 spring joint / RigidBody）。
- **测试路径**：手动试玩 + `tests/integration/test_grapple_constraint.gd`（断言脱钩速度与入钩速度连续）。
- **估算**：M ｜ **优先级 🟡**

### ENG-S2-02 · 轻重力移动与角色控制器
- **GDD §⑤**：重力 0.6g ≈ -5.88 m/s²；地面 5–7 m/s，空中 6–8 m/s。
- **验收**：
  - [ ] `locomotion.gd` 纯函数积分，`GRAVITY=-5.88`、`DELTA=1.0/60` **常量**（非 `_physics_process` 传入）。
  - [ ] `CharacterBody3D` 手动 `velocity` 应用 + `move_and_slide`。
  - [ ] 卡墙 0.2s 自动解卡推离（碰撞体粘连检测）。
- **测试路径**：`tests/unit/test_locomotion_integration.gd`（注入 dt 序列，断言位移符合 -5.88 积分）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S2-03 · 跃 / 闪 位移动词与取消链
- **GDD §⑦**：AC-S2-03（跃→闪→斩 取消延迟 ≤8 帧）；AC-S1-01 共享。
- **验收**：
  - [ ] 跃 Leap：起跳 3–4m，顶点 0.4s 悬停（可接闪调整），cd 0.6s。
  - [ ] 闪 Dash：水平 4–6m（兼 S1 战斗无敌，iframes 见 S1-ENG-03）。
  - [ ] 取消链 跃→闪→斩 经 FSM 同一 `try_transition()`，≤8 帧。
- **测试路径**：`tests/integration/test_leap_dash_cancel.gd`（跃第 N 帧接闪接斩，断言状态转移帧 ≤8）。
- **估算**：M ｜ **优先级 🔴**

### ENG-S2-04 · 荡 Grapple（锚点读取契约）
- **GDD §②**：≤15m 内锚点发射钩索，拉向目标，空中可连续荡（动量守恒）；不可抓表面显灰，可抓显 RESONANCE_GLOW 描边。
- **验收**：
  - [ ] 经 `AnchorSource.get_anchors_in_range(pos, 15.0)` 读取（契约，不直接依赖 S5 场景）。
  - [ ] 多锚点重叠：优先最近且视线无遮挡。
  - [ ] 脱钩中锚点消失 → 保留当前速度自然滑落（adr-005）。
  - [ ] 可抓/不可抓锚点描边由 `ColorTokens` 驱动：可抓 = `ColorTokens.PLAYER_ALLY_MAIN`（星辉青），不可抓 = `ColorTokens.INACTIVE`（灰）。CONCERN-A 已收口于 `design/color-tokens.md` v1.0，无待裁决占位。
- **测试路径**：`tests/integration/test_grapple_constraint.gd`（占位锚点源注入）。
- **估算**：L ｜ **优先级 🔴**（依赖 ENG-S2-01 spike）

### ENG-S2-05 · 越界坠落 → 神龛复活
- **GDD §⑦**：AC-S2-04（越界坠落 100% 触发神龛复活无卡死）。
- **验收**：
  - [ ] `y < 世界下限` → 0.5s 后触发 S8 复活（内存复位 + 传送，不读盘）。
  - [ ] 复活落点为最近神龛（无神龛兜底中枢岛），不掉收集、无卡死。
  - [ ] 传送后 `reset_physics_interpolation()`。
- **测试路径**：`tests/integration/test_fall_respawn.gd`（注入越界，断言 0.5s 内复位到神龛落点）。
- **估算**：S ｜ **优先级 🔴**（依赖 S8 复活流程占位，S8-ENG-02）

### ENG-S2-06 · 可达性 / 纯空中路线验证（工具层）
- **GDD §⑦**：AC-S2-01（单岛可达高点数/体积比 ≥0.6）、AC-S2-02（≥1 纯空中路线绕敌）。
- **验收**：
  - [ ] `tools/level_scan.gd` 统计每岛可达高点数/体积比，断言 ≥0.6。
  - [ ] 工具检测 ≥1 条纯空中路线绕过地面敌人（与 S5-ENG-06 共用扫描）。
  - [ ] 注：本 Story 在 S5 世界内容就绪后由工具层最终核验（S0 阶段仅建工具骨架）。
- **测试路径**：`tools/level_scan.gd`（每夜 CI 跑）。
- **估算**：M ｜ **优先级 🟡**（依赖 S5 世界内容）

## 跨 Epic 接口（systems-index §3）
- → S5：读取锚点列表（契约）；越界 → S8 复活。
- ↔ S1：闪/跃为共享动词，取消窗一致（S1-ENG-02/03）。
- → S6：暴露高度/区域名/锚点可用（S6-ENG-01）。
- → S8：神龛为安全落点。
