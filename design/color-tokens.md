# 权威 ColorTokens · 星陨之境（Aetherfall）
> **文档类型**：语义色单一真相源（Color Tokens · Final Hex）
> **任务**：CONCERN-A 收口（Phase 3 跨文档不一致）
> **视觉权威**：林绘澄（美术圣经作者）；本文件为所有语义色 hex 的最终真理源
> **对齐**：美术圣经 §2（视觉真理源）、概念 §7 色彩纪律、systems-index §2（待文策渊同步为本文件值）
> **约束**：`THREAT=#A62C6B` 不可变；提供 Godot 4 可用 hex
> **版本**：v1.2（机甲灰阶补登。**既有 hex 一处未变，`THREAT` 保持锁定**；引用「v1.0 / v1.1」的下游文档无需更新）

**变更记录**
- **v1.2**：补登机甲灰阶 MECH_BASE/INACTIVE_GRAY 及圣经引用色。（关闭 `mecha-art-bible.md §8` 开放项 **O1**；三个新增全部为**结构色 / 状态色**，**非信号色**，不触碰 `THREAT` 语义、不改变「敌方预警锁 THREAT」约定。）
- **v1.1**：别名补录 `FRIENDLY_AMBER`（hex 集合与 v1.0 完全一致，无一处取值变更）。
- **v1.0**：CONCERN-A 跨文档语义色冲突收口定稿（见 §4）。

---

## 0. 权威声明（Single Source of Truth）
- 本文件是**所有语义色 hex 的最终真理源**。美术圣经 §2 的 hex 与本文件一致；systems-index §2 须由文策渊同步为本文件值（改一处即全项目生效，ColorTokens 单资源）。
- 任何新增资产 / 系统引用语义色，必须引用本文件的 **Token 名**，禁止硬编码旧 hex（尤其已退役的 `#2BB6A8` / `#F4B740`）。
- `THREAT=#A62C6B` 为不可变常量，仅敌/混沌专属（敌人预警、Boss 脉冲、危险标记），**任何模式不得外溢到中立/友方**。
- **别名策略**：一个 hex 可有多个合法名——**本名**（权威 Token 名）+ **别名**（语义别名 / 代码字段名）。别名**不另立 hex**，一律解析到本名取值。别名是合法引用，**不是退役名**，不进 lint 拒绝名单（拒绝名单只收退役 hex 字面量）。当前别名登记见 §1 别名区。

---

## 1. 语义色 Token 表（最终 hex）

| Token (EN) | 中文 | Hex | Godot `Color(r,g,b)` | 用途 | 来源 / 说明 |
|---|---|---|---|---|---|
| `PLAYER_ALLY_MAIN` | 玩家/友方主色（星辉青）| `#5FD2C8` | `(0.373, 0.824, 0.784)` | 玩家身份、友方/共鸣基色、HUD 友方强调 | 美术圣经 §2 星辉青（**真理源**）|
| `RESONANCE_GLOW` | 共振辉光（自发光）| `#9FF7E8` | `(0.624, 0.969, 0.910)` | 共鸣节点/终结技/星刃辉光（emissive + Bloom 提亮青白）| 由星辉青衍生的**发光态**（见 §4 说明）|
| `FRIENDLY_TEAL` | 友方支撑·青 | `#5FD2C8` | `(0.373, 0.824, 0.784)` | 友方/自然/环境青调（与玩家主色同 hue，呼应"玩家即共鸣体"）| 美术圣经 §2 星辉青 |
| `FRIENDLY_GOLD` | 友方支撑·暖金 | `#F2C15E` | `(0.949, 0.757, 0.369)` | 可交互/线索、希望点缀、暖光 | 美术圣经 §2 暖金 |
| `FRIENDLY_CORAL` | 友方支撑·珊瑚 | `#FF8A65` | `(1.000, 0.541, 0.396)` | 友方暖点缀、植被/魔法暖强调 | 概念 §7 珊瑚（美术圣经 §2 未列，此处 canon 化）|
| `THREAT` | 威胁品红（混沌）| `#A62C6B` | `(0.651, 0.173, 0.420)` | 敌人/混沌专属、预警、Boss 脉冲、危险标记 | **不可变常量（mandated）** |
| `DAMAGE_WARN` | 伤害/警告 | `#E5484D` | `(0.898, 0.282, 0.302)` | 受击、危险区、低血闪（替代 THREAT 守"THREAT 仅敌/混沌"铁律）| 美术圣经 §2 |
| — | 治疗/增益 | `#7BD16A` | `(0.482, 0.820, 0.416)` | 回血、buff | 美术圣经 §2 |
| `UI_BG` | UI 底（深空）| `#1A2233` | `(0.102, 0.133, 0.200)` | 面板/遮罩底色、文本托底 | 美术圣经 §2 |
| `SKY_AZURE` | 苍穹蓝（品牌）| `#3E6FB0` | `(0.243, 0.435, 0.690)` | 天空/水体/远景基色 | 美术圣经 §2 主色板 |
| `INTERACT` | 可交互/线索 | `= FRIENDLY_GOLD #F2C15E` | 同暖金 | 拾取/机关/路标（复用暖金）| 美术圣经 §2 可交互 |
| `FRIENDLY_AMBER` | 友方支撑·暖金（代码字段名）| `= FRIENDLY_GOLD #F2C15E` | 同暖金 | 同 `FRIENDLY_GOLD`（可交互/线索、希望点缀、暖光）| architecture L720 `@export var`、systems-index §2、ux-spec §98、accessibility-tier §0 |
| `UI_BASE` | UI 底（深空，代码字段名）| `= UI_BG #1A2233` | 同 `UI_BG` | 同 `UI_BG`（面板/遮罩底色、文本托底）| architecture L793 `@export var` |
| `MECH_BASE` | 机甲 chassis 基色（深岩灰）| `#2A3140` | `(0.165, 0.192, 0.251)` | 玩家/友方机甲 chassis 主 albedo、MechBase 材底 | 美术圣经 §5.1 hero 底；机甲圣经 §1.1/§2.1/§2.3；**与敌枪铁灰区分见下** |
| `INACTIVE` | 未就绪 / 不可用态（灰）| `#5A6072` | `(0.353, 0.376, 0.447)` | 共鸣池不足等「未就绪」态底色、N 稀有度未就绪灰、禁用控件 | gacha §2.1、ux-spec §105、systems-index §2；**本名 `INACTIVE`，别名 `INACTIVE_GRAY`** |
| `ENEMY_CHASSIS_GRAY` | 敌方 chassis 基色（枪铁灰）| `#3A3F4B` | `(0.227, 0.247, 0.294)` | 敌方混沌造物 chassis 主 albedo（材质结构色，非信号）| 美术圣经 §5.3；机甲圣经 §1.1/§2.3（刻意区别于 `MECH_BASE`）|

### 1.1 别名区（Aliases）

**本名 `FRIENDLY_GOLD` = `#F2C15E`，下列名字均解析到该值：**

| 别名 | 类型 | 解析到 | 谁在用 |
|---|---|---|---|
| `INTERACT` | 语义别名 | `FRIENDLY_GOLD` `#F2C15E` | 美术圣经 §2、audio-direction §321 |
| `FRIENDLY_AMBER` | **代码侧别名** | `FRIENDLY_GOLD` `#F2C15E` | architecture L720、systems-index §2、ux-spec、accessibility-tier §0 |
| `UI_BASE` | **代码侧别名** | `UI_BG` `#1A2233` | architecture L793 `@export var` |
| `INACTIVE_GRAY` | **文档侧别名** | `INACTIVE` `#5A6072` | 机甲圣经 §2.3（原「提案·待登记」名）；解析到 `INACTIVE`，不另立 hex |

> `INTERACT` 为 `FRIENDLY_GOLD` 的语义别名，不另立 hex，避免调色板膨胀。
> `FRIENDLY_AMBER` 为 `FRIENDLY_GOLD` 的代码侧别名，不另立 hex，避免调色板膨胀。
>
> **裁决（T5-ART-b）**：`FRIENDLY_GOLD` 与 `FRIENDLY_AMBER` 同值同义，**两个名字都合法**——文档侧写 `FRIENDLY_GOLD`、代码侧 `ColorTokens.FRIENDLY_AMBER` 字段维持原样，**均解析到 `#F2C15E`，无需改名、无需同步其他文件**。
> **新增引用一律优先用本名 `FRIENDLY_GOLD`**（对齐美术圣经 §2「暖金」，中英文名一致；`amber/琥珀` 易与 `FRIENDLY_CORAL #FF8A65` 的暖橙区混淆）。
>
> **裁决（T5-ART-c）**：`UI_BG` 与 `UI_BASE` 同值同义，**两个名字都合法**——文档侧写 `UI_BG`、代码侧 `ColorTokens.UI_BASE` 字段维持原样（architecture L793 `@export var`），**均解析到 `#1A2233`，无需改名、无需同步其他文件**。
> **新增引用一律优先用本名 `UI_BG`**（对齐美术圣经 §2「深空底」，中英文名一致）。

---

## 2. 色盲模式（CVD）映射

**铁律**：色相替换只是辅助，**形状/图标/明度编码为强制**（见可访问性分级 F1）；`THREAT` 品红任何模式不得外溢到中立/友方。

| Token | Normal | CVD Alt | 强制非色编码 | 说明 |
|---|---|---|---|---|
| `PLAYER_ALLY_MAIN` | `#5FD2C8` | Deutan/Protan 保持；Tritan→`#4FD0C0` | 无（青对红绿型安全）| 青在红绿色盲下可辨 |
| `RESONANCE_GLOW` | `#9FF7E8` | 保持 | — | 近白，全 CVD 安全 |
| `FRIENDLY_GOLD` | `#F2C15E` | 保持 | ↗ 图标 | 金/蓝轴 CVD 安全 |
| `FRIENDLY_CORAL` | `#FF8A65` | Deutan/Protan→`#FF9E40`（更橙）| 位置/图标 | 避免与绿混淆 |
| `THREAT` | `#A62C6B` | Deutan/Protan 保持（与青对比强）；Tritan→`#8E2C7A`（更紫）| **菱形 + 脉冲（强制）** | 品红对红绿型安全；Tritan 需位移 + 形状 |
| 伤害红 | `#E5484D` | `#FF5A36`（鲜橙红）| ⚠ 图标 + 血条位置 | 红绿型下红→橙更易辨 |
| 治疗绿 | `#7BD16A` | `#3E8FD0`（CVD 安全蓝，与玩家青以明度/色相区分）| ✚ 图标 | 绿→蓝避开红绿混淆；蓝与玩家青不同明度 |
| `UI_BG` | `#1A2233` | 保持 | — | 中性 |
| `UI_BASE` | `#1A2233` | 保持 | — | 同 `UI_BG`（代码侧别名）|
| `MECH_BASE` | `#2A3140` | 保持 | — | 中性 chassis，非信号色（F1 形状编码承载阵营读）|
| `INACTIVE` | `#5A6072` | 保持 | 禁用样式 + 文字提示 | 状态灰；仅表「未就绪/禁用」，不承载信息文本（2.54:1 低于 3:1）|
| `ENEMY_CHASSIS_GRAY` | `#3A3F4B` | 保持 | — | 中性 chassis，非信号色（敌预警仍锁 `THREAT`）|
| `INTERACT` | `#F2C15E` | 保持 | ↗ 图标 | 同暖金（别名）|
| `FRIENDLY_AMBER` | `#F2C15E` | 保持 | ↗ 图标 | 同暖金（代码侧别名）|

> Godot 4 CVD Alt 浮点（备用）：`#4FD0C0`=`(0.310,0.816,0.753)`、`#8E2C7A`=`(0.557,0.173,0.478)`、`#FF5A36`=`(1.000,0.353,0.212)`、`#3E8FD0`=`(0.243,0.561,0.816)`、`#FF9E40`=`(1.000,0.620,0.251)`。

---

## 3. Godot 4 落地指引
- **集中管理**：在 autoload 单例（如 `ColorTokens` GDScript 常量或 `Theme` 资源）定义上述 Token，全项目引用，禁止散落硬编码。
- **语义色** = `Color(r,g,b)`（见 §1 浮点）；emissive 辉光用 `RESONANCE_GLOW` 设 `emission` + Bloom（`WorldEnvironment` Glow 阈值偏高，避免整体发灰）。
- **色盲模式**：运行时切换 CVD Alt（改 `Theme`/材质参数，或用 `CompositorEffect` 色相旋转），并叠加图标（UI `Control` / 世界空间 sprite）。
- **THREAT 单一来源**：游戏代码（如敌人 telegraph）与美术均引用同一 `THREAT` Token，确保"仅敌/混沌"。

---

## 4. 冲突收口说明（CONCERN-A 三处 + 补充）

| 冲突项 | systems-index §2（旧）| 美术圣经 §2（真理源）| 本文件定稿 | 处置 |
|---|---|---|---|---|
| 共振辉光 | `#9FF7E8` (`RESONANCE_GLOW`) | 共振/玩家 = 星辉青 `#5FD2C8` | 拆分：`PLAYER_ALLY_MAIN=#5FD2C8`；`RESONANCE_GLOW`(emissive)=`#9FF7E8` | 旧 `#9FF7E8` 保留为**发光态**（衍生自星辉青），非真冲突 |
| 友方青 | `#2BB6A8` | 星辉青 `#5FD2C8` | `#5FD2C8` | 退役 `#2BB6A8`，统一星辉青 |
| 暖金 | `#F4B740` | 暖金 `#F2C15E` | `#F2C15E` | 退役 `#F4B740`，统一暖金 |
| （补充）珊瑚 | `#FF8A65` | 未列 | `#FF8A65`（canon）| 采纳概念 §7，正式入册 |
| `MECH_BASE` | — | 未列 | `#2A3140` | 机甲圣经补登（O1）；友方 chassis 结构色 |
| `INACTIVE` / `INACTIVE_GRAY` | — | 未列 | `#5A6072` | 机甲圣经补登（O1）；「未就绪/禁用」态，本名 `INACTIVE` |
| `ENEMY_CHASSIS_GRAY` | — | 美术圣经 §5.3 `#3A3F4B` | `#3A3F4B` | 敌 chassis 结构色；**非信号**，**不**取代 `THREAT` 预警语义 |
| `THREAT` | `#A62C6B` | `#A62C6B` | `#A62C6B` | **不变（mandated）** |

> ⚠ **别名 ≠ 退役名**：本表「退役」列针对的是**旧 hex 字面量**（`#2BB6A8`、`#F4B740`），它们进 lint 拒绝名单。
> `FRIENDLY_AMBER` **不是退役名**，是 `FRIENDLY_GOLD` 的合法别名（见 §1.1），**不得**被 lint 拦截；`control-checklist.md` 的拒绝名单只收退役 hex，无需改动。
> `UI_BASE` **不是退役名**，是 `UI_BG` 的合法别名（见 §1.1），解析到 `#1A2233`；`control-checklist.md` 的拒绝名单只收**退役 hex 字面量**，**不得**拦截 `UI_BASE`（既不拦 token 名，也不拦其取值 `#1A2233`——该值本就是权威 `UI_BG` 当前值）。

**为何共振辉光保留 `#9FF7E8`**：美术圣经 §2 只定义了"星辉青 `#5FD2C8`"这一青色真理；systems-index 的 `#9FF7E8` 实为同一青色家族的**自发光/泛光态**（emissive bloom 需更亮的青白才读作"光"而非"色块"）。故本文件将二者拆分为基色（`PLAYER_ALLY_MAIN`）与发光态（`RESONANCE_GLOW`），既守美术圣经真理，又给技术上正确的辉光表现——冲突源于旧文档同名不同义，现已厘清。

> **v1.2 灰阶补登记·铁律重申**：`MECH_BASE #2A3140`、`INACTIVE #5A6072`、`ENEMY_CHASSIS_GRAY #3A3F4B` 三者均为**结构/状态色（材质 albedo / 控件态）**，**绝不**承担语义信号。阵营「友/敌」可读性与威胁提示，仍**唯一**由 `PLAYER_ALLY_MAIN`（青白共鸣回路）、`THREAT`（品红 telegraph + 菱形脉冲）承载（见 §0、§2）。新增 `ENEMY_CHASSIS_GRAY` **不构成第二种敌人警告色**——敌预告/危险标记只有 `THREAT` 一个信号源，枪铁灰与深岩灰互为对照仅是「机体材质」，对比度仅 ~1.24:1（见 §2 说明），本就**不能**用于阵营辨识。

---

## 4.5 环境美术色（非语义信号）
> 本节登记**纯环境/地形美术色**，明确**不**承担阵营或威胁语义，不触碰 `THREAT` 铁律。
> 仅 arena 草原地图的地表、草丛、地形阴影使用；攻防信号仍唯一由语义 Token（§1）承载。
> 由主理人游承峰定稿（arena 草原化需求），不进入文策渊语义色表，不计入 CVD 替换。

| Token (EN) | 中文 | Hex | Godot `Color(r,g,b)` | 用途 | 来源 / 说明 |
|---|---|---|---|---|---|
| `ENV_GRASS` | 草原地表·中绿 | `#4E7A3A` | `(0.306, 0.478, 0.227)` | 草原地面 albedo、草丛主色 | 草原地图环境美术（非语义）|
| `ENV_SOIL` | 土壤/地形阴影·暖褐 | `#5A4632` | `(0.353, 0.275, 0.196)` | 草丛根部、起伏阴影、结构色 | 草原地图环境美术（非语义）|

## 5. 下一步 / 交接
- **文策渊**：将 systems-index §2 语义色 hex 同步为本文件值（THREAT / RESONANCE_GLOW / FRIENDLY teal·gold·coral / 伤害 / 治疗 / UI_BG），并改为引用本 ColorTokens 单资源（避免二次漂移）。
- **美术圣经**：可在 §2 末新增 §2.6「权威 hex 见 `design/color-tokens.md`」交叉引用（可选，不阻塞）。
- **程基岩（架构）**：设置系统/可读性据本 Token 实现色盲切换与主题参数化（按 Handoff 不直连，由主理人调度）。
- 本收口为 Phase 3 跨文档不一致收尾，**不阻塞 Phase 4 开工**。
- **（v1.2 已闭）机甲灰阶 O1**：`MECH_BASE` / `INACTIVE`(`INACTIVE_GRAY`) / `ENEMY_CHASSIS_GRAY` 已入册（§1、§1.1、§2、§4）。**建议（非阻塞）**：机甲圣经 §2.3 表头「MECH_BASE（提案）/ INACTIVE_GRAY（提案·待登记）/ 无 hex 待补登」等措辞与其 §8 O1「未入 color-tokens」应改为「已补登」；该圣经的清理由美术总监/主理人下一轮处理，本文件不擅改其它文档。
- **（v1.2 待拍板）`ENEMY_CHASSIS_GRAY`**：为「补登圣经引用色、避免散落 hex 被 lint 拦截」而新增（美术圣经 §5.3 已 canon）。其定位为**纯结构色**，不引入第二种敌人信号。若主理人判定敌方 chassis 永不进代码（仅作美术参考），可退回、仅保留 `MECH_BASE`/`INACTIVE`，由工程在美术侧引用；此决策需主理人确认。
