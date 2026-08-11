# 机甲美术圣经 + 资产 / VFX 规格 · 星陨之境（Aetherfall Mecha Art Bible & Asset Spec）

> **文档类型**：机甲线美术圣经 + 资产/VFX 规格（视觉身份扩展，非重复创建）
> **任务**：S10 机甲美术 · 第一步（把 8 名占位样本模型换成「动画风原创机甲」+ 补齐技能特效底座）
> **作者**：林绘澄（美术总监 / art-director）
> **引擎 / 平台**：Godot 4.7-stable（Forward+）· PC / Steam
> **版本**：v0.1（机甲化基准版）
> **纪律**：本文档**只产出美术方向与规格**，不写代码、不改场景/脚本。工程接入清单（§5/§9）供程基岩落地。
> **上游权威**（务必先看，不另起炉灶）：
> - `design/color-tokens.md` v1.1 — 语义色唯一真理源（`THREAT=#A62C6B` 不可变）
> - `design/art-bible.md` v0.1 — 全局美术圣经（§2 色彩 / §4 材质 / §8 VFX）
> - `design/art/asset-spec.md` v1.0 — 资产规格与预算（扩展对象）
> - `design/gdd/systems/gacha.md` §2.1/§8 — 8 角色身份、4 档稀有度色、共用骨骼裁决
> - `design/gdd/systems/gacha-characters.md` — 8 角色五维 / 技能 / lore
> - `design/accessibility/accessibility-tier.md` v1.0 — 可访问性分级（Standard 基线）

---

## §0 文档定位与「机甲化」衔接（先读）

### 0.1 本文档与既有文档的关系
- **不是**新建一份全局美术圣经。全局视觉真理仍归 `art-bible.md`（§2 色板 / §4 材质 / §8 VFX）。本文件在其上**叠加一条「机甲线」专属规范**，并复用既有材质库、能量语言、语义色。
- **替换**对象：`design/art/character-sample-models.md`（v0.1 占位图元样本）。该文档明确把「图元 → 绑定网格（共用同一骨骼集）→ PBR → 特效」列为演进路径；本文件即其「绑定网格 + 材质 + 特效」阶段的事实依据。
- **扩展**对象：`design/art/asset-spec.md`（v1.0）。其 §1.1 的「星刃旅人」单角色条目在此升级为「8 机甲共享骨骼 + 变体」条目；预算勾稽见 §5.8。

### 0.2 与 art-bible §5 的概念衔接（P3 精美即叙事）
- `art-bible.md §5.1` 的「星刃旅人（有机人形 hero）」是 Phase 1 概念种子。机甲化后，该身份重定义为：**8 名可玩角色 = 八位「残响旅人」各驾驶一台原创共鸣机甲**（pilot + mech）。
- 机甲外形承担 pilot 的故事（P3）：每一台的轮廓、识别件、强调色都在「讲这位旅人是谁」。有机曲线 hero vs 硬角 enemy 的 dichotomy 在机甲线下演化为：**共鸣机甲（秩序 / 对称 / 青白能量）= 玩家阵营** vs **混沌造物（破碎 / 不对称 / 品红）= 敌人**。
- ⚠ **待主理人确认**：`art-bible.md §5.1` 是否需要补一句「机甲线为 8 可玩角色最终形态，有机人形为概念期占位」的衔接注记。本文档不擅自改全局圣经。

### 0.3 共用骨骼硬约束（来自 gacha.md §8 待批项 2）
> gacha.md 裁决：**v1 八角色全部共用同一套骨骼与动画集**，差异化仅靠模型 / 材质 / 配色 / 特效。

本规格据此设计：**一条 canonical 骨骼 `skel_mech_shared` + 一套共享动画集**，8 台机甲只是同一骨架上的不同 mesh 外壳与附件（如风追的翼 = 背骨上的 `BoneAttachment`，非风追角色隐藏即可）。这是压住 P3 生产成本（gacha.md C-风险 R1）的唯一结构解。

### 0.4 铁律重申
- `THREAT = #A62C6B` **仅敌 / 混沌专属**。任何机甲（玩家 / 友方）**不得**使用品红（gacha.md §2.1 铁律、color-tokens §0）。
- 语义色一律引用 Token 名，禁止硬编码 hex（CLAUDE.md §1、asset-spec §3.3）。
- 机甲为**原创设计**，不得克隆高达 / 任何受版权 IP（见 §7 红线）。

---

## §1 机甲视觉语言（Mecha Visual Language）

### 1.1 双层语法：阵营整体 × 职阶区分
机甲线一眼可读靠**两层叠加**，而非每角色各自为政：

1. **阵营层（整体可读 = 你是我方）**：8 台共用
   - 同一 chassis 家族（腿/腰/核心/肩的模块比例一致）；
   - 同一**共鸣回路（resonance conduit）**能量线语言（见 §1.3）；
   - 同一**阵营纹章（共鸣符文 crest）**位置（左胸 / 额心）；
   - 同一底色 `MECH_BASE`（深岩灰 `#2A3140`，取自 art-bible §5.1 hero 底，刻意区别于敌人枪铁灰 `#3A3F4B`）。
2. **职阶层（4 类一眼分）**：靠**剪影语法 + 强调色 + 关键识别件**区分（见 §1.2、§2.2）。

> 判定基线：0.2 秒内区分「友/敌」「职阶」。**友方机甲 = 对称、流畅、青白能量、昂扬姿态**；**敌方混沌造物 = 破对称、硬角、品红、故障抖动**（沿用 art-bible §5.3）。机甲线把这条 dichotomy 做得更锋利。

### 1.2 四职阶剪影语法（Silhouette Grammar）
| 职阶 | 剪影关键词 | 体型重心 | 关键轮廓动作 |
|---|---|---|---|
| **BLADE 锋刃** | 锋利、修长、单手/双手刃 | 高、重心偏上 | 刃臂前伸的锐利三角，收腰显敏捷 |
| **BULWARK 磐盾** | 厚重、方正、大盾 | 低、重心压底 | 宽肩 + 巨盾构成「墙」形，读作战术支点 |
| **WINDCHASER 风追** | 轻快、流线、背翼 | 中、重心轻飘 | 背部翼 + 流线腿，读起「要飞」 |
| **RESONANT 谐律** | 能量核心感、神职、环/核 | 中高、仪式感 | 头环 / 胸核 / 法杖构成「共鸣焦点」 |

职阶内两台靠**识别件 + 强调色微差**区分（见 §3），保证「先看职阶、再看是谁」。

### 1.3 分件 / 装甲 / 外露骨架语言
- **模块件词汇（Modular Part Vocabulary）**：所有机甲由同一套部件库拼装——
  - `core_block` 核心舱（胸，含共鸣核 housing）、`armor_plate` 装甲片（肩/小腿/腰）、`λ_frame` 外露骨架（关节外露的细杆，显「机械感」）、`thruster` 推进器（背/脚，呼应 P2 垂直）、`weapon_mount` 武器挂点、附 `wing` 翼（仅风追）。
- **「动画风」分件纪律**：分件边界**粗读、干净**——用明确缝隙 + 0.5–1.5cm 视觉间隙（stylized）而非写实密铆钉；避免高频微 greeble 堆砌（stylized ≠ 脏旧，见 art-bible §4.3）。每件边缘走统一 `MECH_RIM`（Fresnel 边缘高光，复用 `shd_rim.gdshader`）。
- **外露骨架的叙事**：`λ_frame` 为暗调金属，露出处嵌**星辉青能量线**，读作「活着的机械生命」；敌人则把骨架裸露成「断裂锈骨 + 品红侵蚀」形成对照。

### 1.4 能量线 / 发光件语言（共鸣回路 Resonance Conduit）
- **定义**：沿 chassis 结构走向的** engraved 发光细线**（非大面积发光块），是阵营标识也是「共鸣力量可视化」。
- **颜色规则**：阵营主线 = `PLAYER_ALLY_MAIN #5FD2C8`（所有 8 台共用）；职阶强调色（§2.2）作为**次级高亮**出现在该职阶识别件上。
- **发光纪律（防过曝，对 §6.2）**：能量线用细带状 emissive（`RESONANCE_GLOW` 作发光态），**不**用大面 bloom；`WorldEnvironment` Glow 阈值偏高（art-bible §2.5/§3.3）；emissive 强度封顶，避免 clip 到白。
- **动效**：能量线随共鸣池水位呼吸（满池更亮、脉冲更快）——把 P4「共鸣统一」做成可读的视觉反馈（呼应 HUD 星核球）。

### 1.5 阵营识别锚点
- **共鸣纹章（crest）**：左胸 core_block 上方一枚统一「星纹/共鸣符文」浮雕（青白 emissive），是 8 台共享的「阵营身份证」。
- **额心节点**：头盔额心一枚小共鸣节点（青白），强化「同源」感。
- 以上两件 + 青白能量线 + 深岩灰底色 = 阵营整体读。

---

## §2 材质与配色系统（Material & Color System）

### 2.1 基础金属 / 涂装 / 能量色
- **复用材质库**（asset-spec §1.3 / art-bible §4.2）：`AuroraStone`、`ResonanceMetal`、`StarWood`、`HazeGlass`。机甲主材新增 **`MechBase`**（见下）。
- **`MechBase` 共鸣机甲基材**：深岩灰 albedo `#2A3140` + metalness 0.55–0.75 + roughness 0.45–0.6（比敌人枪铁灰更亮、更「干净秩序」）；外缘 `MECH_RIM`；能量线槽位走 `RESONANCE_GLOW` emissive。
- **涂装（paint）**：职阶强调色以**小块涂装 + 发光件**出现，不刷大面积（守色彩纪律 60/25/10 占比，art-bible §2.5）。
- **能量色**：见 §1.4，阵营青 `#5FD2C8` + 发光态 `#9FF7E8`。

### 2.2 配色语法：三层叠加
| 层 | 来源 | 取值 | 出现位置 |
|---|---|---|---|
| **阵营结构色（Faction）** | 全 8 台共用 | `PLAYER_ALLY_MAIN #5FD2C8` | 共鸣回路能量线、核心 housing、纹章、额心 |
| **职阶强调色（Job accent）** | 按职阶 | BLADE=`FRIENDLY_GOLD #F2C15E`；BULWARK=`SKY_AZURE #3E6FB0`；WINDCHASER=`FRIENDLY_CORAL #FF8A65`；RESONANT=`RESONANCE_GLOW #9FF7E8` | 该职阶识别件（刃/盾/翼/核）的涂装与次级发光 |
| **稀有度升级（Rarity）** | 按 gacha §2.1 | N=灰 matte / R=精炼+苍穹蓝描边 / SR=+暖金描边+更多发光vent / SSR=+青白 emissive bloom+召唤特写 | 材质精致度 / 发光强度 / 附加发光件（**非色替换**，守 F1 非色编码） |

> **职阶强调色与 Token 挂钩**：四种强调色全部取自 color-tokens 友方族，零新增 hex、零 THREAT 越界。
> **稀有度与色**：稀有度**不靠换主色**区分（避免与职阶色碰撞），而是靠「材质精致度 + 发光件数量 + 描边」梯度，并叠加 gacha §2.1 的**强制非色编码**（★角标 / 切角 / 星芒边框）满足 F1。

### 2.3 可落地 Hex 色板（机甲线专用）
| Token（引用名） | Hex | Godot `Color(r,g,b)` | 机甲用途 | 备注 |
|---|---|---|---|---|
| `PLAYER_ALLY_MAIN` | `#5FD2C8` | `(0.373,0.824,0.784)` | 阵营能量线 / 核心 / 纹章（全 8 台） | 真理源；faction 主色 |
| `RESONANCE_GLOW` | `#9FF7E8` | `(0.624,0.969,0.910)` | 发光态 emissive / RESONANT 职阶色 / SSR 稀有度 | 发光态，近白全 CVD 安全 |
| `FRIENDLY_GOLD` | `#F2C15E` | `(0.949,0.757,0.369)` | BLADE 职阶色 / SR 稀有度描边 | 刃锋暖金 |
| `FRIENDLY_CORAL` | `#FF8A65` | `(1.000,0.541,0.396)` | WINDCHASER 职阶色 | 翼/流线暖珊瑚 |
| `SKY_AZURE` | `#3E6FB0` | `(0.243,0.435,0.690)` | BULWARK 职阶色 / R 稀有度描边 | 盾/厚重苍穹蓝 |
| `THREAT` | `#A62C6B` | `(0.651,0.173,0.420)` | **仅敌/混沌 telegraph**（机甲线禁用） | 不可变常量 |
| `DAMAGE_WARN` | `#E5484D` | `(0.898,0.282,0.302)` | 受击/非敌危险（机甲受击闪） | 不属敌语义 |
| `MECH_BASE`（提案） | `#2A3140` | `(0.165,0.192,0.251)` | 机甲 chassis 主 albedo | 深岩灰；区别于敌枪铁灰 `#3A3F4B` |
| `INACTIVE_GRAY`（提案·待登记） | `#5A6072` | `(0.353,0.376,0.447)` | N 稀有度未就绪灰底 | ⚠ **color-tokens 无 hex，需文策渊/主理人补登**（gacha §2.1 仅写「灰」） |
| `UI_BG` | `#1A2233` | `(0.102,0.133,0.200)` | 无（机甲不用） | 仅 UI 底 |

> ⚠ 开放项：`INACTIVE_GRAY` 与 `MECH_BASE` 两个灰目前未进 `color-tokens.md`。建议文策渊把二者补登为 Token（`INACTIVE` 已有名无 hex；`MECH_BASE` 命名提案），避免散落 hex。本文档先按此值设计，待登记后替换引用。

### 2.4 色盲安全（CVD）预检（对接 color-tokens §2 / accessibility F1）
- 职阶四色在 Protan/Deutan/Tritan 下均不与 `THREAT` 品红混淆（青/金/蓝/珊瑚 vs 品红，对比强）。
- 友方内部区分**不单靠色**：BLADE 刃形 / BULWARK 盾形 / WINDCHASER 翼 / RESONANT 环核 = 强形状编码（F1 强制）。
- 稀有度梯度靠形状/★角标（gacha §2.1），不靠色相，CVD 模式零退化。

---

## §3 八角色机甲设计简报（8 Mecha Design Briefs）

> 每台：轮廓特征 / 关键识别件 / 强调色 / 呼应职阶+五维 / lore 回声 / 生成提示词方向（供 3D 生成步骤直接消费）。
> 五维引用 gacha-characters §1（roll=1000 中位档）。

### 3.1 灰烬学徒 `ash_acolyte` ｜ BLADE 锋刃 · 尘 N
- **轮廓**：纤高收腰，单手持细长刃；整体读「见习执剑人」。
- **识别件**：右臂细长单手刃（刃锋暖金描边）；左肩小圆甲；额心微弱节点。
- **强调色**：`FRIENDLY_GOLD #F2C15E`（刃锋 + 胸口余温发光点）。
- **呼应**：hp95/atk118（攻高）/def90/spd102/aff95 —— 修长锋利呼应高攻；「余温」= 剑柄处一抹持续暖金 ember glow，呼应 lore「剑柄余温尚存」。
- **生成方向**：stylized original mecha, slim humanoid frame, slender single-blade arm, warm-gold blade edge glow, dark-teal chassis with cyan resonance lines, small shoulder pauldron, no V-fin, faction crest on chest.

### 3.2 誓锁守卫 `oath_guard` ｜ BULWARK 磐盾 · 铁 R
- **轮廓**：低重心、宽肩厚甲，左臂巨塔盾；读「墙」。
- **识别件**：左臂圆形塔盾（盾面苍穹蓝「锁」纹章 emissive）；厚重小腿装甲。
- **强调色**：`SKY_AZURE #3E6FB0`（盾纹章 + 肩描边）。
- **呼应**：hp115/atk88/def112（双最高）/spd92/aff93 —— 厚重方正呼应最高耐久最低速；「以誓约为锁」= 盾面锁形纹章，呼应 lore。
- **生成方向**：original heavy mech, broad shoulders, massive round tower shield on left arm, sky-azure lock emblem glowing on shield, thick leg armor, low center of mass, cyan conduit lines, faction crest; no mono-eye.

### 3.3 迅羽游侠 `swift_ranger` ｜ WINDCHASER 风追 · 铁 R
- **轮廓**：轻盈流线，背双翼（羽状），持长枪；读「要飞」。
- **识别件**：背部双羽状翼（珊瑚色涂装）；细长长枪；流线小腿（内置 thruster）。
- **强调色**：`FRIENDLY_CORAL #FF8A65`（翼 + 枪尖）。
- **呼应**：hp90/atk110/spd108（速高）/def88/aff104 —— 轻快流线呼应高移速；「风托起羽毛」= 翼如羽、thruster 轻喷，呼应 lore。
- **生成方向**：lightweight streamlined mech, twin feather-shaped back wings (coral accent), long lance, aerodynamic legs with small thrusters, cyan energy lines, faction crest; distinct from echo by solid (non-glowing) wings.

### 3.4 疾风回响者 `gale_echo` ｜ WINDCHASER 风追 · 辉 SR
- **轮廓**：同风追基底，但翼为**半透明发光**、头顶加光环；读「回声/残像」。
- **识别件**：半透明 emissive 双翼（`RESONANCE_GLOW`）；头顶 Torus 光环；区别于游侠的实翼。
- **强调色**：职阶珊瑚 `#FF8A65` + SR 暖金描边 + 青白发光翼。
- **呼应**：五维同风追（spd108 高）；「同一动作的千万次回声」= 半透明残像翼 + 头环，呼应 lore。
- **生成方向**：same windchaser base, but wings are translucent emissive cyan-white, add a halo ring above head, gold trim (SR), echo/afterimage motif; original, not a Gundam clone.

### 3.5 磐心卫士 `bulwark_heart` ｜ BULWARK 磐盾 · 辉 SR
- **轮廓**：同磐盾基底，胸口双球「心」形核心，短盾；读「守护之心」。
- **识别件**：胸口 twin-sphere 共鸣核心（苍穹蓝 + 脉冲）；左臂短盾（非塔盾）；SR 暖金描边。
- **强调色**：`SKY_AZURE #3E6FB0`（核心 + 盾）。
- **呼应**：hp115/def112（高耐久）；「心跳如磐石」= 胸口核心随心跳脉冲 emissive，呼应 lore「护友于喧嚣」。
- **生成方向**：heavy bulwark mech, twin-sphere chest core pulsing like a heartbeat (sky-azure), short shield (not tower), gold trim (SR), cyan conduits, faction crest; differentiate from oath_guard by chest core + short shield.

### 3.6 谐律主祭 `resonant_hierophant` ｜ RESONANT 谐律 · 星 SSR
- **轮廓**：中高、仪式感，大头光环 + 手持法杖环；读「神职校准者」。
- **识别件**：头顶大光环（青白）；手持 ring-staff；胸核心（青白）。
- **强调色**：`RESONANCE_GLOW #9FF7E8`（环/核/杖，全青白）；SSR 加 bloom + 召唤特写。
- **呼应**：aff115（亲和最高）；「以歌声校准世界的频率」= 头环如音叉、法杖环如共鸣器，呼应 lore。
- **生成方向**：original priest-type mech, large halo ring above head (cyan-white emissive), ring-tipped staff, chest resonance core, SSR bloom trim, elegant symmetric frame, faction crest; no religious-clone silhouettes.

### 3.7 断空剑主 `voidblade_lord` ｜ BLADE 锋刃 · 星 SSR
- **轮廓**：同锋刃修长，双交叉巨剑，黑金「虚空」描边；读「斩开虚空」。
- **识别件**：双交叉巨剑（刃锋金 + 剑身黑金描边）；非对称肩甲（呼应「虚空」）；SSR 青白 bloom 收尾。
- **强调色**：`FRIENDLY_GOLD #F2C15E` 偏深 + 黑描边（void）+ SSR 青白点睛。
- **呼应**：atk118（攻高，SSR 乘区后更狠）；「剑光所至再无间距」= 双剑交叉如破界，呼应 lore。
- **生成方向**：slim dual-greatsword mecha, crossed blades with black-gold void trim, asymmetric shoulder, deep-gold accents, SSR cyan-white glow accents, faction crest; distinct from acolyte by twin greatswords + black trim.

### 3.8 共鸣歌者 `resonant_singer` ｜ RESONANT 谐律 · 辉 SR
- **轮廓**：中人体，胸前发光共鸣核 + 发束状头饰；读「歌唱者」。
- **识别件**：胸前球形共鸣核（青白偏暖）；头顶发束（珊瑚/金）；SR 暖金描边。
- **强调色**：`RESONANCE_GLOW #9FF7E8` 偏暖 + `FRIENDLY_CORAL` 发束点缀。
- **呼应**：aff115（亲和高）；「她唱，世界便低声应和」= 胸前核如歌者之声源、发束如声波，呼应 lore。
- **生成方向**：mid-frame mecha, chest spherical resonance core (warm cyan-white glow), hair-tuft head ornament (coral), gold trim (SR), ring motif, faction crest; differentiate from hierophant by chest core + hair-tuft (no big halo/staff).

> **辨识度结论（回应 gacha §8 待批项2）**：共用骨骼下，8 台靠「职阶剪影语法（§1.2）+ 识别件（§3 每栏）+ 强调色（§2.2）+ 稀有度非色编码（★角标/边框）」四重区分，辨识度充足；同职阶两台再靠识别件微差（实翼 vs 发光翼、塔盾 vs 短盾+心、单手细剑 vs 双巨剑）拉开。**美术侧判定可行**，交工程按 §5 落地。

---

## §4 技能 VFX 方向（Skill VFX Direction）

### 4.0 共鸣母体（Resonance Mother-Motif）· 守 P4「共鸣统一」
- **定义**：所有「共鸣」语义特效共用同一视觉母体 = **谐波虹膜（Harmonic Iris）**——同心旋转光环收束成虹膜/光圈，中央迸发青白（`RESONANCE_GLOW`）脉冲。
- **复用点**：① 终结技 finisher（吃共鸣池 40）② 开门 gate（吃共鸣池 30）③ 共鸣节点触发 ④ 召唤演出。四者**同母体、异强度/异时长**，把 P4「开门↔终结技共享单一共鸣池、天然互斥」做成玩家一眼读懂的视觉同源性。
- **节奏**：虹膜旋开 0.3–0.5s → 满开脉冲 → 收束。终结技更猛（更大半径 + hit-stop），开门更「仪式」（更慢旋开 + 光圈定格）。
- **Shader 方向**：ring/sine shader（`GPUParticles3D` + 自定义 `ShaderMaterial`，additive）；复用 asset-spec §1.5 `ResonanceTide` 同源色温。

### 4.1 斩 Slash（锋刃主伤害）
- **方向**：加色混合的青色渐变缎带（ribbon mesh）+ fresnel + 星痕噪动（沿用 art-bible §8 星刃拖尾）。
- **色彩**：玩家技用**职阶强调色描边 + 阵营青白母体**——BLADE 斩痕染 `FRIENDLY_GOLD` 边、核心 `RESONANCE_GLOW`；其余职阶斩用各自强调色。
- **强度/节奏**：命中 hit-stop 60–90ms（combat.md，非时间膨胀）+ 轻震屏；拖尾 LOD 远处降密度（asset-spec §1.4）。

### 4.2 跃 Leap（垂直/P2）
- **方向**：落地震荡波（landing shockwave）= 地面扩散环 shader（青白母体）；起跳时脚部 thruster 喷流粒子（职阶强调色）。
- **色彩**：shockwave = `RESONANCE_GLOW`；thruster = 职阶强调色。
- **节奏**：起跳短喷（0.15s）+ 滞空悬停微光 + 落地环爆（0.4s 扩散）。

### 4.3 荡 Grapple（锚点/P2）
- **方向**：玩家→锚点的能量索（动态 ribbon/line，additive）；接触锚点处小共鸣环。
- **色彩**：索 = 阵营青 `#5FD2C8` + 职阶强调色高光；锚点互动描边复用 `INTERACT`(=FRIENDLY_GOLD) 暖金（asset-spec §1.1）。
- **节奏**：射出（0.1s）+ 摆荡失重拖影 + 脱钩微闪。

### 4.4 终结技 Finisher（吃共鸣池 · P4 母体）
- **方向**：**Harmonic Iris 母体满开**（§4.0）+ 全屏谐波脉冲 + 高伤 + 击退 4m + hit-stop（systems-index：`FINISHER_SLOWMO` 不存在，全程 `time_scale=1.0`——冲击靠上述承载，不靠慢动作）。
- **色彩**：全程 `RESONANCE_GLOW` 青白；**绝不**用品红。
- **强度/节奏**：虹膜旋开 0.4s → 满开脉冲（强 bloom 但守阈值防过曝）→ 收束；职阶在虹膜中心叠加各自强调色刃/盾/翼/核演出。
- **互斥可视化**：终结技与开门共享母体，玩家靠「同一道光」直观感到「这道光既能开门也能终结」，强化 P4 张力。

### 4.5 完美格 Parry（慢动作归属点）
- **方向**：格挡命中瞬间「叮」火花（菱形晶体碎裂粒子）+ 短 hit-stop + 时间膨胀 0.3/18帧（systems-index 常量，唯一慢动作语义）。
- **色彩**：火花 = `RESONANCE_GLOW` 青白 + 职阶强调色；**非纯色反馈**（见 §6.3）= 菱形碎片形状 + 音效 + 冻结。
- **节奏**：PARRY_SLOWMO 300ms 真实时间（忽略 time_scale），膨胀期约 5.4 游戏帧。

### 4.6 敌人 Telegraph（THREAT 锁定 · 铁律）
- **方向**：敌人攻击前摇显 **THREAT `#A62C6B` 预警**——地面/空间 telegraph 形状（攻击范围指示）+ 脉冲描边 + 故障抖动（ChaosGlitch，asset-spec §1.5）。
- **色彩**：**锁死 `THREAT`**，任何模式不得外溢友方（color-tokens §0 / accessibility F1/F8）。
- **强制非色编码（F1）**：telegraph 附 **菱形 + 脉冲**（accessibility §F1），不单靠色相；Boss 脉冲同 THREAT。
- **节奏**：Hard telegraph 下限 0.4s（consistency-review CONCERN-1）；难度辅助预设可延长（accessibility F7）。

### 4.7 VFX 总表（可落地）
| 类型 | 母体/方向 | 引用色 | 粒子量(峰值) | Shader/实现 | 节奏 |
|---|---|---|---|---|---|
| 斩 slash | 青白缎带+职阶边 | `RESONANCE_GLOW`+职阶accent | ≤1k/实例 | ribbon+additive ShaderMaterial | hit-stop 60–90ms |
| 跃 leap | 落地环+thruster | `RESONANCE_GLOW`+accent | ≤2k | ring shader+GPUParticles | 起跳0.15s/落地0.4s |
| 荡 grapple | 能量索+锚点环 | `PLAYER_ALLY_MAIN`+`INTERACT` | ≤0.5k | dynamic line | 0.1s 射出 |
| 终结技 finisher | **Harmonic Iris 母体** | `RESONANCE_GLOW`（青白）| ≤3k | ring/sine+GPUParticles+additive | 旋开0.4s+脉冲+hit-stop |
| 完美格 parry | 菱形火花+冻结 | `RESONANCE_GLOW`+accent | ≤1k | crystal-burst | PARRY_SLOWMO 300ms |
| 敌 telegraph | **THREAT 锁定** | `THREAT #A62C6B` | ≤1.5k/敌 | ChaosGlitch+shape | ≥0.4s，菱形+脉冲 |

> 全技能 VFX 总基调：**玩家技用友方强调色（青白共鸣母体统一终结技/开门/节点/召唤），敌方 telegraph 锁死 THREAT 品红 + 菱形脉冲形状编码**。

---

## §5 资产生产规格（Asset Production Spec · 工程可直接用）

### 5.1 共享骨骼 `skel_mech_shared`（canonical）
- **结构**：humanoid-biped mech，约 **48–56 bones**。固定层级与命名（冻结，所有 8 台复用）：
  - `root → hips → spine → chest → neck → head`
  - `chest → shoulder_L/R → upper_arm_L/R → lower_arm_L/R → hand_L/R`
  - `hips → upper_leg_L/R → lower_leg_L/R → foot_L/R`
  - 附加：`core`（胸核心空 bone，挂共鸣核）、`weapon_mount_L/R`（挂武器）、`thruster_back`、`wing_L/R`（背骨 `chest` 下的 `BoneAttachment`，非风追角色隐藏）
- **约束**：bone 命名/数量/层级**全 8 台一致**；差异化仅通过 mesh + `BoneAttachment`（翼/盾/武器）实现。Godot 用 `Skeleton3D` + `BoneAttachment3D` 挂附件；换角色 = 换 mesh + 显隐 attachment。

### 5.2 面数预算（每台，与 asset-spec §2.2 对齐）
| 资产 | LOD0 三角 | LOD1 | LOD2 | 纹理 | 同屏上限 | gi_mode |
|---|---|---|---|---|---|---|
| 机甲（每台，8 共用骨架）| 18–22k | 9–11k | 4–5k | 2048² atlas | **1**（仅出战 1 台，hub 可预览）| Dynamic |
| Boss/敌 | （沿用 asset-spec，不变）| — | — | — | — | — |

> 仅 1 台出战同屏（gacha 选 1 部署），故 8 台不叠加；hub/花名册按需流式加载其余（见 §5.8）。

### 5.3 贴图规格（对齐 asset-spec §1.2）
- 通道：**Albedo**(sRGB) / **Normal**(切线) / **ORM**(Occlusion+Roughness+Metalness 合并) / **Emission**(仅发光件，sRGB)。
- 尺寸：机甲 2048² atlas（含分件 UV 排布）；附件（翼/盾）可并入同 atlas 或独立 1024²。
- 强制 ORM 打包；emissive 只给能量线/核心/纹章。

### 5.4 骨架 / 动画需求（共享动画集）
- **必做 5 套**（gacha 共用集）：`anim_idle` / `anim_run` / `anim_attack`（**4 职阶变体**：blade_slash / bulwark_shieldbash / windchaser_lance / resonant_cast）/ `anim_finisher`（Harmonic Iris 母体 pose + 职阶叠加）/ `anim_hit`（受击）。
- **可选抛光**：`anim_dash_start` / `anim_air`（对应 S2 闪/跃摆姿，提升 P1/P2 流动感）。
- **驱动**：Godot `AnimationTree`（blend/过渡），共享状态机；出战角色切换只换 mesh + 动画参数（如风追 run 速度微快由 move_speed 标量驱动，不另做动画）。
- **约束**：窗口帧数（CANCEL_WINDOW=8 / PARRY_WINDOW=6 / DASH_IFRAMES=10）由 combat 决定，动画只提供姿势，**不**在动画里改这些常量（gacha-characters §0 红线）。

### 5.5 GLB / glTF 导入与 Godot 落地
- **格式**：`.glb`（binary glTF 2.0，Godot 4 首选导入）。导出时**保留骨架 + 骨骼名**（与 `skel_mech_shared` 对齐）以便 Godot `Skeleton3D` 复用/重映射。
- **导入预设**：导入网格+骨骼；生成 LOD（或外部 LOD 网格）；静态件 `gi_mode=Static`，机甲 `Dynamic`；不启用多余平滑。
- **共享复用**：建一个 `chr_mech_base.tscn`（含 `Skeleton3D` + `AnimationTree` + `BoneAttachment` 槽），8 台 = 该 base 的 8 个 mesh 变体子场景（`chr_<job>_<id>.tscn`），`CharacterDefinition.model_scene` 指向各自 `.tscn`（gacha §5.2）。

### 5.6 纹理压缩适配（bptc / s3tc）
- **目标后端**：Forward+，Windows = D3D12，Vulkan 回退（adr-001）。**BPTC 与 S3TC 在 D3D12/Vulkan 均支持**，无兼容风险。
- **映射**（对齐 asset-spec §1.2）：
  - Albedo → **BPTC / BC7**（sRGB，8 bpp → 4.19 MB @2048²）
  - Emission → **BPTC / BC7**（sRGB，8 bpp → 4.19 MB @2048²）
  - Normal → **S3TC / BC5**（RG 切线，8 bpp → 4.19 MB @2048²）
  - ORM → **BC7**（三通道打包，8 bpp → 4.19 MB）；若拆单通道则 BC4（4 bpp → 2.10 MB/通道）
- **单台显存核算**：4 张 2048² ≈ 16.8 MB，含 mipmap（×1.33）≈ **22 MB / 台**。
- 移动/Compatibility 后端（G5 缺口）下 BPTC 不支持 → 需 fallback 为 etc2；**v1 PC 独占不阻塞**，标注为 Should 项。

### 5.7 工程接入清单（命名 / 路径 / 清单）
- **目录**（扩展 asset-spec §3.1）：
  ```
  res://art/models/mecha/   # chr_<job>_<id>_lod0.glb ...
  res://art/models/mecha/shared/skel_mech_shared.tscn
  res://art/materials/mecha/ # mat_mechbase.tres 等
  res://art/textures/mecha/  # tex_<id>_albedo.png ...
  res://scenes/mecha/        # chr_<job>_<id>.tscn
  res://shaders/             # 复用 shd_rim / ResonanceTide / ChaosGlitch
  res://scenes/vfx/mecha/    # vfx_resonance_iris / vfx_slash_* / vfx_telegraph_threat ...
  ```
- **命名规范**（沿用 asset-spec §3.2 `{cat}_{name}_{var}_{lod}.{ext}`）：
  - 模型：`chr_blade_ash_acolyte_lod0.glb` … `chr_resonant_singer_lod0.glb`
  - 材质：`mat_mechbase.tres`、`mat_mech_accent_gold.tres` 等（accent 按职阶 4 套）
  - VFX：`vfx_resonance_iris.tres`、`vfx_slash_blade.tres`、`vfx_telegraph_threat.tres`、`vfx_parry_spark.tres`、`vfx_leap_shockwave.tres`、`vfx_grapple_line.tres`
  - 语义色：全部从 `color_tokens.tres` 取，CVD 热切换覆盖（asset-spec §3.3）；lint 拦截散落 hex。
- **资产校验**（对接 gacha `AC-GACHA-03`）：每台须满足 ① 引用 `skel_mech_shared` ② 命名合规 ③ 无 THREAT 引用 ④ emissive 仅 `RESONANCE_GLOW`/职阶accent。

### 5.8 与 asset-spec 预算勾稽（不破全局红线）
| 指标（asset-spec §2.1）| 原预算 | 机甲线影响 | 结论 |
|---|---|---|---|
| 骨骼角色同屏 ≤12 | 玩家1+敌≤11 | 出战机甲=1，不与敌叠加 | ✅ 余量充足 |
| 三角 ≤2M | 角色~240k | 1 台出战 22k，远低于 240k | ✅ |
| 纹理显存 ≤2.5GB | — | 1 台 resident ≈22MB（§5.6 核算，含 mip）；hub 花名册若 8 台全驻留 ≈176MB，仍 <<2.5GB | ✅ |
| 唯一材质 ≤120 | 4 基材+变体 | 机甲 +`MechBase`+4 accent ≈ +5 | ✅ |
| 粒子 ≤30k | 分项封顶 | VFX 峰值 ≤约 9.5k（含敌 telegraph）| ✅ 余量 |

---

## §6 可访问性备注（Accessibility · art-director 负责）

### 6.1 色盲友好（F1）
- 职阶四色（青/金/蓝/珊瑚）CVD 下均不误读为 `THREAT` 品红（§2.4）。
- 敌 telegraph **形状编码优先**：菱形 + 脉冲（accessibility §F1 强制），色相替换仅辅助。
- 稀有度靠 ★角标/切角/星芒边框（gacha §2.1），不靠色相，CVD 零退化。

### 6.2 发光不过曝（F5 / 光敏与眩晕）
- **emissive 强度封顶**：能量线/核心 emissive 亮度设上限，禁止 clip 到纯白；`WorldEnvironment` Glow **阈值偏高**（art-bible §3.3），保证 bloom 只包住发光件而非整屏发灰。
- **细带而非大面**：能量线用细带 emissive（§1.4），大面积发光仅在终结技满开瞬间短暂出现（<0.5s）。
- **高频闪烁受控**：终结技脉冲、敌 telegraph 脉冲频率避开 3–30Hz 光敏高危带；`ChaosGlitch.intensity` 与终结技 bloom 强度**接可访问性滑块**（accessibility F5，可降至 0）。
- **SSR 稀有度 bloom** 同样受滑块约束，不得因稀有度炫技突破过曝底线。

### 6.3 关键反馈不纯靠颜色（F1 / F8）
| 反馈 | 颜色 | **强制非色编码** |
|---|---|---|
| 敌 telegraph | `THREAT` 品红 | **菱形 + 脉冲**（accessibility F1 强制）+ 范围形状 + 音效 |
| 完美格成功 | 青白火花 | **菱形晶体碎裂形状** + hit-stop 冻结 + 「叮」音效 + 时间膨胀 |
| 终结技可用 | 青白 | HUD 星核球**满环形状** + 图标 + 音效（不靠色亮度差） |
| 受击 | `DAMAGE_WARN` 炽红 | ⚠ 图标 + 血条位置 + 震屏（color-tokens §2） |
| 职阶区分 | 四强调色 | **剪影形状**（刃/盾/翼/环核）为主，色为辅 |
| 稀有度 | 无色替换 | ★×N 角标 + 边框形状（直角/切角/星芒）|

### 6.4 分级归属
- 本机甲线按 **Standard**（v1 推荐基线，accessibility §3.1）设计：三型色盲替换 + 形状编码 + 发光强度滑块 + 高对比兼容。
- **跨级铁律**：任何级别下 `THREAT` 品红零外溢到机甲（友方）——机甲线资产审计须逐台 grep 确认（§5.7 校验④）。

---

## §7 原创性红线（Originality Guardrails）

用户方向为「动画风原创机甲」，精神接近高达 / 国产机甲动画，但**必须原创**。生产与 AI 生成阶段须遵守：

- ❌ **禁止**：V 字额饰（V-fin）、双眼+额宝石的 RX-78 面部组合、Zaku 单眼横槽、EVA 特征脸/束缚具、Valkyrie 可变机构等**任何具体受版权 IP 的标志性识别件**。
- ❌ **禁止**在生成提示词中出现受版权 IP 名称、机体型号、作品名（如 "Gundam"、"RX-78"、"Zaku"、"EVA-01"、"Macross"）。
- ✅ **允许**：机甲这一**通用类型**的共性语汇——分件装甲、关节骨架、推进器、能量线、驾驶舱概念。这些是类型语言，不是某一 IP 的专属。
- ✅ **本作原创识别系统**（区别于任何既有 IP）：**共鸣纹章 + 额心节点 + 青白共鸣回路 + 倒泪滴星陨世界观的能量美学**（§1.5）。这四件是 Aetherfall 机甲的身份指纹。
- **生成提示词模板**（§3 每台已给）统一以 `original stylized mecha, anime-inspired` 开头，并显式带 `no V-fin, no mono-eye, original design` 负面约束。

---

## §8 风险与开放项（不阻塞，需主理人/用户拍板）

| # | 项 | 说明 | 归属 |
|---|---|---|---|
| **O1** | `MECH_BASE #2A3140` / `INACTIVE_GRAY #5A6072` 未入 color-tokens | 两个灰目前无权威 Token（`INACTIVE` 有名无 hex）。建议补登，避免散落 hex 被 lint 拦截 | 文策渊 / 主理人拍板 |
| **O2** | `art-bible.md §5.1` 衔接注记 | 有机人形 hero → 机甲线的定位关系，建议在全局圣经补一句；本文档不擅改 | 主理人 |
| **O3** | 8 台 GLB 的实际产出方式 | AI 3D 生成 vs 手工建模 vs 混合；共享骨骼要求对生成管线是硬约束（生成件须能重定向到 `skel_mech_shared`） | 用户 / 主理人 |
| **O4** | 动画集来源 | 5 套共享动画（idle/run/attack×4变体/finisher/hit）需确定来源（自制 / mixamo 重定向 / 生成）；重定向须骨骼名对齐 | 程基岩 + 主理人 |
| **O5** | Compatibility 后端 BPTC fallback | 若 G5（Steam Deck）转 Should，需补 etc2 fallback 预设 | 程基岩 |
| **O6** | 稀有度视觉是否随「同一角色不同档」变化 | gacha 同角色有 N/R/SR/SSR 四档数值，视觉是否也分档（成本 ×4）？**建议：不分档**，稀有度只体现在 UI 卡面与召唤演出，机甲本体一台一模（省 4× 成本） | 主理人拍板 |

---

## §9 交付摘要（给工程 / 3D 生成步骤直接消费）

**一句话机甲语言**：*八台共用同一副共鸣骨架的原创动画风机甲，以「深岩灰 chassis + 青白共鸣回路 + 共鸣纹章」统一为一个阵营，再以四套职阶剪影（锋刃修长 / 磐盾厚重 / 风追流线 / 谐律环核）与四种友方强调色完成区分——敌人则永远是破对称、品红、故障的混沌造物。*

**每职阶强调色**：
- BLADE 锋刃 → `FRIENDLY_GOLD #F2C15E`
- BULWARK 磐盾 → `SKY_AZURE #3E6FB0`
- WINDCHASER 风追 → `FRIENDLY_CORAL #FF8A65`
- RESONANT 谐律 → `RESONANCE_GLOW #9FF7E8`
- （阵营共用结构色 `PLAYER_ALLY_MAIN #5FD2C8`；敌方 telegraph 锁 `THREAT #A62C6B`）

**技能 VFX 总基调**：玩家技全部以**谐波虹膜（Harmonic Iris）青白母体**为共鸣视觉母体——终结技 / 开门 / 共鸣节点 / 召唤同源异强度，把 P4「单一共鸣池互斥」做成一眼可读的同一道光；斩/跃/荡叠各自职阶强调色；敌人 telegraph 锁死 THREAT 品红 + **菱形脉冲形状编码**（不单靠颜色）。

**8 台清单（生成/建模直接用）**：
| id | 职阶 | 强调色 | 关键识别件 |
|---|---|---|---|
| `ash_acolyte` | BLADE | `#F2C15E` | 细长单手刃 + 剑柄余温 ember |
| `voidblade_lord` | BLADE | `#F2C15E`深+黑金 | 双交叉巨剑 + 非对称肩 |
| `oath_guard` | BULWARK | `#3E6FB0` | 圆形塔盾 + 锁纹章 |
| `bulwark_heart` | BULWARK | `#3E6FB0` | 胸口双球心核 + 短盾 |
| `swift_ranger` | WINDCHASER | `#FF8A65` | 实体羽翼 + 长枪 |
| `gale_echo` | WINDCHASER | `#FF8A65`+青白 | 半透明发光翼 + 头环 |
| `resonant_hierophant` | RESONANT | `#9FF7E8` | 大头光环 + 环杖 |
| `resonant_singer` | RESONANT | `#9FF7E8`暖 | 胸前球核 + 发束头饰 |

**工程接入要点**：共享骨骼 `skel_mech_shared`（48–56 bones，命名冻结）→ `chr_mech_base.tscn` + 8 mesh 变体 → GLB 导入 → LOD0 18–22k 三角 / 2048² atlas → Albedo·Emission=BPTC(BC7)、Normal=S3TC(BC5)、ORM=BC4/BC7 → 5 套共享动画（AnimationTree）→ 语义色全走 `color_tokens.tres`。

---

> **变更记录**：v0.1 — S10 机甲美术第一步。依用户「动画风原创机甲 + 补齐技能特效」方向，在既有 `art-bible.md` / `asset-spec.md` / `color-tokens.md v1.1` 基础上扩展机甲线，替代 `character-sample-models.md` 占位样本层。未新增任何语义色 hex（除两个待登记灰 O1），未改动任何代码或场景。