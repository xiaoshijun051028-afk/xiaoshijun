# 资产规格 Asset Spec · 星陨之境（Aetherfall）
> **文档类型**：资产规格（Asset Specification）
> **任务 ID**：T4-ART（Phase 4 预制作 · 优先级 P0）
> **引擎 / 平台**：Godot 4.7.1（Forward+） / PC · Steam
> **评审强度**：Solo（精炼可执行）
> **上游对齐**：美术圣经 §4/§6/§8、架构 §6(渲染管线)/§7(性能预算)、ColorTokens（`design/color-tokens.md` v1.0）
> **版本**：v1.0

---

## 0. 范围与依据
本规格把美术圣经的视觉语言落地为**可生产、可生成、可审计**的资产清单与预算。所有数值严格对齐架构 §7.3 场景复杂度预算（draw call ≤1500 / 三角 ≤2M / 粒子 ≤30k / CPU ≤9ms / GPU ≤15ms）与 §6 渲染管线。语义色一律引用 ColorTokens Token 名，禁止硬编码 hex。

---

## 1. 资产清单（按系统）

### 1.1 3D 模型
| 系统 | 资产 | 数量 | 说明 | 语义色 / 材质 |
|---|---|---|---|---|
| 玩家 | 星刃旅人 Starblade Wanderer | 1 | 主角 + 星带披帛（独立骨骼/布料）；星刃为子件 | `PLAYER_ALLY_MAIN`；StarWood+ResonanceMetal |
| 敌人 | Brute（重装）| 1 原型 | 破对称硬角、枪铁灰底 + `THREAT` 脉冲 | `THREAT`；ResonanceMetal |
| 敌人 | Skirmisher（敏捷）| 1 原型 | 轻量、带故障抖动 | `THREAT` |
| 敌人 | Sentinel（远程/弱点）| 1 原型 | 弱点 x2（架构 §4.5）| `THREAT` |
| 敌人 | Boss（区域首领）| 1 | 多阶段（boss_phase_changed）| `THREAT` + `RESONANCE_GLOW` 侵蚀 |
| 世界 | 浮岛构件 Kit | 模块化一组 | 倒泪滴：顶岩(AuroraStone) + 晶根(HazeGlass) + 岩桥 | AuroraStone / HazeGlass |
| 世界 | 神龛 Shrine | 1 | 存档/复活点；`AreaLight3D` 柔光 | StarWood + `RESONANCE_GLOW` |
| 世界 | 共鸣闸门 Gate | 1 | 消耗共鸣池开启（GATE_COST=30）| ResonanceMetal + `RESONANCE_GLOW` |
| 世界 | 锚点 Anchor | 1 | 荡/跃抓点；可交互描边（stencil）| `INTERACT`(暖金) |
| 世界 | 残响节点 EchoNode | 1 | 触发叙事（S7）| ResonanceMetal + `RESONANCE_GLOW` |
| 植被 | 星花 / 苇 / 叶 | 模块化一组 | instanced；星花自发光 motes | `FRIENDLY_CORAL` / `RESONANCE_GLOW` |
| UI(3D) | 威胁标记 / 伤害数 世界空间 sprite | — | 复用 §6 HUD 符文语言 | `THREAT` / 伤害红 |

### 1.2 纹理
- **Albedo**（sRGB）、**Normal**（切线）、**ORM**（Occlusion/Roughness/Metalness 合并，强制打包）、**Emission**（仅共鸣/辉光物体，sRGB）。
- 尺寸上限：主角 2048²；敌人/神龛 1024–2048²；环境 tileable 1024²；道具/植被 512–1024²。压缩：Albedo/Emission=BPTC(BC7)，Normal=BC5，ORM=BC4/RG。

### 1.3 材质库（4 类，对齐美术 §4.2 / 架构 §6.3）
| 材质 | Roughness | Metalness | gi_mode | 备注 |
|---|---|---|---|---|
| **AuroraStone** 星纹岩 | 0.70–0.90 | 0.00 | Static | 分带渐变 Albedo + 可选发光脉络 |
| **ResonanceMetal** 共鸣金属 | 0.20–0.40 | 0.60–0.90 | Dynamic | + `RESONANCE_GLOW` emissive 镶边 |
| **StarWood** 星木 | 0.30–0.60 | 0.00–0.20 | Dynamic | 透射/微 emission 星斑 |
| **HazeGlass** 雾晶 | 0.30–0.60 | 0.00 | Static | 半透/折射低，+ `RESONANCE_GLOW` 点缀 |
- 全项目统一 `rim.gdshader` include（Fresnel Rim：hero 强 / 环境弱）。可交互描边用 stencil（架构 §6.3）。

### 1.4 VFX（粒子 / 特效）
| 特效 | 实现 | 粒子量 | 引用色 |
|---|---|---|---|
| 星刃拖尾 | ribbon mesh + 加色 ShaderMaterial | 0（mesh）| `RESONANCE_GLOW` |
| 共鸣光效 | GPUParticles3D + 扩散环 shader | ≤2k/实例 | `RESONANCE_GLOW` |
| 混沌侵蚀 | glitch shader + ember 粒子 | ≤1.5k/敌 | `THREAT` |
| 体积光 | VolumetricFog + DirectionalLight | 0 | — |
| 闪避 i-frame | DashPhase（CompositorEffect）| 0 | — |
| 速度线 | SpeedStreaks（CompositorEffect）| 0 | — |
| 天空星陨 | Sky Shader + 浮尘 motes | ≤5k 环境 | `SKY_AZURE` / `FRIENDLY_GOLD` |

### 1.5 Shader
| Shader | 类型 | 说明 | 约束 |
|---|---|---|---|
| **Fresnel Rim** `shd_rim.gdshader` | include | 全项目精美描边 | 4.5+ stencil 外描边 |
| **共鸣潮汐 ResonanceTide** | Curve+Gradient 资源 + 脚本 | 驱动 Key 光色温/天幕染色，6–8min 周期（架构 §6.2 `[GAP]` 周期待定）| `_process` 纯表现 |
| **混沌 glitch** `ChaosGlitch` | CompositorEffect | UV 位移 + 色散 + 扫描线 | 暴露 `intensity` 接可访问性滑块（美术 §9.3）|

---

## 2. 预算与 LOD（对齐架构 §7.3）

### 2.1 全局预算勾稽（每帧 High 档 @1440p）
| 指标（架构 §7.3）| 预算 | 本规格分配口径 |
|---|---|---|
| Draw calls | ≤ 1,500 | 静态几何 MultiMesh/GridMap 合批；环境 ~600、角色 ~12×1–3、VFX ~200、UI ~50 |
| 三角形（可见）| ≤ 2,000,000 | 环境 kits（含 LOD）~1.0–1.4M、角色 ~240k、VFX mesh 极小 |
| GPU 粒子总数 | ≤ 30,000 | 见 §2.3 分项封顶 |
| 单 GPUParticles3D | ≤ 2,000 | 硬上限，超出需评审 |
| 实时阴影投射光 | ≤ 4 | Key + 3（AreaLight 默认不投影）|
| AreaLight3D 同屏 | ≤ 8 | 神龛/节点/闸门符文（§6.2/§6.4）|
| 反射探针 | ≤ 6 / 岛 | — |
| 唯一材质数 | ≤ 120 | 4 基材 + 变体 ≤ 120 |
| 骨骼角色同屏 | ≤ 12 | 玩家 1 + 敌 ≤11（典型 3–6）|
| 纹理显存 | ≤ 2.5 GB | 尺寸上限见 §1.2 |
| 系统内存 | ≤ 3.5 GB | — |

### 2.2 逐资产预算与 LOD 档
| 资产 | LOD0 三角 | LOD1 | LOD2 | 纹理 | 同屏上限 | gi_mode |
|---|---|---|---|---|---|---|
| 星刃旅人 | 18k | 9k | 4k | 2048² atlas | 1 | Dynamic |
| Brute | 12k | 6k | 3k | 1024–2048² | ≤4 | Dynamic |
| Skirmisher | 8k | 4k | 2k | 1024² | ≤6 | Dynamic |
| Sentinel | 10k | 5k | 2.5k | 1024–2048² | ≤4 | Dynamic |
| Boss | 40k | 20k | 10k | 2048²×2 | 1 | Dynamic |
| 浮岛岩件 | 0.5–3k/件 | ×0.5 | ×0.25 | 1024² tileable | MultiMesh 数百 | Static |
| 晶根 | 1–4k | ×0.5 | ×0.25 | 1024² | instanced | Static |
| 神龛 | 3–5k | ×0.5 | ×0.25 | 1024² | ≤6/岛 | Static（+AreaLight）|
| 闸门 | 2–4k | ×0.5 | ×0.25 | 1024² | 少 | Dynamic |
| 锚点 | 0.2–0.5k | — | — | 256² | ≤20 | Disabled |
| 残响节点 | 1–2k | ×0.5 | — | 512² | ≤3/岛 | Dynamic（+AreaLight）|
| 植被/星花 | 0.2–0.8k | — | — | 512² | instanced 数百 | Static/Disabled |

### 2.3 粒子分项封顶（战斗峰值，总和 ≤30k）
| 来源 | 封顶 | 说明 |
|---|---|---|
| 混沌侵蚀 ember（≤4 敌 ×1.5k）| 6k | `THREAT` |
| 共鸣光效（≤3 实例 ×2k）| 6k | `RESONANCE_GLOW` |
| 天空星陨 motes + 浮尘 | 5k | 环境常驻 |
| 星刃拖尾 motes | ≤1k | 极少量点缀 |
| 残响/神龛辉光 | ≤3k | `RESONANCE_GLOW` |
| **合计** | **≤21k**（余量 9k）| 低于 30k 红线，留峰值余量 |

> LOD 偏置：High 默认、Low 激进（架构 §6.4）；`GPUParticles3D` 上限 High=100% 预算、Low=40%。

---

## 3. 资产管线

### 3.1 目录结构（对齐架构 §2.1）
```text
res://
├── art/
│   ├── models/        # .glb：chr_ / env_ / prop_
│   ├── textures/      # albedo / normal / orm / emission（tex_ 前缀）
│   └── materials/     # 材质实例（或下放 resources/materials/）
├── resources/
│   ├── materials/     # 4 基材模板（aurorastone/resonancemetal/starwood/hazeglass）
│   ├── colors/color_tokens.tres        # 语义色单一源（§9 引用）
│   └── colors/color_tokens_cvd.tres   # 色盲模式热切换
├── shaders/           # shd_rim.gdshader / ChaosGlitch / ResonanceTide
└── scenes/            # player/ enemies/ world/ vfx/ ui/
```

### 3.2 命名规范
格式：`{cat}_{name}_{var}_{lod}.{ext}`
- 前缀：`chr_`(角色) `env_`(环境) `prop_`(道具) `vfx_`(特效) `mat_`(材质) `shd_`(着色器) `tex_`(纹理) `sky_`(天空)
- LOD 后缀：`_lod0` / `_lod1` / `_lod2`（或 `_hi/_mid/_lo`）
- 示例：`chr_player_wanderer_lod0.glb`、`env_isle_rock_a.glb`、`mat_resonancemetal.tres`、`vfx_resonance_ring.tres`、`shd_rim.gdshader`、`tex_isle_rock_albedo.png`
- 规则：全小写下划线；同名资产靠前缀区分系统；禁止空格/中文文件名（UID 友好，架构 §12.2 要求编辑器内移动）。

### 3.3 导入预设
- **模型（.glb）**：导入网格+骨骼；生成 LOD（或导入 LOD 网格）；不启用多余平滑；静态件 `gi_mode=Static`，动态件 `Dynamic`。
- **纹理**：ORM **强制打包**（Occlusion/Roughness/Metalness 合一）；Albedo/Emission 标 sRGB；Normal 切线空间；按 §1.2 尺寸与压缩。
- **材质**：基材用 `resources/materials/` 模板，实例只改参数；emissive 一律取 `RESONANCE_GLOW`/`THREAT` Token，不写 hex。
- **语义色**：全项目仅从 `color_tokens.tres` 取色（含 CVD 热切换），架构 lint（`tools/lint_hex_literals.gd`）拦截散落 hex。
- **git**：`art/` 源走 LFS（架构 §12.2）；`*.import` 必须入库。

---

## 4. 一致性勾稽
| 本规格 | 美术圣经 | 架构 | ColorTokens | 对齐点 |
|---|---|---|---|---|
| §1.3 四材质 | §4.2 材质库方向 | §6.3 材质规范 | — | roughness/metalness/gi_mode 三处一致 |
| §1.1 浮岛/植被/神龛 | §6 环境语言（倒泪滴、human scale、星花）| §2.2 场景树 | — | 岛屿构成与场景职责纪律一致 |
| §1.4/§1.5 VFX·Shader | §8 VFX 与着色器方向 | §6.1 Compositor 栈 / §6.2 共鸣潮汐 / §6.3 Rim | — | 7 项 VFX + 3 Shader 逐一对齐 |
| §2 预算 | §8.1 LOD 纪律 | §7.2/§7.3 性能预算 | — | draw call/三角/粒子/CPU/GPU 全对齐 |
| §3.1–3.3 管线 | §4.3 ORM/Fresnel | §2.1 目录 / §6.3 ORM / §9 ColorTokens | Token 名 | 目录、命名、gi_mode、语义色单源一致 |
| 全语义色 | §2 色板 | §9 色源 | **本规格引用 Token 名** | `THREAT`/`RESONANCE_GLOW`/`FRIENDLY_*` 严格一致，THREAT 不变 |

---

## 5. 风险与开放项（不阻塞 Phase 4）
- **RISK-PERF-1**（架构 §7.5）：60Hz tick+插值使键鼠延迟贴近 50ms 红线——本规格不涉逻辑，但高刷下相机/插值纪律（架构 §7.4）须在美术资产 LOD 偏置上配合，避免抖动。
- **`[GAP]` 共鸣潮汐周期**（架构 §6.2 G6）：6–8min 为建议值，待与主理人/文策渊确认氛围节奏。
- **色盲切换**：本规格所有资产经 `color_tokens_cvd.tres` 天然全覆盖（架构 §9）；`ChaosGlitch.intensity` 接可访问性 Standard 滑块（美术 §9.3）。
- **THREAT 纪律**：敌人/混沌专属，任何资产不得让 `#A62C6B` 外溢到中立/友方（ColorTokens §0）。
