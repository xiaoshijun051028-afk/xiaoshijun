# 架构评审 · 星陨之境 (Aetherfall)

> 版本 v1.0 ｜ Phase 3 ｜ 评审人 程基岩（自评，Solo 评审强度）｜ 日期 2026-08-08
> 评审对象：`architecture.md` v1.0、`adr-001..005.md`
> 评审基准：`design/gdd/systems-index.md`（**常量单一真相源**）、8 篇系统 GDD、`design/art-bible.md`、`design/concept/game-concept.md` v0.2

## 0. 总体结论

# **PASS（带 3 项 CONCERN，0 项 FAIL）**

架构与 GDD 单一真相源一致，PC 性能预算可行，与美术圣经渲染项全部对齐。
**3 项 CONCERN 中 1 项（CONCERN-A 语义色冲突，源自上游文档间不一致）已于 2026-08-08 裁决闭合——`design/color-tokens.md` v1.0 为唯一权威；余 2 项需 Phase 4 实测验证。**

| 维度 | 结论 |
|---|---|
| 常量一致性（systems-index §2） | **PASS** |
| 依赖 DAG 一致性（systems-index §1） | **PASS** |
| 跨系统接口契约（systems-index §3） | **PASS** |
| 单例一致性（P4 支柱工程保障） | **PASS** |
| PC 性能可行性 | **CONCERNS**（见 B、C） |
| 与美术圣经渲染项对齐 | **PASS**（语义色见 A） |
| GDD 验收标准可测性 | **PASS** |
| 支柱（P1–P4）技术支撑 | **PASS** |
| Phase 2 遗留 CONCERN 处置 | **PASS** |

---

## 1. 常量一致性核查（systems-index §2 逐条）

方法：逐条比对 systems-index §2 与 `architecture.md` §4.2 的 `GameConstants`，并检查是否存在"另起一套常量"。

| systems-index §2 | 值 | GameConstants | 一致 |
|---|---|---|---|
| 帧基准 | 60 fps（1 帧 ≈16.67 ms） | `TICKS_PER_SECOND = 60`，且 **1 物理 tick ≡ 1 帧** | ✔ |
| `CANCEL_WINDOW` | 8 帧 | `CANCEL_WINDOW: int = 8` | ✔ |
| `PARRY_WINDOW` | 6 帧 | `PARRY_WINDOW: int = 6` | ✔ |
| `DASH_IFRAMES` | 10 帧 | `DASH_IFRAMES: int = 10` | ✔ |
| `THREAT` | `#A62C6B` | `ColorTokens.THREAT` | ✔ |
| `FRIENDLY` teal/amber/coral | `#5FD2C8` / `#F2C15E` / `#FF8A65` | `ColorTokens.FRIENDLY_*` | ✔ **已裁决**（CONCERN-A 闭合，color-tokens.md v1.0）|
| `RESONANCE_GLOW` | 青白 `#9FF7E8` | `ColorTokens.RESONANCE_GLOW` | ✔ **已裁决**（自发光态，与 `PLAYER_ALLY_MAIN=#5FD2C8` 拆分）|
| 池 `MAX` / 初始 | 100 / 50 | `RESONANCE_MAX=100` / `RESONANCE_INITIAL=50` | ✔ |
| 增益 命中/完美格/击杀/节点/脱战 | +1 / +5 / +15 / +10 / +2·s⁻¹ | `GAIN_HIT=1` / `GAIN_PERFECT_PARRY=5` / `GAIN_KILL=15` / `GAIN_NODE=10` / `GAIN_OUT_OF_COMBAT_PER_SEC=2` | ✔ |
| `GATE_COST` | 30 | `GATE_COST: int = 30` | ✔ |
| `FINISHER_COST` | 40 | `FINISHER_COST: int = 40` | ✔ |
| 单一共享池 → 开门与终结技互斥 | — | ADR-002 强制（无 setter，唯一扣费入口） | ✔ |

**补充核查（来自各 GDD §⑤ 而非 systems-index §2）**：

| 来源 | 值 | 架构落点 | 一致 |
|---|---|---|---|
| S3 §⑤ 节点 cd | 5 s | `NODE_COOLDOWN_SEC = 5.0` | ✔ |
| S3 §⑥ 脱战判定 | 3 s | `OUT_OF_COMBAT_SEC = 3.0` | ✔ |
| S8 §⑤ 取消窗下限 | 5 帧（技能树最多减 3） | `CANCEL_WINDOW_MIN = 5` | ✔ |
| S2 §⑤ 重力 | 0.6g ≈ −5.88 m/s² | ADR-005 `GRAVITY = -5.88` | ✔ |
| S1 §⑤/S4 §⑤ 破防硬直 | 1.2 s | 72 帧（`.tres`） | ✔ 换算正确 |
| S1 §⑥ hitstun 上限 | 0.5 s | 30 帧 | ✔ 换算正确 |
| S4 §② telegraph Normal/Hard | 0.6–1.2 s / 0.4–0.8 s | 36–72 帧 / 24–48 帧（`.tres`） | ✔ 换算正确 |

**判定：常量一致性 PASS（语义色 CONCERN-A 已裁决闭合，取值以 `design/color-tokens.md` v1.0 为准）。**

**架构层面的额外保障（超出"不冲突"的被动一致）**：
1. `GameConstants` 是唯一常量宿主，`SOURCE_OF_TRUTH` 常量显式指向 GDD 路径；
2. `tests/unit/test_constants_match_gdd.gd` **硬断言**全部数值，改动未同步 GDD → CI 红灯；
3. `src/combat|movement/**` 路径作用域规则**禁止玩法数值字面量**，lint 扫描（`tools/lint_magic_numbers.gd`）；
4. ADR-004 明确**常量不入存档**，杜绝老存档带回旧规则形成第二真相源。

> 这四条把"文档一致性"从人工约定变成了**可执行门禁**。

---

## 2. 依赖 DAG 与实现顺序核查（systems-index §1）

GDD 给定顺序：**S3 → S1 → S2 → S4 → S5 → S8 → S6 → S7**

`architecture.md` §13 给定：**S0（地基）→ S3 → S1 → S2 → S4 → S5 → S8 → S6 → S7**

| 检查项 | 结论 |
|---|---|
| S3 排第一（根资源，无前置） | ✔ 一致 |
| S1 依赖 S3（终结技） | ✔ ADR-002/003：`Resonate.can_enter()` 查询池 |
| S2 依赖 S5（锚点） | ⚠ **见 CONCERN-C（顺序张力，已缓解）** |
| S4 依赖 S1（动词/预警）、S3（共鸣伤害） | ✔ ADR-003 敌人复用同一 FSM 基类 |
| S5 依赖 S2/S3/S8 | ✔ 场景承载锚点/闸门/神龛 |
| S8 依赖 S5（神龛位）、S1（技能树效果） | ✔ ADR-004 |
| S6 依赖 S1/S3/S4（状态源） | ✔ 只读订阅 EventBus，UI 不持有状态 |
| S7 依赖 S3（触发）、S5（节点） | ✔ |
| 无环 | ✔ 架构未引入 GDD 之外的反向依赖 |

**S0 前置是否算偏离 DAG？** 判定**否**。S0 只包含 GDD 未涵盖的工程底座（Autoload 骨架、常量、EventBus、FSM 基类、tick 配置、测试框架、CI），**不实现任何 GDD 系统逻辑**，且是 S3 单测能够运行的前提（"先写测试"要求框架先在）。它是对 DAG 的补充，未改变任何系统间依赖关系。

**判定：依赖 DAG PASS。**

---

## 3. 跨系统接口契约核查（systems-index §3 逐条）

| # | 契约 | 架构落点 | 结论 |
|---|---|---|---|
| 1 | S1→S3：终结技扣 `FINISHER_COST`；池不足则不可用（HUD 灰显） | ADR-002 `try_spend(FINISHER_COST)` → 失败 emit `resonance_spend_rejected` → ADR-003 状态转移被拒（`can_enter()` false）→ HUD 三态色灰显（§4.6） | ✔ **三处联动闭合** |
| 2 | S5→S3：闸门扣 `GATE_COST`；不够不解锁并提示 | 同一 `try_spend(GATE_COST)` 入口；失败走同一 rejected 信号 | ✔ |
| 3 | S1↔S4：敌人 telegraph 显 `THREAT`；`PARRY_WINDOW` 内格挡 → 破防硬直 | `architecture.md` §5.3 流 B 完整落地：telegraph 事件 → HUD/材质/音效；`parry_armed_left` 帧计数；破防 72 帧 | ✔ |
| 4 | S3→S7：共鸣节点 → 节点发光 + 触发残响 | `EventBus.resonance_node_consumed` + `echo_triggered`；节点 5 s cd | ✔ |
| 5 | S5→S8：神龛为唯一存档/复活点；技能树在神龛应用 | ADR-004 §10.4 复活流程；兜底中枢岛神龛 | ✔ |
| 6 | S1/S3/S4→S6：HUD 读 hp/池/威胁/连段 | EventBus 只读订阅；HUD 不持有状态（§11.4 路径规则强制） | ✔ |

**判定：接口契约 PASS。**

**值得注意的正向发现**：契约 1 与 2 共用**同一个** `try_spend()` 入口，这不是巧合而是 ADR-002 的直接结果——它使 P4「互斥消耗」在代码层面成为不可绕过的事实，而非需要两处分别维护的约定。

---

## 4. 单例一致性核查（P4 支柱的工程保障）

支柱 P4 的验证方式是「共鸣池同时承担开门与终结技且互斥消耗——不存在只点战斗不点解谜的主导策略」。这要求**全局有且仅有一份池数值**。

| 潜在失效路径 | 架构阻断手段 | 结论 |
|---|---|---|
| HUD 缓存副本导致显示不一致 | §11.4 规定 UI 不持有游戏状态；HUD 冷启动主动拉一次当前值 | ✔ |
| 某系统直接写字段绕过互斥 | ADR-002：`_current` 私有 + **无 setter**，只读访问器 | ✔ |
| 增益超上限 | `add()` 内部 `mini(…, RESONANCE_MAX)`，唯一入口 | ✔ |
| 存档带回旧常量形成第二真相源 | ADR-004 决策 3：常量不入档 + 单测拦截 | ✔ |
| 同帧双消耗双花 | ADR-002 决策 3：`try_spend()` 同步返回 + `process_priority` 固定顺序 + 闸门排队 | ✔ |
| 篡改存档写入非法值 | ADR-004 决策 5：读档逐字段 `clampi` | ✔ |
| Autoload 泛滥稀释"单一权威"概念 | §4.3 准入红线（全局唯一 + 跨场景存活 + ≥3 系统消费）；8 个 Autoload 逐一列明职责与禁止事项 | ✔ |

**判定：单例一致性 PASS。**

三个单一真相源（`GameConstants` 常量、`ResonancePool` 池值、`ColorTokens` 语义色）采用同一模式，架构内部自洽。

---

## 5. PC 性能可行性核查

### 5.1 预算自洽性

| 检查项 | 结论 |
|---|---|
| CPU 9.0 ms + 余量、GPU 15.0 ms ≤ 16.67 ms 帧预算 | ✔ 分项求和自洽，留 1.67 ms 余量 |
| GPU 为瓶颈侧（15.0 ms 对 CPU 9.0 ms） | ✔ 符合 stylized 3D + SDFGI + 体积雾的实际形态 |
| 玩法逻辑仅 4.0 ms | ✔ 且因 §3 固定 60 Hz tick，高刷下不随渲染帧增长 |
| 三档画质均不牺牲玩法可读性 | ✔ §6.4 明确 THREAT/telegraph 在 Low 档同样清晰（硬约束） |
| 场景复杂度预算（draw call 1500 / 三角 2M / 粒子 30k） | ✔ 对 1660S 级基准机为保守合理值 |
| 美术圣经 §8.1「粒子封顶、拖尾 LOD」 | ✔ §7.3 单个 GPUParticles3D ≤2000 + 同屏 30k 封顶 |
| 美术圣经 §8.1「慎用 SSR，记账」 | ✔ Low 关闭 / High 半分辨率仅水面；4.6 SSR 重写降低成本 |
| 加载 ≤3 s、岛间有过场遮罩 | ✔ 不追求无缝，范围克制 |

### 5.2 风险项

- **CONCERN-B（输入延迟）** 与 **CONCERN-C（性能实测未做）** 见 §7。
- 正向缓解：4.7 的 `AreaLight3D` 让神龛/共鸣节点用真实面光而非"自发光 + SDFGI 弹跳"，**降低对 SDFGI 高档位的依赖**，是净性能收益（`architecture.md` §6.2）。

**判定：PC 性能可行性 CONCERNS（预算自洽且合理，但未经实测；关键风险已登记并排期）。**

---

## 6. 与美术圣经渲染项对齐核查

| 美术圣经条目 | 架构落点 | 结论 |
|---|---|---|
| §3.1 SDFGI（户外）/ VoxelGI（封闭） | §6.1 GI 分场景策略；`gi_mode` 材质规范 | ✔ |
| §3.1 VolumetricFog + 指数雾 + 高度雾托云海 | §6.1 完整落地 | ✔ |
| §3.1 单一 DirectionalLight3D「星核之日」+ 环境补光 | §6.2 Key/Fill 策略，PSSM 4 split | ✔ |
| §3.2 自定义 Sky Shader（星陨流光 + 极光） | §6.1 Background | ✔ |
| §3.2「共鸣潮汐」代替昼夜循环 | §6.2 Curve+Gradient 驱动，周期待定（G6） | ✔ |
| §3.3 Glow 高阈值 + 轻微 exposure | §6.1 Tonemap AgX + 高阈值 Glow | ✔ |
| §3.3 / §8.1 全屏特效统一走 CompositorEffect（4.3+） | §6.1 Compositor 栈 4 个效果，统一 `intensity` | ✔ 版本充裕（钉 4.7.1） |
| §4.1 粗糙度/金属度区间表 | §6.3 材质规范表**逐行照搬**美术给定区间 | ✔ |
| §4.3 ORM 打包省采样 | §6.3 导入预设强制 | ✔ |
| §4.3 全项目 Fresnel Rim（hero 强/环境弱） | §6.3 统一 `rim.gdshader` include | ✔ |
| §4.3「避免高频噪点法线，大块明暗」 | 作为 ADR-001 否决 UE5 Nanite/Lumen 的论据；材质规范承接 | ✔ |
| §8 VFX 表 7 项（拖尾/共鸣光效/混沌侵蚀/体积光/i-frame/速度线/天空） | §6.1 Compositor 栈 + GPUParticles3D + Sky Shader 全覆盖 | ✔ |
| §8.1 粒子封顶 + 拖尾 LOD | §7.3 预算表 | ✔ |
| §8.1 慎用 SSR | §6.4 分档策略 | ✔ |
| §9.1 色盲模式（品红替代 + 脉动描边 + 纹理图案） | §9 `color_tokens_cvd.tres` 热切换，**全覆盖无死角** | ✔ |
| §9.2 UI 对比度 ≥4.5:1、字号、150% 缩放 | §附录A `stretch/mode=canvas_items`；交 UX 规格细化 | ✔（部分交 S6） |
| §9.3 抖动/暗角减弱开关、故障强度滑块 | §6.1 Compositor 统一 `intensity` 全局系数，一个开关关掉光敏风险特效 | ✔ |
| §9.4 Standard 分级基线 | ADR-001 核验 4.5 AccessKit + 4.7 地标导航为原生支撑 | ✔ |
| 附录「SDFGI/VolumetricFog/CompositorEffect/GPUParticles3D 均为内置、PC 性能充裕」 | ADR-001 §能力引入版本核验表**逐项证实** | ✔ **已核验成立** |

**判定：与美术圣经渲染项对齐 PASS（语义色 hex 的 CONCERN-A 已裁决闭合，见 §7）。**

**超出预期的正向项**：美术圣经写于 Phase 1，当时不知 4.5–4.7 的新能力。核验后发现三项额外红利已纳入架构——**stencil 描边**（4.5，让 §4.3 的"精美描边"比法线外扩更干净）、**SSR 重写 + 半分辨率**（4.6，直接回应 §8.1"记账"顾虑）、**AreaLight3D**（4.7，让 §4.2 ResonanceMetal 镶边与神龛辉光有真实面光源）。

---

## 7. CONCERN 明细

### CONCERN-A · 语义色 hex 在两份上游文档间冲突 —— **已裁决（2026-08-08）**

**性质**：这不是架构缺陷，是**上游两份已锁定文档之间的既有不一致**，在 Phase 3 工程化时被发现。

**裁决结果**：`design/color-tokens.md` **v1.0 为所有语义色 hex 的唯一权威**，三处差异全部收敛如下表"裁决值"列。

| 语义 | systems-index §2（旧） | art-bible §2 | **裁决值 (v1.0)** | 差异 → 处置 |
|---|---|---|---|---|
| 威胁/混沌 THREAT | `#A62C6B` | `#A62C6B` | `#A62C6B` | ✔ 一致 → 强制锁定，永不变 |
| 共鸣辉光 RESONANCE_GLOW | `#9FF7E8` 青白 | `#5FD2C8` 星辉青 | `#9FF7E8` | ✗ 冲突 → **已裁决**：同名不同义，拆分为基色 `PLAYER_ALLY_MAIN=#5FD2C8` 与自发光态 `RESONANCE_GLOW=#9FF7E8` |
| 友好 teal | ~~`#2BB6A8`~~ | `#5FD2C8` | `#5FD2C8` | ✗ 冲突 → **已裁决**：统一星辉青，`#2BB6A8` 退役 |
| 友好 amber | ~~`#F4B740`~~ | `#F2C15E` | `#F2C15E` | ✗ 冲突 → **已裁决**：统一暖金，`#F4B740` 退役 |
| 友好 coral | `#FF8A65` | 未列 | `#FF8A65` | → canon 化入册 |
| 伤害/警告 DAMAGE_WARN | — | `#E5484D` | `#E5484D` | → 低血/受击专用，**非敌色** |
| UI 底 UI_BG | — | `#1A2233` | `#1A2233` | → 采纳 |

值得注意：`consistency-review.md` §1 将"语义色"一项判为 PASS——该判定对 **THREAT 与"青白 vs 品红严格区分"的语义层面成立**，但**未逐 hex 比对到美术圣经**，故三处数值差异未被发现。这属于跨文档（GDD ↔ 美术圣经）而非跨 GDD 的一致性，落在原评审范围之外，非评审疏漏。

**影响评估**：**低-中**。品红 THREAT（唯一与玩法安全强绑定的颜色，"危险一眼可读")两文档完全一致，**不影响可玩性与色盲安全**。差异集中在友好/共鸣色的具体色值，属视觉调性问题。

**架构侧已做的隔离**：`ColorTokens` 单一资源（`architecture.md` §9）使裁决成本降到最低——**改一个 `.tres` 字段，全项目（材质/Shader/HUD/VFX）同步生效，零代码改动**。该隔离在本次裁决中直接兑现：落地成本 = 按裁决值填 `color_tokens.tres`，无代码改动。

**处置（已执行）**：裁决路径与建议一致 = 林绘澄给出最终 hex（美术圣经为色彩专业来源）→ 产出 `design/color-tokens.md` v1.0 作为唯一权威 → `architecture.md` §9 与本文已同步。**遗留动作**：文策渊将 systems-index §2 同步为 v1.0 值（不阻塞工程，因工程只读 `ColorTokens`）。

**退役禁令**：`#2BB6A8`、`#F4B740` **禁止**作为活值出现在任何资源/代码/Shader/文档中，仅可存在于 `color-tokens.md` §4 退役对照表的历史记录。

**状态**：✅ **已裁决（2026-08-08，color-tokens.md v1.0）**，CONCERN-A 闭合，未阻塞 Phase 4 启动。

---

### CONCERN-B · 输入延迟贴近 S6 红线 —— **需 Phase 4 实测**

**问题**：`architecture.md` §3 为保证 GDD 帧常量的确定性，钉定固定 60 Hz 物理 tick + 物理插值。代价是延迟累加（§7.5 延迟账）：键鼠典型 **~40–50 ms**，而 GDD S6 §⑤ 要求 **<50 ms（键鼠）/ <80 ms（手柄）**。**贴线，无充裕余量。**

**为何仍接受该方案**：替代方案更糟。若改用可变时间步按秒定义窗口，`CANCEL_WINDOW=8f` 将随刷新率漂移，GDD S1 §⑦「取消延迟 ≤8 帧」与 P1「中断率 <5%」**双双失去可验证性**——损失的是支柱级设计目标，代价远大于十几毫秒延迟。

**已排期缓解**（`architecture.md` §7.5）：`set_use_accumulated_input(false)`、Adaptive 垂直同步 + Disabled 选项、双缓冲选项、**≤6 帧输入缓冲**（同时直接服务中断率 <5% 目标）。

**逃生门**：若实测超标 → ①关物理插值（代价：144 Hz 抖动）；②提高 tick 至 120（代价：**需回 GDD 重算全部帧常量**，高成本变更）。

**状态**：🔬 Phase 4 **首个 spike**，240 fps 摄像实测。对应缺口 G2 / 风险 RISK-PERF-1。

---

### CONCERN-C · 性能预算与 S2/S5 顺序张力未经实证 —— **需 Phase 4 验证**

两个子项：

**C-1 性能预算未经实测**：§7 的帧时间与复杂度预算基于工程经验推导，**尚无真机数据**。SDFGI + VolumetricFog 同开在 1660S 级 GPU 上的实际成本存在不确定性，且 ADR-001 已登记 RISK-ENG-1（4.7 对 SDFGI/体积雾无专门更新说明，按 4.3–4.6 行为规划）。
→ **处置**：S0 阶段建渲染冒烟场景 + 3 个固定基准场景，一键脚本输出 CSV 与基线比对（§7.6）。预算超限时优先降 SDFGI 档位与体积雾分辨率（已在 §6.4 分档中预留调节位）。

**C-2 S2↔S5 顺序张力**：DAG 规定 S2 依赖 S5（锚点），但实现顺序 S2 在 S5 之前。GDD 本身即如此（S2 排第 3、S5 排第 5），架构未偏离，但工程上 S2 开发时**尚无真实岛屿**。
→ **处置**：S2 阶段用测试用 blockout 场景（程序化摆放锚点）开发与单测；`grapple_anchor` 接口先行定义，S5 只需按接口摆放。**此为已识别并已缓解的施工顺序问题，不是架构缺陷。**

**状态**：🔬 Phase 4 验证。

---

## 8. GDD 验收标准可测性核查

逐条检查 8 篇 GDD §⑦ 的复选框是否都有工程落点（`architecture.md` §11.2）：

| GDD | 验收标准 | 测试层 | 可测 |
|---|---|---|---|
| S1 | 任意两动词取消延迟 ≤8 帧 | 集成（SceneRunner 逐帧） | ✔ 确定性 |
| S1 | 连段中断率 <5%（20 人） | 人工（交严守真） | ✔ 非自动化 |
| S1 | 完美格触发慢动作 + 硬直 ≥1s | 集成 | ✔ |
| S1 | 共鸣不足终结技不可释放且灰显 | 单元 + 集成 | ✔ |
| S1 | 闪 iframes 期间 0 伤害 | 集成（注入攻击） | ✔ |
| S2 | 可达高点/体积比 ≥0.6 | 工具扫描 | ✔ |
| S2 | ≥1 条纯空中路线 | 工具 + 人工 | ✔ |
| S2 | 跃→闪→斩 ≤8 帧 | 集成 | ✔ |
| S2 | 越界坠落 100% 复活无卡死 | 集成 | ✔ |
| S3 | 池上限严格 100 不溢出 | 单元 | ✔ |
| S3 | 终结技恰扣 40、闸门恰扣 30 | 单元 | ✔ |
| S3 | **池=35 可开门不可终结技** | 单元 | ✔ 互斥核心 |
| S3 | 节点 5s cd 内不二次增益 | 单元 | ✔ |
| S4 | 所有攻击 100% 有 THREAT telegraph + 音效 | 集成（遍历 `.tres`） | ✔ |
| S4 | 完美格 100% 触发破防 ≥1s | 集成 | ✔ |
| S4 | Sentinel 弱点 ≈x2（±5%） | 单元 | ✔ |
| S4 | Boss 阶段切换无即死 | 集成 | ✔ |
| S5 | 每岛可达比 ≥0.6 / 0 死路 / 神龛覆盖 | 工具扫描（每夜 CI） | ✔ |
| S6 | HUD 仅 5 类元素 | 审查清单（控制清单） | ✔ |
| S6 | 共鸣三态色正确 | 单元（阈值）+ 集成 | ✔ |
| S6 | 威胁标记 100% 对应 telegraph | 集成 | ✔ |
| S6 | 键鼠 + 手柄均可完成核心循环 | 人工 | ✔ |
| S7 | 节点 +10 正确 / 计入进度 / 5s cd / 战斗中不卡输入 | 单元 + 集成 | ✔ |
| S8 | 存档读档 100% 还原 / 复活保留收集 / 技能树应用 / 写盘失败不崩 | 单元 | ✔ |

**判定：可测性 PASS。** 覆盖率 100%（自动化 ~85%，其余为必然人工项：中断率玩家测试、输入延迟实测、双设备通关）。

**关键使能因素**：`architecture.md` §3 把「帧」定义为物理 tick，使帧级断言**确定性、不 flaky**；ADR-003 的整数帧计时与之配套。若无此决策，上表中 6 条帧级标准都只能靠录屏人工分析。

---

## 9. 支柱技术支撑核查

| 支柱 | 验证指标（概念文档 §1） | 架构支撑 | 结论 |
|---|---|---|---|
| **P1 流动即正义** | 中断率 <5% | 取消窗**单点实现**（ADR-003）+ 整数帧确定性（§3）+ ≤6 帧输入缓冲（§7.5） | ✔ **PASS**（延迟见 CONCERN-B） |
| **P2 垂直即世界** | 可达比 ≥0.6、≥1 纯空中路线 | ADR-005 确定性移动 + 锚点选择算法；工具自动扫描可达性 | ✔ PASS |
| **P3 精美即叙事** | 无文本推断率 ≥70% | §6 渲染管线全面兑现美术圣经；`AreaLight3D`/stencil 描边额外加分 | ✔ PASS |
| **P4 共鸣统一** | 互斥消耗、无主导策略 | **ADR-002 在架构层强制**：单一数值、无 setter、唯一扣费入口 | ✔ **PASS（最强项）** |

---

## 10. Phase 2 遗留 CONCERN 处置核查

| 遗留项 | 要求 | 架构处置 | 结论 |
|---|---|---|---|
| **CONCERN-1**：Hard telegraph 下限 0.4s 待 Phase 4 A/B | 不在 Phase 3 定死 | ADR-003 §6：telegraph 帧数全部外置到 `EnemyDefinition.tres`（Hard 24–48 帧）。**A/B 调参 = 改数据，不改代码**，甚至可做成运行时可调的调试面板 | ✔ **处置到位** |
| **CONCERN-2**：荡中攻击 / 洗点为 MoSCoW 未覆盖，不擅自纳入 v1 | 不纳入 v1 | **荡中攻击**：ADR-005 备注 + ADR-003 后果——FSM 结构上 `Grapple` 可挂 `Slash` 子状态，**架构预留但 v1 明确不实现**。**洗点**：ADR-004 备注——schema 中 `skill_points` 与 `skills_unlocked` 分离存储，数据结构可支持，**v1 不实现功能** | ✔ **处置到位：预留而不实现，严格守住 MoSCoW** |

**判定：Phase 2 遗留 CONCERN 处置 PASS。** 两项均采用"降低未来变更成本但不扩大 v1 范围"的处理方式，既不擅自纳入，也不让未来纳入变得昂贵。

---

## 11. 待主理人审批项汇总

| # | 事项 | 紧急度 | 阻塞 Phase 4？ |
|---|---|---|---|
| ~~1~~ | ~~**CONCERN-A 语义色 hex 冲突裁决**~~ | — | ✅ **已裁决（2026-08-08）**：`design/color-tokens.md` v1.0 为唯一权威；遗留 systems-index §2 同步交文策渊 |
| ~~2~~ | ~~**G5 Steam Deck 是否列 Should**~~ | — | ✅ **已裁决（2026-08-08）**：**v1 不支持**；画质档下限与 UI 缩放接口**按 Deck 规格预留** |
| ~~3~~ | ~~**G8 lock-on 摄像机是否做**（GDD S1 §⑧开放问题）~~ | — | ✅ **已裁决（2026-08-08）**：**做 lock-on**；Dash 方向解算采用目标相对极坐标解，详见 ADR-003 |
| ~~4~~ | ~~G6 共鸣潮汐周期（交林绘澄/文策渊）~~ | — | ✅ **已收口**：`RESONANCE_TIDE_PERIOD_SEC = 90–120s` |
| 5 | G7 慢动作音频处理（交阮和鸣） | 低 | ❌ |
| 6 | 确认 `CANCEL_WINDOW` 不提供可访问性放宽选项的取舍（交文策渊 UX 规格） | 中 | ❌ |

---

## 12. 结论与放行建议

**总体：PASS（3 CONCERN / 0 FAIL）**

- 架构与 GDD 单一真相源**严格一致**，且通过 `GameConstants` + 单测 + lint 把一致性变成**可执行门禁**，强于被动的"不冲突"。
- 依赖 DAG 与跨系统契约**完全对齐**，未引入反向依赖；S0 地基为必要工程补充，非偏离。
- 与美术圣经渲染项**全部对齐**，且核验证实其"Godot 4 内置、PC 性能充裕"的判断成立，另有三项版本红利（stencil / SSR 重写 / AreaLight3D）纳入。
- P4 支柱获得**架构级强制保障**（ADR-002），这是本次架构最有价值的产出。
- Phase 2 两项遗留 CONCERN 处置得当：预留而不实现，严守 MoSCoW。

**放行建议：批准进入 Phase 4 预制作**，附三个条件：

1. **Phase 4 首个 spike 必须验证 CONCERN-B（输入延迟实测）**——它是唯一可能推翻核心时间基准决策（§3）的风险，越早暴露越便宜；
2. **S0 地基阶段完成后立即建立性能基线**（CONCERN-C），不要等到内容堆起来才测；
3. ~~**G8（lock-on）建议在 Phase 4 早期拍板**，避免相机架构返工。~~ ✅ **已于 2026-08-08 拍板：做 lock-on**——`CameraRig` 需从一开始含目标锁定层，Dash 方向语义见 ADR-003。避免返工的目的已达成。

CONCERN-A 已于 2026-08-08 裁决闭合（`design/color-tokens.md` v1.0 为唯一权威），未阻塞开工。

