# Epic E8 · S8 元进度·神龛 (Meta-Progression: Shrines)

- **系统**：S8 元进度·神龛（唯一存档/复活点 + Should 技能树）
- **依赖**：S5（神龛位 / 复活落点）、S1（技能树效果）
- **目标**：神龛为唯一存档/复活点（核心循环闭环）；Meta 轻量无 grind（防经济失衡）；Should 共鸣配装技能树。
- **出口**：存档还原 100%；写盘失败不崩；AC-S8-01..04 覆盖。
- **关联 ADR**：adr-004（版本化 JSON / 原子写 / 钳制 / 不存常量）；architecture.md §10（复活不读盘）。
- **GDD 验收覆盖**：AC-S8-01..04（见 `test-plan.md` §7）。

## 故事清单（5）

### ENG-S8-01 · 神龛写盘（序列化全状态）
- **GDD §⑦**：AC-S8-01（神龛存档/读档 100% 还原状态）。
- **验收**：
  - [ ] `SaveManager` 神龛交互 → 序列化（玩家状态/共鸣池/岛屿进度/残响/技能树）。
  - [ ] 读档 → 反序列化 → 应用至 S1/S2/S3/S5/S7。
  - [ ] **存档中不含任何 `GameConstants` 常量**（单测断言，保护 ADR-002 单一真相源）。
  - [ ] `schema_version` + `checksum` + `migrate_N_to_N+1()` 迁移链。
- **测试路径**：`tests/unit/test_save_roundtrip.gd`（`test_save_restore_100`、`test_save_no_constants`、`test_save_version_mismatch_rejected`）。
- **估算**：M ｜ **优先级 🔴**（依赖 S0-ENG-10 存档骨架）

### ENG-S8-02 · 复活流程（内存复位 + 传送）
- **GDD §⑦**：AC-S8-02（死亡 100% 最近神龛复活且保留收集）。
- **验收**：
  - [ ] 死亡/坠落 → 最近神龛满血复活，保留全部收集与技能。
  - [ ] **不读盘**：内存复位 + 传送至神龛落点（S5-ENG-04）；传送后 `reset_physics_interpolation()`。
  - [ ] 无神龛死亡：兜底用中枢岛神龛（S5 中枢 1）。
- **测试路径**：`tests/integration/test_respawn.gd`（注入死亡，断言复位到最近神龛 + 收集保留 + 不触发读盘）。
- **估算**：S ｜ **优先级 🔴**（与 S2-ENG-05 联动）

### ENG-S8-03 · 写盘失败不崩溃
- **GDD §⑦**：AC-S8-04（写盘失败不崩溃）。
- **验收**：
  - [ ] 模拟磁盘满/权限失败 → 保留内存状态，emit `save_completed(false)`，HUD 提示「未保存」。
  - [ ] 旧存档不被破坏（原子写 + `.bak` 轮转，adr-004）。
  - [ ] 读档版本不匹配 → 拒绝并提示，不损坏（与 ENG-S8-01 迁移链共用）。
- **测试路径**：`tests/unit/test_save_failure.gd`（`test_disk_full_no_crash`、`test_corrupt_restore_from_bak`）。
- **估算**：S ｜ **优先级 🔴**

### ENG-S8-04 · 读档版本不匹配拒绝
- **GDD §⑥**：读档版本不匹配拒绝并提示，不损坏。
- **验收**：
  - [ ] 读取 `schema_version` 高于当前 → 拒绝加载，提示玩家，保留当前会话。
  - [ ] 校验 `checksum` 失败 → 回退 `.bak` 或拒绝。
- **测试路径**：`tests/unit/test_save_version_mismatch.gd`（注入旧/新版本，断言拒绝行为）。
- **估算**：S ｜ **优先级 🟡**

### ENG-S8-05 · 技能树（Should）在神龛应用
- **GDD §⑦**：AC-S8-03（技能树效果在神龛正确应用至 S1/S2/S3）；§⑧ 开放问题：洗点不纳入 v1。
- **验收**：
  - [ ] 技能点来自「发现/里程碑」（非刷怪）；总 ≈12–16，3 系（迅捷/共鸣/守护）。
  - [ ] 在神龛应用：影响 S1（取消窗下限 5f/伤害/完美闪奖励）、S2（移动）、S3（增益）。
  - [ ] **洗点不实现**（架构评审 CONCERN-2：预留而不实现，严守 MoSCoW）；数据结构分离 `skill_points` / `skills_unlocked`。
- **测试路径**：`tests/integration/test_skilltree_apply.gd`（解锁节点，断言 S1/S2/S3 参数生效）。
- **估算**：L ｜ **优先级 🟢**（Should，可后置）

## 跨 Epic 接口（systems-index §3）
- ← S5：神龛位 / 复活落点。
- → S1/S2/S3：技能树效果。
- → S6：技能树 UI（暂停菜单）。
- → S7：残响存档。
