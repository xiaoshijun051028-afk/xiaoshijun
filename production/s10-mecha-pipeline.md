# S10 机甲美术 · 生产管线与技术方案（O3 关键生产门）

> **文档类型**：技术管线方案（仅产出文档，不改代码/场景）
> **任务**：O3 — 8 台机甲 GLB 怎么产出 + 如何满足「共享骨骼 `skel_mech_shared` 重定向」硬约束
> **作者**：程基岩（engineering-lead / 主程序）
> **引擎 / 平台**：Godot 4.7.1-stable（Forward+，D3D12 / Vulkan 回退）· PC / Steam
> **上游权威**：`design/art/mecha-art-bible.md` v0.1（§5/§8）、`design/art/asset-spec.md` v1.0（§2.1）、`design/gdd/systems/gacha.md`（§2/§5/§6/§8）、`game/src/core/color_tokens.gd`（语义色唯一真相源）、`game/src/art/character_model.gd`（现行占位实现）
> **版本**：v0.1
> **纪律**：本文档只做技术方案与管线设计，不雕刻最终模型、不改玩法数值、不写游戏代码。所有落地动作列入 §6 待主理人/用户拍板项。

---

## §0 现状核查（先对齐事实，再给方案）

落地前先把"现在是什么样"查清楚，避免方案悬空：

| 核查项 | 现状（已用 Read/Grep 确认） | 对方案的含义 |
|---|---|---|
| 占位模型 | `game/src/art/character_model.gd`（`CharacterModel extends Node3D`）**运行时用基础图元拼装**，无 GLB、无 `.tscn`、无 `Skeleton3D`/`AnimationPlayer` | 8 台机甲 GLB **是全新资产**，不是"替换现有场景文件"——现有 `scenes/player/` 是空的，模型是代码 `new()` 出来的 |
| 装配点 | `game/src/gameplay/arena_min.gd`：`_rig/Model = CharacterModel.new()`，`_enemy/Model = EnemyModel.new()`；`_model.build(character_id)` | 替换点已明确：`build()` 改为实例化 `chr_<job>_<id>.tscn`（见 §5.3） |
| 战斗 FSM 状态名闭集 | `PlayerCombat` 8 态：`Idle / Slash / Dash / Grapple / Leap / Parry / Resonate / Hitstun`（`player_combat.gd` 顶部常量） | **动画集必须覆盖 8 态**，但美术圣经 §5.4 只列了 5 套（idle/run/attack×4/finisher/hit）——存在 **4 套缺口**（见 §4.4 / §6 O9） |
| 动画驱动信号 | `EventBus.player_state_entered(state_name: StringName)` 已存在，且 `AudioDirector`/`DebugOverlay` 已订阅（过去式事实信号，符合 CLAUDE.md 全局纪律） | 动画系统 = 表现层 **从属订阅者**，由该信号驱动，绝不自持状态机（见 §4.3） |
| 语义色真相源 | **`game/src/core/color_tokens.gd`**（const 段，静态可访问）；不是美术圣经 §5.7 写的 `resources/colors/color_tokens.tres` | 路径以代码为准；`INACTIVE`、`GATE_READY` 已有临时 const 值，O1 在代码侧已部分收口（见 §5.4） |
| 敌方 | `EnemyCombat` 6 态（Idle/Telegraph/Attack/Recover/Stagger/Dead），**不广播** `player_state_entered`（架构纪律：敌人走 `enemy_*` 信号） | 敌方机甲（混沌造物）走独立 AnimationTree，不共享本方案动画集；telegraph 锁 `THREAT` 由 §5.4 纪律保证 |
| 资产预算红线 | `asset-spec.md §2.1`：骨骼同屏≤12 / 三角≤2M / 显存≤2.5GB / 唯一材质≤120 / 粒子≤30k | 1 台出战机甲全部落在红线下且有余量（见 §5.5 勾稽） |

> ⚠ **路径修正**：美术圣经 §5.7 把语义色调色板写成 `resources/colors/color_tokens.tres` + `color_tokens_cvd.tres`，但代码实装是 `game/src/core/color_tokens.gd`（const + `@export` 双形态）。本文档后续一律引用**代码实装路径**，避免落地时找不到文件。

---

## §1 推荐生产方法（O3 核心裁决）

### 1.1 本机可用的 3D 生成能力

本工作环境内装的 3D 生成能力 = **腾讯混元 3D（Hunyuan 3D）**（`buddy-multimodal-generation` skill 的 `buddy-cloud.py 3d`）。能力边界（已读 SKILL.md 确认）：

| 能力 | 输出 | 与本约束的关系 |
|---|---|---|
| 文生 3D / 图生 3D | `.glb` / `.obj`（默认 50 万面，`--face-count` 1万–150万，可 LowPoly/白模）| **输出是静态网格，无骨骼、无 skin、无 UV atlas 控制、无骨骼名** |
| PBR 材质 | `--enable-pbr` | 生成一套贴图，但**不绑定到 `skel_mech_shared` 的规范 UV / 语义通道** |
| 额外格式 | STL / USDZ / FBX | 同上，皆无 rig |

### 1.2 结论（能 / 不能 + 理由 + 风险）

> **结论：混元 3D【不能】直接产出「可重定向到 `skel_mech_shared` 的机甲原型」。**
> 根因不是"重定向算法不够"，而是**生成件根本不带骨架**：重定向（retarget）的前提是源与目标**两边都有骨骼**；混元输出是零骨骼静态 mesh，缺的是"上骨架 + 蒙皮 + 骨骼名对齐"这一步，这一步当前没有自动工具。

- **理由**：
  1. 混元输出无 `Skeleton3D`、无权重、无骨骼名 → 无法被 Godot `Skeleton3D`/`BoneMap` 识别为可重定向资源。
  2. 默认 50 万面 ≫ 8 台机甲单台 LOD0 18–22k 三角预算（超 ~25×），拓扑为 isosurface 非流形/非 quad-flow，直接进引擎会爆预算且无法干净蒙皮。
  3. 姿态不可控（生成中性站姿，但关节朝向/比例不可指定），无法保证与 `skel_mech_shared` 的 rest pose 一致。

- **风险（若强行拿生成件当最终资产）**：
  - 必炸预算（50 万面 vs 22k）；
  - 无法装配到共享骨骼（无 bone）；
  - 原创性红线（§7 V-fin/mono-eye 等）无法靠生成约束 100% 守住，需人工审。

### 1.3 推荐路径（混合管线，把 AI 生成用在"能用的地方"）

把 8 台机甲拆成**三部分**，只有一部分需要重人力：

```
┌─ A. 共享 chassis 本体（skinned，上 skel_mech_shared）── 重人力 / 不可 AI ──┐
│   提案：按 4 职阶各 1 套 chassis（BLADE/BULWARK/WINDCHASER/RESONANT），共 4 套│
│   都蒙到【同一副冻结骨骼】，仅 mesh 体积差异（不缩放骨骼长）            │
└────────────────────────────────────────────────────────────────────────┘
        │ 差异只靠：
┌─ B. 刚性附件（rigid，BoneAttachment3D 挂骨骼挂载点，无需蒙皮）────────────┐
│   提案：刀/盾/翼/环/杖/核/发束/肩甲 —— 这部分【可用混元 3D 生成】做原型 │
│   → 人工 decimate 到 4–8k 面 + 轻量清理 UV + 挂 bone_mount → 零蒙皮成本  │
└────────────────────────────────────────────────────────────────────────┘
        │ 差异只靠：
┌─ C. 材质 / 配色（shader 参数，非换主色）────────────────────────────────┐
│   1 套 MechBase 母材 + 4 套 accent（职阶）→ 用 per-instance shader 参数换色 │
│   见 §3.4 / §5.4。零建模成本，满足 O6「不分档」省 4× 成本              │
└────────────────────────────────────────────────────────────────────────┘
```

**为什么这样能压住 R1（P3 生产成本）这个最大风险**：

- 美术圣经 §5.1 说"8 台共用同一骨架"——但若 8 台是 8 个独立完整 mesh，每台的腿/腰/核心/肩都要分别建模+蒙皮，工作量 ≈ 8 倍。
- 我的提案：**蒙皮只发生 4 次（每职阶 1 套 chassis）**。同职阶两台（如两 BLADE：灰烬学徒 vs 断空剑主）的差异 100% 落在【附件 B】+【配色 C】上，不新增蒙皮。
- 附件 B 可用混元 3D 生成原型（刀/翼/盾是刚性件，生成质量可接受，且天然原创），人工只做 decimate + UV 清理 + 挂点，单件成本远低于完整角色。
- **结论：8 台机甲的"重人力"被收敛到「4 套 chassis 蒙皮 + 1 套动画集」**，这正是 R1 唯一结构解的工程落地形态。

### 1.4 生产方法决策表（交主理人拍板，见 §6）

| 选项 | 内容 | 成本 | 我的推荐 |
|---|---|---|---|
| **A（推荐）** | 混合：4 套手蒙 chassis（按职阶）+ AI 生成的刚性附件 + shader 换色；动画集手 authored（Mixamo 仅作 blockout 参考） | 中等，Solo 可承受 | ✅ |
| B | 全手工：8 台各自完整建模蒙皮 | 极高，R1 风险引爆 | ❌ |
| C | 全 AI：8 台全用混元生成后强行蒙皮 | 看似低实则崩（无 rig + 超面数 + 改不了骨名） | ❌ 不可行 |

---

## §2 共享骨骼规格 + 重定向方案（硬约束落地）

### 2.1 关键澄清：「重定向」在本项目里不是运行时动作

- **运行时无 retarget**：8 台机甲用的是**同一副冻结骨骼**（同名、同层级、同 rest pose），只换 mesh 外壳。所以不是"8 套骨骼互相重定向"，而是"**8 套 mesh 都蒙到同一套骨骼定义上**"——一次 authoring-time 绑定，运行时零成本。
- "重定向"真正发生的两处（都是**一次性 authoring / 资产准备**动作，不是每帧）：
  1. **动画来源 → `skel_mech_shared`**：若动画来自 Mixamo 等外部源（Humanoid 骨骼），用 Godot `SkeletonProfileHumanoid` + `BoneMap` 一次性把外部 clip 重映射到本骨架（rest pose 归一到 canonical）。
  2. **附件 mesh → bone_mount**：用 `BoneAttachment3D`（一次性挂，运行时只是显隐）。

### 2.2 `skel_mech_shared` 骨骼层级（冻结，48–56 bones）

采用 **Humanoid-biped** 命名，确保 Godot 4 的 `SkeletonProfileHumanoid` 可识别、外部动画可映射。数量取美术圣经 §5.1 的 **52 bones**（落在 48–56 区间，命名冻结后不得增删/改名）：

```
root                          # 总根（非骨骼，场景根 Node3D）
└─ hips (Hips)                # 根骨
   ├─ spine (Spine)           # 脊柱 1
   │  ├─ chest (Chest)        # 胸（核心舱挂载父）
   │  │  ├─ neck (Neck)
   │  │  │  └─ head (Head)
   │  │  │     └─ head_tip (HeadTip)        # 额心节点挂点
   │  │  ├─ shoulder_L (LeftShoulder)
   │  │  │  └─ upper_arm_L (LeftUpperArm)
   │  │  │     └─ lower_arm_L (LeftLowerArm)
   │  │  │        └─ hand_L (LeftHand)
   │  │  │           └─ weapon_mount_L (LeftWeaponMount)   # 武器挂点
   │  │  ├─ shoulder_R (RightShoulder)
   │  │  │  └─ upper_arm_R (RightUpperArm)
   │  │  │     └─ lower_arm_R (RightLowerArm)
   │  │  │        └─ hand_R (RightHand)
   │  │  │           └─ weapon_mount_R (RightWeaponMount)
   │  │  ├─ core (Core)              # 空骨：共鸣核心 housing（§3 识别件）
   │  │  ├─ wing_L (LeftWing)        # 背骨 child of chest；非风追角色隐藏
   │  │  ├─ wing_R (RightWing)
   │  │  └─ thruster_back (ThrusterBack)   # 背部推进器挂点
   │  ├─ upper_leg_L (LeftUpperLeg)
   │  │  └─ lower_leg_L (LeftLowerLeg)
   │  │     └─ foot_L (LeftFoot)
   │  └─ upper_leg_R (RightUpperLeg)
   │     └─ lower_leg_R (RightLowerLeg)
   │        └─ foot_R (RightFoot)
```

**冻结纪律（CI 强校验，见 §5.6）**：
- 上述 52 个 bone 名 + 父子关系 = **canonical 契约**。任何机甲 GLB 的 `Skeleton3D` 必须逐字匹配（名 + 层级 + 数量）。
- **rest pose 冻结**：所有 8 台 + 4 套 chassis 的 rest pose（骨骼 local transform）必须**逐骨一致**。职阶剪影差异**只通过 mesh 体积**实现，**禁止缩放骨骼长**（否则脚会离地/插地，因为动画是 FK 无 IK）。
- **附件差异不进骨骼**：翼/盾/核/杖/发束/肩甲全部是 `BoneAttachment3D` 子节点挂到上述挂载骨（`wing_L/R`、`weapon_mount_L/R`、`core`、`thruster_back`、`head_tip`），骨骼数恒定 52，永不因角色增减。

### 2.3 8 角色 → 骨骼的映射（谁隐藏/挂什么）

| id | 职阶 | chassis（蒙皮） | 挂附件（BoneAttachment，其余隐藏） |
|---|---|---|---|
| `ash_acolyte` | BLADE | BLADE | `weapon_mount_R` → 细长单手刃；`head_tip` → 微弱节点 |
| `voidblade_lord` | BLADE | BLADE | `weapon_mount_L/R` → 双交叉巨剑；非对称肩甲挂 `shoulder_L` |
| `oath_guard` | BULWARK | BULWARK | `weapon_mount_L` → 塔盾（盾面锁纹章）；`shoulder_L/R` 重甲 |
| `bulwark_heart` | BULWARK | BULWARK | `core` → 双球心核；`weapon_mount_L` → 短盾 |
| `swift_ranger` | WINDCHASER | WINDCHASER | `wing_L/R` 显（实体羽翼）；`weapon_mount_R` → 长枪 |
| `gale_echo` | WINDCHASER | WINDCHASER | `wing_L/R` 显（半透明发光）；`head_tip` → 头环 |
| `resonant_hierophant` | RESONANT | RESONANT | `head_tip` → 大头光环；`weapon_mount_R` → 环杖；`core` → 胸核心 |
| `resonant_singer` | RESONANT | RESONANT | `core` → 球核；`head_tip` → 发束头饰 |

> 同职阶两台 = 同一 chassis + 不同附件组合 + 不同 accent 色。零额外蒙皮。

### 2.4 重定向（retarget）操作步骤（authoring-time）

**步骤 A — 建立 canonical 骨骼（一次性）**
1. 在 DCC（Blender）按 §2.2 建 52-bone 人形 biped，命名严格一致，T-pose / A-pose rest。
2. 导出 `skel_mech_shared.glb`（仅骨架，或含一个中性 chassis 作绑定参考）。
3. 在 Godot 导入为 `res://game/art/models/mecha/shared/skel_mech_shared.tscn`，作为骨骼契约基准。

**步骤 B — 每套 chassis 蒙皮到 canonical（4 次）**
1. 把 BLADE/BULWARK/WINDCHASER/RESONANT 四套 chassis mesh 分别 bind 到同一 `skel_mech_shared`（同名 bone，自动对齐）。
2. 导出各 `chr_<job>_base_lod0.glb`，导入 Godot 时**保留骨骼名**（GLB 导入预设："Mesh → Skin → Use Named Skin" / 不重映射）。

**步骤 C — 动画来源重定向到 canonical（若用 Mixamo 等外部源）**
1. 导入外部 GLB → 建 `BoneMap` 资源，选 `SkeletonProfileHumanoid`，把外部 bone 映射到 §2.2 的 canonical 名。
2. Godot 4 重定形会在导入时把位置/旋转 track 归一化到 canonical rest（"Retarget" / "Fix Silence.../Rest Fixer" 导入选项，**Godot 4.7 具体开关名待验证，见 §0 知识缺口 K1**）。
3. 导出为共享 `AnimationLibrary`（`res://game/art/anim/mecha/anim_shared.res`），与具体角色解耦。
4. **若直接手 authored 动画（推荐，见 §4.4）**：在 canonical 骨架上直接 K 帧，跳过 C1–C3。

**步骤 D — 附件生成 + 挂载（可用 AI）**
1. 混元 3D 生成刀/盾/翼/环/杖/核/发束原型 → 人工 decimate（4–8k 面）+ 清理 UV。
2. 在 Blender 对齐到对应 `bone_mount` 的局部空间 → 导出小 GLB。
3. Godot 里用 `BoneAttachment3D`（parent = 对应骨）挂入，运行时按角色显隐（§4.2）。

### 2.5 AnimationTree 如何复用同一套 clip

- **关键约束**：共享 `AnimationLibrary` 能驱动所有 8 台的前提 = **从 AnimationTree 根到 `Skeleton3D` 的 NodePath 在所有变体场景里完全一致** + **bone 名完全一致**。
- 实现：`chr_<job>_<id>.tscn` 顶节点下，`Skeleton3D` 一律位于约定相对路径（如 `Model/Skeleton3D`），bone 轨道 path 才能跨场景通用。
- 单份 `AnimationLibrary` 赋值给 8 个 `AnimationTree`（每角色一份 tree 引用同一 lib），动画数据**只存一份**，内存/磁盘最小。
- CI 强校验（§5.6）：扫描 8 个 GLB 断言 bone 名/层级一致 + 断言 track path 命中 canonical，防"骨骼漂移"导致某台机甲动画错位。

---

## §3 资源结构 / 目录 / 命名（对齐 asset-spec §3，修正路径）

### 3.1 目录（落到 `game/` 下，与现有 `src/art`、`resources/colors` 一致）

```
res://game/
├── art/
│   ├── models/mecha/
│   │   ├── shared/skel_mech_shared.tscn          # canonical 骨骼契约
│   │   ├── chassis/  chr_blade_base_lod0.glb … chr_resonant_base_lod0.glb   # 4 套蒙皮 chassis
│   │   └── characters/ chr_blade_ash_acolyte_lod0.glb … chr_resonant_singer_lod0.glb  # 8 台（chassis+附件引用）
│   ├── attachments/  att_blade_sword.glb / att_bulwark_towershield.glb …   # 刚性附件（可 AI 生成）
│   ├── anim/mecha/   anim_shared.res (AnimationLibrary) + anim_shared_tree.tres (AnimationTree 模板)
│   ├── materials/mecha/  mat_mechbase.tres + mat_mech_accent_<job>.tres (4)
│   └── textures/mecha/   tex_<id>_albedo.png … (外部 PNG，不走 GLB 内嵌，便于压缩控制)
├── resources/colors/color_tokens.gd              # 语义色唯一真相源（已是代码，非 .tres）
└── src/art/  mech_animator.gd (新增，表现层订阅者) + character_model.gd (保留作 fallback)
```

### 3.2 命名规范（沿用 asset-spec §3.2 `{cat}_{name}_{var}_{lod}.{ext}`）

- 模型：`chr_blade_ash_acolyte_lod0.glb` … `chr_resonant_singer_lod0.glb`
- chassis：`chr_blade_base_lod0.glb`（4 套）
- 附件：`att_<job>_<part>_lod0.glb`（如 `att_windchaser_wing_lod0.glb`）
- 材质：`mat_mechbase.tres`、`mat_mech_accent_blade.tres` / `_bulwark` / `_windchaser` / `_resonant`
- 动画：`anim_idle` / `anim_run` / `anim_slash_blade` … / `anim_dash` / `anim_parry` / `anim_leap` / `anim_grapple` / `anim_hit` / `anim_finisher`
- VFX（后续 S10 另一文档）：`vfx_resonance_iris` / `vfx_slash_<job>` / `vfx_telegraph_threat`

### 3.3 语义色纪律（铁律，lint 可拦）

- 全部引用 `ColorTokens.*` 常量（`game/src/core/color_tokens.gd`），**禁 hex 字面量**（被 `tools/lint/lint_hex_literals.gd` 拦）。
- **敌方 telegraph 锁 `THREAT`**（`ColorTokens.THREAT`，品红不可变）；任何机甲（玩家/友方）**不得**引用 `THREAT`。
- 职阶 accent：`BLADE→FRIENDLY_GOLD` / `BULWARK→SKY_AZURE` / `WINDCHASER→FRIENDLY_CORAL` / `RESONANT→RESONANCE_GLOW`；阵营结构色 `PLAYER_ALLY_MAIN`。
- `MECH_BASE`（机甲 chassis albedo `#2A3140`）是**材质 albedo 值**，非语义 Token；按 CLAUDE.md 单一真相源纪律，应在 `mat_mechbase.tres` 里写为 `Color(0.165,0.192,0.251)` 并由 lint 豁免，或在 `color_tokens.gd` 补 `MECH_BASE` const——**建议后者**（O1 收口，避免散落 hex）。

### 3.4 配色靠 shader 参数，不靠 4× 建模（O6 决策建议）

- 1 套 `MechBase` 母材（深岩灰 chassis + 青白共鸣回路 emissive）+ 4 套 accent 材质（职阶强调色）。
- **同角色 N/R/SR/SSR 四档视觉不分档**（O6 建议不分）：稀有度只体现在 UI 卡面 / 召唤演出 / 描边强度（shader 标量参数），机甲本体一台一模。省 4× 成本，直接服务 R1。
- accent 色用 **per-instance shader parameter** 传入（Godot 4 `set_instance_shader_parameter` / `material_override` 的 instance uniform），让 4 套 accent 在运行时按职阶赋值，材质实例数不随角色数膨胀（守 §5.5 唯一材质≤120）。

---

## §4 Godot 接入步骤（工程可直接执行）

> 全部为**下一步动作清单**，本文档不替你改代码。每步标注产出物。

### 4.1 导入预设（GLB → Godot）

| 资产 | 导入预设要点 | 压缩（对齐 asset-spec §1.2） |
|---|---|---|
| 角色 / chassis GLB | 导入 Mesh + Skeleton；**保留骨骼名**；生成 LOD（或外部 LOD 网格）；`gi_mode=Dynamic`；不启用多余平滑 | — |
| 附件 GLB | 仅 Mesh（无骨骼）；作为 `BoneAttachment3D` 子节点 | — |
| 动画 GLB | 仅导入 Animation；clip 拆分命名对齐 §3.2；导出为共享 `AnimationLibrary` | — |
| 纹理 PNG | Albedo/Emission → **BPTC/BC7**（sRGB）；Normal → **S3TC/BC5**；ORM → **BC7**（三通道打包） | 见 §5.5 显存核算 |

> **纹理压缩位置**：Godot 4 的 BPTC/S3TC 在**纹理导入**（`.import`）层设置，不在 GLB 导入层。建议 GLB 内**不内嵌贴图**，走外部 PNG（`res://game/art/textures/mecha/`）以获得压缩控制权（美术圣经 §5.6 的 BPTC 映射才落得实）。

### 4.2 场景结构（每个角色一个变体场景）

```
chr_<job>_<id>.tscn
└─ Node3D (root, name="Model")
   ├─ Skeleton3D (name 固定，bone 名 = §2.2 canonical)
   │  └─ MeshInstance3D (skin)  ← chassis mesh（引用 chr_<job>_base）
   ├─ BoneAttachment3D (parent=weapon_mount_R) → att_blade_sword (显隐按角色)
   ├─ BoneAttachment3D (parent=wing_L/R)        → att_windchaser_wing (非风追隐藏)
   ├─ BoneAttachment3D (parent=core)            → att_core_sphere
   ├─ AnimationTree (ref = anim_shared_tree.tres；anim_player → 共享 AnimationLibrary)
   └─ MeshInstance3D (rim)  ← MechBase 母材（RESONANCE_GLOW emissive 回路）
```

- 替换现有占位：`arena_min.gd` 的 `_model = CharacterModel.new()` 改为按 `character_id` `preload`/`load` 对应 `chr_<job>_<id>.tscn` 并 `instance()`；`CharacterDefinition.art_ref`（现为空字符串）填 `.tscn` 路径（gacha §5.2 已有该字段，只差填值）。
- 非风追角色：隐藏 `wing_L/R` 的 `BoneAttachment3D`（`visible=false`），无需另建骨骼。

### 4.3 动画系统 = 战斗 FSM 的从属订阅者（架构纪律，最高优先级）

**铁律（来自 CLAUDE.md + 架构 §4.4「敌人 FSM 不广播 player_state_entered」同源纪律）**：
> **AnimationTree 不得持有自己的状态机逻辑 / 不得自治转移。** 游戏状态唯一真相源 = 战斗 FSM；动画只是其表现投影。

- 新建 `game/src/art/mech_animator.gd`（`class_name MechAnimator extends Node`，**表现层，只读订阅 EventBus**，与 `AudioDirector`/`DebugOverlay` 同构）：
  - `_ready()`：`EventBus.player_state_entered.connect(_on_state)`。
  - `_on_state(state_name)`：调 `animation_tree.travel(_state_to_clip(state_name))`。
  - **所有 AnimationTree 过渡设为 manual / `advance_mode = MANUAL`（禁用自动转移）**，只有 `travel()` 能推进——杜绝动画系统"自作主张"跳态，与战斗 FSM 状态严格 1:1。
- **帧精度对齐**：`AnimationTree`/`AnimationPlayer` 的 `callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS`（4.7 可能为 `AnimationMixer.callback_mode_process`），使动画回调与 60Hz `_physics_process` 同拍，命中点对齐 GDD 窗口帧（CANCEL=8/PARRY=6/DASH=12 等由 FSM 持有，动画只给姿势）。
- **伤害不进动画**：动画的 method-call track 只允许调 `AudioDirector.play_event()`（已有先例，`audio_director.gd` L390），**绝不**在动画里改 `CANCEL_WINDOW` 等常量或触发伤害——伤害结算唯一在 FSM/`SkillController`。
- **禁 root motion**：机甲位移由 FSM + `arena_min` 的移动换算（MOVE_UNITS_PER_STAT 等）权威；动画 clip **不导出根运动**，避免"动画位移"与"FSM 位移"双源打架。

### 4.4 动画集实际清单（对照 FSM 8 态，揭示缺口）

| FSM 态 | clip | 来源建议 | 状态 |
|---|---|---|---|
| Idle | `anim_idle` | 手 auth / Mixamo Idle 重映射 | ✅ 圣经已列 |
| Run | `anim_run` | 手 auth | ✅ 圣经已列 |
| Slash | `anim_slash_blade` / `_bulwark` / `_windchaser` / `_resonant`（4 职阶变体）| 手 auth | ✅ 圣经已列（attack×4）|
| Dash | `anim_dash` | 手 auth | ⚠ **圣经缺口**（§5.4 仅标"可选"）|
| Grapple | `anim_grapple` | 手 auth | ✅ 圣经已列 |
| Leap | `anim_leap` | 手 auth | ⚠ 圣经标"可选"，但 **P2 垂直是核心支柱，建议升必做** |
| Parry | `anim_parry` | 手 auth | 🔴 **圣经完全未列 —— FSM 有 Parry（PARRY_WINDOW=6），无动画则玩家读不出完美格，300ms 慢动作无视觉落点** |
| Resonate | `anim_finisher`（Harmonic Iris 母体 + 职阶叠加）| 手 auth | ✅ 圣经已列（finisher）|
| Hitstun | `anim_hit` | 手 auth | ✅ 圣经已列（hit）|

**汇总**：FSM 需要 **9 个 clip**（Idle/Run/Slash×4/Dash/Grapple/Leap/Parry/Hit/Finisher = 实为 12 条轨道，Slash 算 4 条），美术圣经 §5.4 只承诺 **8 条**（含 Slash×4 算 1 套）→ **净缺 Dash / Parry / Leap 三条**（若 Leap 升必做）。**这是必须回美术/主理人补的硬缺口**（见 §6 O9）。

### 4.5 与 PlayerCombat / EnemyCombat 的对接点

- **玩家**：`PlayerCombat` 不感知模型细节，只经 `EventBus.player_state_entered` 广播态名；`MechAnimator`（表现层）订阅驱动 `anim_finisher` 等。移除旧 `CharacterModel` 占位即可，`PlayerCombat` 代码**零改动**（符合 gacha §6.1「feature-flag 回落」纪律：无 `art_ref` 时仍可回退占位）。
- **敌人（混沌造物）**：走 `enemy_*` 信号 + 独立 `AnimationTree`（不共享本动画集）。telegraph 阶段由 `vfx_telegraph_threat`（锁 `THREAT`）呈现，动画只需 Telegraph/Attack/Recover/Stagger/Dead 五态，骨骼可与玩家共用 `skel_mech_shared` 或独立（混沌造物「破对称」建议独立骨骼，**不在 O3 范围**，另立文档）。

---

## §5 资产预算勾稽（对齐 asset-spec §2.1，逐条有余量）

### 5.1 全局红线核对（1 台出战）

| 指标（asset-spec §2.1）| 预算 | 本方案 1 台出战 | 结论 |
|---|---|---|---|
| 骨骼角色同屏 | ≤12 | 1（出战）+ 敌 ≤11 | ✅ 余量充足 |
| 三角（可见）| ≤2,000,000 | 1 台 LOD0 ≈ 22k（chassis 14k + 附件 8k）| ✅ ≪ 240k |
| 纹理显存 | ≤2.5 GB | ≈17–22 MB（见 §5.3）| ✅ |
| 唯一材质 | ≤120 | MechBase + 4 accent + 少量 base ≈ ≤10 | ✅ |
| GPU 粒子 | ≤30,000 | 机甲本体 0；VFX 峰值 ≤9.5k（含敌 telegraph，圣经 §5.8）| ✅ |

> 仅 1 台出战同屏（gacha 选 1 部署），8 台不叠加——这是预算能落的关键前提（gacha §8 待批项 2 已裁决）。

### 5.2 面数分配（单台 LOD0 ≤ 22k，守圣经 §5.2）

| 部件 | 三角 | 说明 |
|---|---|---|
| chassis（按职阶 1 套）| 12–14k | 腿/腰/核心/肩主体 |
| 附件（刀/盾/翼/核/环/杖/发束，按角色组合）| 4–8k | 刚性件，可 AI 生成后 decimate |
| **合计 LOD0** | **16–22k** | 落在圣经 18–22k 区间（留 2k 给识别件微差）|
| LOD1 | 9–11k | 外部 LOD 或自动 |
| LOD2 | 4–5k | — |

### 5.3 显存核算（单台，含 mipmap ×1.33）

**推荐方案（Plan B：chassis 按职阶 2048² ×4 套 + 附件 1024² ×8）**：

| 图集 | 尺寸 | 通道 | 压缩 | 单张 | 数量 | 小计 |
|---|---|---|---|---|---|---|
| chassis albedo | 2048² | sRGB | BC7 | 5.6 MB | 4（职阶）| 22.3 MB |
| chassis ORM | 2048² | 打包 | BC7 | 5.6 MB | 4 | 22.3 MB |
| chassis normal | 2048² | 切线 | BC5 | 5.6 MB | 4 | 22.3 MB |
| chassis emission | 2048² | sRGB | BC7 | 5.6 MB | 4 | 22.3 MB |
| 附件 atlas | 1024² | 4 通道 | BC7×4 | 1.4 MB | 8（角色）| 11.2 MB |
| **8 台 hub 全驻留** | | | | | | **≈113 MB** |
| **1 台出战** | | | | | | **≈28 MB**（1 chassis×22.3 + 1 附件×1.4）|

- **对照圣经 §5.6**：圣经按「1 台 4×2048²≈22MB」估算；本方案 1 台出战 ≈28MB（因含 1024² 附件），仍 ≪ 2.5GB，且满足「单台≈22MB」量级（附件可压到 512² 进一步贴近）。
- **hub 花名册 8 台全驻留 ≈113MB ≪ 2.5GB**（圣经 §5.8 估 176MB，本方案更省，因附件用 1024²）。
- 备选 Plan A（每台独立 2048² 全套）：8 台 ≈178MB，也可行但略贵；Plan B 更优。

### 5.4 语义色落地（修正美术圣经路径）

- 真相源 = `game/src/core/color_tokens.gd`（const 段），**不是** `resources/colors/color_tokens.tres`（代码里无此文件）。
- `INACTIVE` / `GATE_READY` 已有临时 const（灰 / 暖金），O1 在代码侧**部分已收口**；`MECH_BASE` 建议补为 const（见 §3.3）。
- `THREAT` 品红在任何机甲资产里**不得出现**；CI 扫描 `grep THREAT` 于机甲 `.tres`/`.gd` 必为空（对接 gacha `AC-GACHA-03` / `AC-GACHA-06`）。

### 5.5 知识缺口（Godot 4.7 具体 API，标记不臆造）

- **K1**：Godot 4.7 导入 dock 的「骨骼重定形 / Rest Fixer / Use Named Skin」**确切开关名与位置**待验证（4.0–4.3 间有改名）。落地前需开一次 Godot 4.7 导入面板截图确认，或查官方 4.7 文档。
- **K2**：`AnimationMixer.callback_mode_process` 在 4.7 的枚举名（4.3 前为 `ANIMATION_CALLBACK_MODE_PROCESS_*`）待核对，但"绑定到物理帧"的意图确定。
- **K3**：per-instance shader 换 accent 色，`set_instance_shader_parameter` 对 `StandardMaterial3D` 的可用 uniform 类型（Color 支持，但需材质开启 `use_as_albedo`/instance uniform 声明）待在 4.7 实测。若受限，回退为 4 套 accent 材质实例（仍守 ≤120）。
- 以上 K1–K3 不影响方案结构，仅影响"具体勾哪个框"，可在落地 Story 里由执行者开编辑器确认。

### 5.6 CI 强校验（把"共享骨骼"从口头纪律变成门禁）

补一个 `tests/` 资产契约测试（对齐项目"先写测试"纪律，如 `test_constants_match_gdd.gd`）：

- `test_skel_contract.gd`：
  - [ ] 扫描 8 个 `chr_*.glb`，断言每个 `Skeleton3D` 的 bone 名集合 / 父子层级 / 数量 == `skel_mech_shared.tscn` 基准（防骨骼漂移）。
  - [ ] 断言每个 GLB 无 `THREAT` hex / 无 `ColorTokens.THREAT` 引用（机甲侧铁律）。
  - [ ] 断言共享 `AnimationLibrary` 的 track path 在 8 场景里均可解析（防 NodePath 不一致导致动画错位）。
  - [ ] 断言 LOD0 三角 ≤22k、图集 ≤2048²（预算门禁）。
- 这把"8 台必须能重定向到同一副骨骼"变成**CI 红灯**，而不是美术自查。

---

## §6 风险清单 + 所需支持（待主理人/用户拍板）

### 6.1 风险清单

| # | 风险 | 严重度 | 缓解 / 当前结论 |
|---|---|---|---|
| **R-A** | 混元 3D 无法产出可重定向 rig（无骨骼/超面数）| 🔴 高（若误用 AI 当最终资产）| §1.2 已判"不能"；改用 §1.3 混合管线，AI 仅做刚性附件 |
| **R-B** | 蒙皮成本（4 套 chassis）仍需美术/外部人力 | 🟠 中高 | 是 R1 唯一结构解；建议确认人力来源（O3 拍板）|
| **R-C** | **动画集缺口**：Dash/Parry/Leap 三条圣经未列，但 FSM 有 Parry 态 | 🔴 高 | §4.4 已揭示；必须补（O9）|
| **R-D** | Mixamo 商业授权（Adobe 账户 / 商标）| 🟠 中 | 若用 Mixamo 作来源需主理人确认授权；推荐手 auth 规避 |
| **R-E** | 混元生成件的原创性红线（§7 V-fin/mono-eye）| 🟠 中 | 生成仅做刚性附件，且人工审 + 负面提示词约束 |
| **R-F** | 同职阶两台靠附件+配色区分，辨识度是否够 | 🟡 中低 | 美术圣经 §3 已判定可行；建议 playtest 验证（对接 AC-GACHA-05）|
| **R-G** | 骨骼 rest pose 漂移（8 台不一致 → 脚离地）| 🟠 中 | §2.2 冻结纪律 + §5.6 CI 强校验 |
| **R-H** | Godot 4.7 具体导入/API 开关名（K1–K3）| 🟡 低 | 落地 Story 开编辑器确认，不影响结构 |

### 6.2 待主理人/用户拍板项（阻塞落地）

| # | 项 | 选项 | 我的推荐 |
|---|---|---|---|
| **O3** | 8 台 GLB 产出方式 | A 混合（推荐）/ B 全手工 / C 全 AI（不可行）| **A** |
| **O3-人力** | 4 套 chassis 蒙皮 + 动画集的人力/外部工具来源 | 内部美术 / 外包 / 全程序化（不可行，无自动蒙皮）| 需主理人确认资源 |
| **O4** | 动画来源 | 手 auth（推荐）/ Mixamo 重映射（需授权）/ 生成（不可行）| **手 auth** |
| **O6** | 稀有度是否随档变视觉 | 不分档（推荐，省 4×）/ 分档（成本 ×4）| **不分档** |
| **O9（新）** | 补 Dash/Parry/Leap 三条动画 | 补（必做，因 FSM 有 Parry 态）/ 暂不补（Parry 无视觉）| **补** |
| **O1** | `MECH_BASE` 补为 `ColorTokens` const | 补（推荐）/ 留材质 albedo 值 | **补**（便于 lint） |
| **K-确认** | Godot 4.7 导入 dock 开关名（K1–K3）| 落地前开编辑器截图确认 | 执行 Story 内做 |

### 6.3 下一步建议执行顺序（供主理人排期）

1. **拍板 O3/O4/O6/O9**（本文 §6.2）→ 解锁生产。
2. 建 `skel_mech_shared.tscn`（canonical 52-bone）+ 写 `test_skel_contract.gd`（CI 先行）。
3. 美术/外包产出 4 套 chassis（蒙皮到 canonical）+ 1 套动画集（12 clip）。
4. 混元 3D 生成刚性附件原型 → 人工 decimate + 挂 `BoneAttachment`。
5. 8 台 `chr_<job>_<id>.tscn` 装配 + `arena_min.gd` 替换占位（保留 fallback）。
6. `mech_animator.gd` 接 `EventBus.player_state_entered`，AnimationTree 全 manual。
7. CI 跑 `test_skel_contract.gd` + 预算断言，playtest 验证辨识度（AC-GACHA-05）。

---

## §7 一句话结论（回传主理人用）

> **生产方法**：混元 3D【不能】直接产出可重定向 rig（零骨骼），改用「4 套手蒙 chassis（按职阶）+ AI 生成的刚性附件 + shader 换色」混合管线，把 R1 成本压到「4 次蒙皮 + 1 套动画集」。
> **共享骨骼**：可行且是硬约束唯一解——8 台蒙到同一副冻结 52-bone `skel_mech_shared`，差异只靠 mesh 体积 + `BoneAttachment` 附件 + 配色，运行时零 retarget，靠 §5.6 CI 强校验防漂移。
> **最大风险**：① 动画集缺口（Dash/Parry/Leap 圣经未列，但 FSM 有 Parry 态，必补）；② 4 套 chassis 蒙皮 + 动画集需要美术/外部人力（O3-人力待拍板）。

---

> **变更记录**：v0.1 — S10 O3 关键生产门技术方案。核查现状（无 GLB、占位为代码拼装、FSM 8 态、EventBus 信号已存在），给出混合生产方法裁决、共享骨骼规格与重定向步骤、Godot 接入清单、预算勾稽、风险与拍板项。未改任何代码/场景/数值。
