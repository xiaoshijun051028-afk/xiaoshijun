# Epic E6 · S6 UX / HUD

- **系统**：S6 UX / HUD（极简 HUD + 双输入 + 可访问性）
- **依赖**：S1（hp/combo/iframe）、S3（resonance）、S4（threat/bossHp）、S5（area/objective）【全部为只读状态源】
- **目标**：可读性优先、防认知过载；键鼠 + 手柄双输入；Challenge 不靠信息堆砌。
- **出口**：三态色正确；双设备通关；AC-S6-01..04 覆盖。
- **关联 ADR**：adr-002（HUD 订阅 ResonancePool，不调用 `add`）；architecture.md §4.6（HUD 不持有游戏状态）。
- **GDD 验收覆盖**：AC-S6-01..04（见 `test-plan.md` §7）。

## 纪律红线
`src/ui/**`、`scenes/ui/**` **不持有游戏状态**：只读订阅 EventBus；禁止 UI 直接改玩法状态；禁止 UI 调 `ResonancePool.add()`（architecture.md §11.4）。

## 故事清单（5）

### ENG-S6-01 · HUD 5 类元素骨架（只读）
- **GDD §⑦**：AC-S6-01（HUD 仅含 5 类元素）。
- **验收**：
  - [ ] 仅 5 类：①玩家 HP 条（左上）②共鸣池条（HP 下）③目标追踪（右上箭头）④威胁标记（telegraph 边缘脉冲）⑤Boss 血条（底部居中）。
  - [ ] 不显示经验/金币/复杂资源（无经济系统）。
  - [ ] 全部元素只读订阅 EventBus；状态源断连时显示最后已知值 + "?"，不崩溃。
- **测试路径**：`tests/integration/test_hud_elements.gd`（断言场景树仅含 5 类 HUD 节点 + 断连降级）。
- **估算**：M ｜ **优先级 🟡**

### ENG-S6-02 · 共鸣三态色
- **GDD §⑦**：AC-S6-02（共鸣≥40 终结技态、≥30 开门态、<30 灰，三态正确）。
- **验收**：
  - [ ] 订阅 `ResonancePool.resonance_changed`；≥40 显「可终结技」青白；≥30 显「可开门」；<30 灰。
  - [ ] 三态由 `ColorTokens` 驱动（CONCERN-A 裁决前暂用 systems-index 值），无 hex 字面量（lint 拦截）。
  - [ ] 终结技态灰显联动 S1-ENG-05（池<40 禁用）。
- **测试路径**：`tests/integration/test_hud_resonance_states.gd`（注入池值 39/30/40，断言三态色与启用位）。
- **估算**：S ｜ **优先级 🔴**（依赖 S3-ENG-04 广播）

### ENG-S6-03 · 威胁标记 100% 对应 telegraph
- **GDD §⑦**：AC-S6-03（威胁标记 100% 对应 S4 telegraph）。
- **验收**：
  - [ ] 订阅 S4 telegraph 事件 → 边缘脉冲（频率 2Hz，THREAT 色）。
  - [ ] 每个 S4 telegraph 起始均有对应威胁标记显隐；telegraph 结束标记消失。
  - [ ] 色盲模式：威胁附形状提示（脉冲 + 菱形），不只靠色。
- **测试路径**：`tests/integration/test_hud_threat_marker.gd`（注入 telegraph 起止，断言标记同步）。
- **估算**：S ｜ **优先级 🟡**（依赖 S4-ENG-02）

### ENG-S6-04 · 双设备通关（键鼠 + 手柄）
- **GDD §⑦**：AC-S6-04（键鼠 + 手柄均可完成核心循环）。
- **验收**：
  - [ ] 键鼠（WASD + 鼠标）与手柄（左摇杆 + RT/LT/RB 映射 6 动词）均可完成核心循环（S3+S1 最小切片）。
  - [ ] 双设备同时 → 最近输入设备优先（InputManager 仲裁，S0-ENG-09）。
  - [ ] 全动作可重映射 UI + `user://input_map.json` 持久化（独立于存档）+ 冲突检测。
- **测试路径**：人工/录像（交严守真）；CI 含 `tests/integration/test_dual_device_core_loop.gd`（脚本驱动双设备输入跑通切片）。
- **估算**：M ｜ **优先级 🟡**

### ENG-S6-05 · 分辨率适配与可访问性输入
- **GDD §⑥**：1280×720–4K 适配；可访问性输入项（长按↔切换、连点辅助、死区/灵敏度可调）。
- **验收**：
  - [ ] HUD 锚定九宫格，1280×720–4K 不溢出。
  - [ ] 可访问性输入项接 InputManager：长按↔切换、连点辅助、死区/灵敏度可调。
  - [ ] 与画质档正交的可访问性开关（故障强度/镜头抖动/暗角，S0-ENG-08）。
- **测试路径**：`tests/integration/test_hud_resolution.gd`（多分辨率布局断言）。
- **估算**：S ｜ **优先级 🟢**

## 跨 Epic 接口（systems-index §3）
- ← S1/S3/S4/S5：状态源（只读）。
- → S8：暂停菜单入口（技能树 UI）。
- → 所有：语义色一致（systems-index §2 / ColorTokens）。
