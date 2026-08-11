# S10 机甲美术 · 资产生产交接单（Handoff Package）

> **文档状态**：v0.1 · 2026-08-11 · 主理人游承峰汇编
> **上游来源**（专业判断归各成员，本单为汇编 + 艺术家可直接消费的交接包）：
> - 美术圣经 `design/art/mecha-art-bible.md`（林绘澄 / art-director，v0.1）
> - 生产管线 `production/s10-mecha-pipeline.md`（程基岩 / engineering-lead，v0.1）
> - 语义色 `design/color-tokens.md`（文策渊 / design-strategist，v1.2）
> - 程序化占位 `game/src/art/character_model.gd`（程基岩，运行时盒装机甲，当前在构建中可见）

---

## §0 主理人编排说明（这份交接单是干什么的）

用户选择「主理人安排内部/外包 3D 美术」。在本工作室编排模型下，这意味着：

1. **主理人（已做）**：产出这份**可直接消费的资产生产交接单**——把美术圣经的视觉/规格语言、管线文档的骨骼/集成约束，转译成一位 3D 美术（内部同事或外包 contractor）**开工即用的交付清单、契约与验收标准**。
2. **3D 美术（人力层）**：按本单 + 上游三份文档产出 GLB/动画/VFX 资源。A 层机身蒙皮与整套动画集**必须人力**（混元 3D 等 AI 生成件零骨架、默认 50 万面、拓扑非 quad-flow，**不能直接重定向**，见管线 §1）。B 层刚性附件可由 AI 生成后人工 decimate 挂 `BoneAttachment3D`。
3. **无缝替换（已留缝）**：当前构建用 `character_model.gd` 程序化盒装机甲占位（已验证，8 台零错）。真资源到位后仅改 `arena_min.gd:391` 的装配点 + 填 `CharacterDefinition.art_ref`，**无 `art_ref` 时自动回落占位**（gacha §6.1 feature-flag 纪律），集成零风险。

> 本单不重复上游文档的设计论证，只给「做什么 / 交什么 / 怎么验 / 怎么接」。需要原理时回上游文档对应小节。

---

## §1 交付物总清单（Manifest）

| # | 交付物 | 类型 | 数量 | 来源 | 备注 |
|---|---|---|---|---|---|
| D1 | `skel_mech_shared.tscn` | 骨骼契约基准 | 1 | 人力（一次性） | 52-bone 人形 biped，命名冻结（§2） |
| D2 | 职阶 chassis 蒙皮 mesh | skinned mesh | 4（BLADE/BULWARK/WINDCHASER/RESONANT） | 人力 | 4 套蒙到同一副 D1 骨骼，仅体积差 |
| D3 | `chr_<job>_<id>.tscn` | 角色变体场景 | 8 | 装配 | D2 chassis + 附件 + AnimationTree 引用（§3 映射） |
| D4 | `anim_shared.res`（AnimationLibrary） | 动画集 | 12 clip | 人力（手 auth 推荐） | 与角色解耦，8 台共用（§4） |
| D5 | `anim_shared_tree.tres` | AnimationTree 模板 | 1 | 工程 | 全 manual，禁止自动转移 |
| D6 | 刚性附件 GLB（刃/盾/核/杖/翼/环/发束/肩甲） | rigid mesh | ~12 | **可 AI 生成** | 挂 `BoneAttachment3D`，零蒙皮（§6） |
| D7 | 技能 VFX（谐波虹膜青白母体） | shader/粒子 | 按圣经 §6 | 美术 | 终结技/开门/共鸣/召唤同源；敌方锁 THREAT（§5） |
| D8 | `mech_animator.gd` | 表现层脚本 | 1 | 工程（程基岩） | 订阅 `EventBus.player_state_entered`，非状态机（§8） |
| D9 | `test_skel_contract.gd` | CI 强校验 | 1 | 工程 | 骨骼漂移/动画 track 断言（§7） |

> **8 台角色 id**（来自 `gacha_catalog.gd` / `character_model.gd._spec_for`）：
> `ash_acolyte`(BLADE) · `voidblade_lord`(BLADE) · `oath_guard`(BULWARK) · `bulwark_heart`(BULWARK) · `swift_ranger`(WINDCHASER) · `gale_echo`(WINDCHASER) · `resonant_hierophant`(RESONANT) · `resonant_singer`(RESONANT)

---

## §2 共享骨骼契约 `skel_mech_shared`（冻结，52 bones）

Humanoid-biped 命名，确保 Godot 4 `SkeletonProfileHumanoid` 可识别、外部动画可映射。**命名/层级/数量冻结后不得增删改名**（CI 强校验，管线 §5.6）。

```
root                          # 总根（场景根 Node3D，非骨骼）
└─ hips (Hips)
   ├─ spine (Spine)
   │  ├─ chest (Chest)                  # 核心舱挂载父
   │  │  ├─ neck (Neck)
   │  │  │  └─ head (Head)
   │  │  │     └─ head_tip (HeadTip)    # 额心/头饰挂点
   │  │  ├─ shoulder_L → upper_arm_L → lower_arm_L → hand_L → weapon_mount_L
   │  │  ├─ shoulder_R → upper_arm_R → lower_arm_R → hand_R → weapon_mount_R
   │  │  ├─ core (Core)                 # 共鸣核心 housing（空骨）
   │  │  ├─ wing_L (LeftWing)           # 非风追角色隐藏
   │  │  ├─ wing_R (RightWing)
   │  │  └─ thruster_back (ThrusterBack)
   │  ├─ upper_leg_L → lower_leg_L → foot_L
   │  └─ upper_leg_R → lower_leg_R → foot_R
```

**冻结纪律（硬约束）**：
- 8 台 + 4 套 chassis 的 **rest pose（骨骼 local transform）逐骨一致**。
- 职阶剪影差异**只通过 mesh 体积**实现，**禁止缩放骨骼长**（否则 FK 动画脚离地/插地）。
- 附件（翼/盾/核/杖/发束/肩甲）一律 `BoneAttachment3D` 挂到 `wing_L/R`/`weapon_mount_L/R`/`core`/`thruster_back`/`head_tip`，**骨骼数恒定 52**，永不因角色增减。

---

## §3 八台机甲 → 骨骼/附件映射 + 强调色

强调色（accent）**全部取自 `design/color-tokens.md` v1.2 友方族**，零新增语义色、零 THREAT 越界。精确 hex 以该文档为唯一真相源。

| id | 职阶 chassis | accent token | 挂附件（其余隐藏） |
|---|---|---|---|
| `ash_acolyte` | BLADE | `FRIENDLY_GOLD` | `weapon_mount_R`→细长单手刃；`head_tip`→微弱节点 |
| `voidblade_lord` | BLADE | `FRIENDLY_GOLD`(×0.8) | `weapon_mount_L/R`→双交叉巨剑；非对称肩甲挂 `shoulder_L` |
| `oath_guard` | BULWARK | `SKY_AZURE` | `weapon_mount_L`→塔盾(盾面锁纹章)；`shoulder_L/R`重甲 |
| `bulwark_heart` | BULWARK | `SKY_AZURE` | `core`→双球心核；`weapon_mount_L`→短盾 |
| `swift_ranger` | WINDCHASER | `FRIENDLY_CORAL` | `wing_L/R`显(实体羽翼)；`weapon_mount_R`→长枪 |
| `gale_echo` | WINDCHASER | `FRIENDLY_CORAL` | `wing_L/R`显(半透明发光)；`head_tip`→头环 |
| `resonant_hierophant` | RESONANT | `RESONANCE_GLOW` | `head_tip`→大头光环；`weapon_mount_R`→环杖；`core`→胸核心 |
| `resonant_singer` | RESONANT | `RESONANCE_GLOW` | `core`→球核；`head_tip`→发束头饰 |

> 同职阶两台 = 同一 chassis + 不同附件组合 + 不同 accent 色。**零额外蒙皮**。

**材质/配色系统**（引用 color-tokens v1.2）：
- chassis 基色 = `MECH_BASE`(#2A3140 深岩灰)；暗部 = `MECH_BASE`×0.55
- 阵营共鸣回路（胸/双肩发光条）= `PLAYER_ALLY_MAIN`（青白 emissive）
- accent 识别件 = 上表 token
- 敌方 telegraph 锁 `THREAT`(#A62C6B)，**玩家/友方模型一律不引用**

---

## §4 动画集清单（12 clip · 覆盖 FSM 全态，含 O9 补件）

动画 = 战斗 FSM 的**从属订阅者**，由 `EventBus.player_state_entered(state_name)` 驱动（架构纪律，管线 §4.3）。`AnimationTree` 全 `MANUAL`，只有 `travel()` 推进，与 FSM 1:1。**禁 root motion**，位移由 FSM/`arena_min` 权威；动画 method-call track 只许调 `AudioDirector.play_event()`，绝不改窗口常量或触发伤害。

| FSM 态 | clip | 帧数建议 | 状态 |
|---|---|---|---|
| Idle | `anim_idle` | loop | ✅ 圣经已列 |
| Run | `anim_run` | loop | ✅ 圣经已列 |
| Slash(BLADE) | `anim_slash_blade` | 命中帧对齐 CANCEL=8 | ✅ 圣经已列(attack×4) |
| Slash(BULWARK) | `anim_slash_bulwark` | 同上 | ✅ |
| Slash(WINDCHASER) | `anim_slash_windchaser` | 同上 | ✅ |
| Slash(RESONANT) | `anim_slash_resonant` | 同上 | ✅ |
| Grapple | `anim_grapple` | 一次 | ✅ 圣经已列 |
| Resonate/Finisher | `anim_finisher` | 谐波虹膜青白母体 + 职阶叠加 | ✅ 圣经已列 |
| Hitstun | `anim_hit` | 一次 | ✅ 圣经已列 |
| **Dash** | `anim_dash` | 对齐 DASH=12 | ⚠ **O9 补件（圣经原标可选→升必做）** |
| **Leap** | `anim_leap` | 一次 | ⚠ **O9 补件（P2 垂直核心支柱，升必做）** |
| **Parry** | `anim_parry` | 对齐 PARRY=6 + 300ms 慢动作 | 🔴 **O9 必做（FSM 有 Parry 态，无动画则完美格无视觉落点）** |

> 汇总 = 12 条轨道（Slash 算 4 条职阶变体）。美术圣经 §5.4 原承诺 8 条，**净缺 Dash/Leap/Parry 三条已由本单升为必做（O9 已裁决：补）**。

---

## §5 技能 VFX 交接（谐波虹膜 / THREAT 锁）

- **母体 = 谐波虹膜（青白）**：终结技 / 开门 / 共鸣 / 召唤 **同源**视觉语言（圣经 §6），由 `audio_director` 事件驱动，与 `anim_finisher` 同步。
- **敌方 telegraph 锁 `THREAT`(#A62C6B)**：由 `vfx_telegraph_threat` 呈现，玩家/友方模型与 VFX **绝不**使用该色（防语义越界，CI 可加断言）。
- 发光强度：本项目 **Physical Light Units 未开**，不可设 `emission_intensity`；统一用 `emissive` 颜色亮度调制，封顶防 bloom 过曝（占位脚本 `character_model.gd._process` 已验证该模式）。

---

## §6 刚性附件（B 层 · 可 AI 生成）

- 翼/盾/核/杖/环/发束/肩甲 = 仅 Mesh、**无骨骼**，作为 `BoneAttachment3D` 子节点挂到 §2 挂载骨。
- 可由混元 3D 等生成原型 → 人工 decimate 到预算 + 转 quad-flow → 挂点。生成件**不蒙皮**，故零 retarget 风险。
- 非本角色附件：`BoneAttachment3D.visible=false`，不另建骨骼。

---

## §7 导出与验收标准

- 格式：GLB → Godot 导入为 `.tscn`/`.res`；quad-flow 拓扑；LOD0 单台 ≤22k 三角（8 台 hub ≈113MB << 2.5GB 预算，管线 §3）。
- 命名：chassis `chr_<job>_chassis.tscn`；变体 `chr_<job>_<id>.tscn`；附件 `att_<name>.glb`。
- **CI 强校验（`test_skel_contract.gd`）**：
  - [ ] 8 个 `chr_*.glb` 的 `Skeleton3D` bone 名集合 / 父子层级 / 数量 == `skel_mech_shared.tscn` 基准（防骨骼漂移）
  - [ ] 共享 `AnimationLibrary` 的 track path 在 8 场景均可解析（防 NodePath 不一致导致动画错位）
  - [ ] `THREAT` 不在任何玩家/友方资源被引用

---

## §8 Godot 集成缝（替换占位，零回归）

1. `CharacterDefinition.art_ref`（`game/src/gacha/character_definition.gd:21`，现空串）填对应 `chr_<job>_<id>.tscn` 路径。
2. `arena_min.gd:391` `_model = CharacterModel.new()` → 改为按 `character_id` `load(art_ref).instantiate()`；`art_ref` 为空时回落 `CharacterModel.new()`（保留占位）。
3. 新增 `game/src/art/mech_animator.gd`（`class_name MechAnimator extends Node`，表现层）：`_ready` 连 `EventBus.player_state_entered` → `_on_state(name)` 调 `animation_tree.travel(_state_to_clip(name))`；`AnimationTree.advance_mode=MANUAL`；`callback_mode_process=PHYSICS` 对齐 60Hz。
4. `PlayerCombat` **零改动**（只广播态名）；移除占位时仅删 `CharacterModel` 引用，保留作 fallback。
5. 敌人（混沌造物）走 `enemy_*` 信号 + 独立 `AnimationTree`，不在本动画集范围。

---

## §9 给内部/外包 3D 美术的对接流程与里程碑

- **里程碑 M1（契约）**：建 `skel_mech_shared.tscn` + `test_skel_contract.gd`（CI 先行），冻结 52-bone。→ 主理人/工程验收后进入 M2。
- **里程碑 M2（机身）**：4 套 chassis 蒙皮到 M1 骨骼，rest pose 一致。→ 验收后 M3。
- **里程碑 M3（动画）**：12 clip（§4，含 O9 三件）手 auth，导出共享 `AnimationLibrary`。→ 验收后 M4。
- **里程碑 M4（附件+VFX）**：刚性附件 GLB + 谐波虹膜 VFX；`chr_<job>_<id>.tscn` 装配。→ 集成 M5。
- **里程碑 M5（集成）**：填 `art_ref` + 改 `arena_min.gd:391` + `mech_animator.gd`；全量单测 + 冒烟通过后替换占位。
- **对接入口**：设计疑问→`mecha-art-bible.md`；骨骼/集成/CI 疑问→`s10-mecha-pipeline.md`；配色精确值→`color-tokens.md` v1.2。

---

## §10 已知风险（已在本单裁决/缓解）

| 风险 | 等级 | 处置 |
|---|---|---|
| 动画缺口 Dash/Parry/Leap | 🔴 高 | O9 已裁决「补」，升必做（§4） |
| 4 套 chassis 蒙皮 + 动画集需人力 | 🟠 中 | 用户授权主理人安排内部/外包（本单即交接包）；占位 `character_model.gd` 兜底 |
| 骨骼 rest pose 漂移（8 台不一致→脚离地） | 🟠 中 | §2 冻结纪律 + §7 CI 强校验 |
| AI 生成件不可重定向 | 🟠 中 | A 层人力蒙皮；B 层附件可 AI + BoneAttachment 零蒙皮 |
| THREAT 语义越界 | 🟡 低 | §5 锁色 + §7 CI 断言 |
