# 美术规格 · 卡池人物样本模型（Sample / Placeholder Models）

> 版本 v0.1 ｜ 作者 林绘澄（主理人降级直写，因 agent 网络中断）
> 引擎 Godot 4.7-stable 3D ｜ 工程根 `game/`
> 上游：`design/color-tokens.md`（语义色唯一真理源）、`design/gdd/systems/gacha.md`、`game/resources/enemy_defs/*.tres`
> **本文件 = 用户需求「不同的卡池人物样本模型」的可审阅蓝图。样本模型 = 仅用 Godot 基础图元 + StandardMaterial3D 做出可区分占位体，非最终美术。**

---

## §0 铁律（必须遵守）

- `THREAT = #A62C6B` **仅敌/混沌专属**，任何玩家/友方/卡池角色**不得**使用品红。
- 友方/玩家角色使用非 THREAT 色：`PLAYER_ALLY_MAIN #5FD2C8`（星辉青）、`RESONANCE_GLOW #9FF7E8`、`FRIENDLY_GOLD #F2C15E`、`FRIENDLY_CORAL #FF8A65`、`SKY_AZURE #3E6FB0`。
- 敌人使用 `THREAT #A62C6B`（主威胁色）+ 暗调辅助。
- 可访问性（F1）：**不靠颜色唯一区分**——每角色叠加**独特轮廓 + 形状/图标注记**。

---

## §1 样本模型构建规则（工程共识）

- 全部用 Godot 基础 `Mesh`：`CapsuleMesh / BoxMesh / CylinderMesh / SphereMesh / ConeMesh / TorusMesh`。
- 材质：`StandardMaterial3D`；友方用哑光（roughness 0.7）+ 角色标志色 albedo；终态辉光用 `emission = RESONANCE_GLOW` + Bloom。
- 待机动画（确定性、低开销，避免穿模）：
  - **浮动 bob**：`position.y = base_y + sin(t * speed) * amp`（amp 0.05–0.15）。
  - **慢转 rotate**：`rotation.y += delta * 0.5`。
  - **缩放脉冲 pulse**：`scale = base * (1 + sin(t*2)*0.03)`。
- 角色根节点 `CharacterModel`（继承 `Node3D`），提供 `_set_archetype(id)` 按配置切换轮廓/配色，供 Roster 实例化复用。

---

## §2 卡池角色样本（8 名）

> 标志色取自 tokens；职阶内靠配色 + 轮廓细节区分；同职阶角色（如两风追、两磐盾、两谐律）靠**帽/翼/环**等差异件 + 色相微调区分。

| 角色 id | 职阶 | 轮廓 Silhouette | 标志色 (hex) | 材质 | 缩放 | 待机 | 辨识注记 |
|---|---|---|---|---|---|---|---|
| `ash_acolyte` 灰烬学徒 | BLADE | Capsule 躯干 + Cone 尖帽 + 细长 Box 剑 | `FRIENDLY_GOLD #F2C15E` | 哑光 | 1.0 | bob+rotate | 尖帽 + 单手长剑，瘦高 |
| `oath_guard` 誓锁守卫 | BULWARK | 宽 Box 躯干 + 大 Sphere 肩甲 + Cylinder 塔盾 | `SKY_AZURE #3E6FB0` | 金属(metallic 0.6) | 1.15 | bob 慢 | 方正宽厚 + 圆形塔盾，最"重" |
| `swift_ranger` 迅羽游侠 | WINDCHASER | Capsule + 两片 Cone 背翼 + 细 Cylinder 长枪 | `FRIENDLY_CORAL #FF8A65` | 哑光 | 0.95 | pulse 快 | 背后双翼 + 长枪，轻盈 |
| `gale_echo` 疾风回响者 | WINDCHASER | Capsule + 双 Cone 翼（半透明 emissive）+ 头 Torus 环 | `RESONANCE_GLOW #9FF7E8` | 哑光+emissive 翼 | 0.95 | pulse 快+rotate | 翼半透明发光 + 头顶光环，区别于游侠 |
| `bulwark_heart` 磐心卫士 | BULWARK | 宽 Box + Sphere 心形标志(双球) + Cylinder 短盾 | `SKY_AZURE #3E6FB0` 偏深 | 金属 | 1.15 | bob 慢 | 胸口双球"心" + 短盾，区别于守卫 |
| `resonant_hierophant` 谐律主祭 | RESONANT | 高 Capsule + 大头 Torus 光环 + 手持 Torus 法杖 | `RESONANCE_GLOW #9FF7E8` | emissive 光环 | 1.05 | rotate | 大头光环 + 法杖环，最"神职" |
| `voidblade_lord` 断空剑主 | BLADE | Capsule + 无帽 + 双 Box 交叉巨剑 + 暗金描边 | `FRIENDLY_GOLD #F2C15E` 偏深 + 黑描边 | 哑光+emissive 剑刃 | 1.0 | bob+rotate 慢 | 交叉巨剑 + 黑金描边，区别于学徒的尖帽细剑 |
| `resonant_singer` 共鸣歌者 | RESONANT | 中 Capsule + Sphere 发束 + 胸前 Sphere 共鸣核 | `RESONANCE_GLOW #9FF7E8` 偏暖 | emissive 核 | 1.0 | pulse | 胸前发光共鸣核 + 发束，区别于主祭的光环法杖 |

> 职阶轮廓语言：BLADE=剑系瘦高 / BULWARK=宽厚盾系 / WINDCHASER=翼系轻盈 / RESONANT=光环/核系神职。玩家一眼可辨职阶，再靠细节辨具体角色。

---

## §3 玩家 Avatar 样本

- 轮廓：Capsule 躯干 + Sphere 头 + 细 Cylinder 双臂（中性人形），标志色 `PLAYER_ALLY_MAIN #5FD2C8`（星辉青）。
- 材质：哑光 + 微弱 `emission` 青。
- 待机：bob + 极慢 rotate。
- 辨识：全身星辉青，与所有敌人（THREAT 品红）形成强对比，且异于卡池角色的暖金/珊瑚/天蓝。

---

## §4 敌人样本（4 + Boss）

| id | 轮廓 Silhouette | 标志色 | 材质 | 缩放 | 待机 | 辨识注记 |
|---|---|---|---|---|---|---|
| `brute` | 大 Box 方体 + 小 Sphere 头 + 粗 Cylinder 臂 | `THREAT #A62C6B` | 哑光暗 | 1.2 | 微 bob | 方正巨型，品红主色 |
| `skirmisher` | 细 Capsule + Cone 尖 + 长 Cylinder 矛 | `THREAT #A62C6B`（偏亮） | 哑光 | 0.9 | pulse 快 | 瘦高敏捷，矛长 |
| `sentinel` | Capsule + 头顶 Box 警示牌 + 慢转 | `THREAT #A62C6B` + 黄黑警示边(`FRIENDLY_GOLD`) | 哑光 | 1.0 | rotate | 头顶警示牌（标记弱点×2 语义），转体慢 |
| `boss_warden` | 超大 Box + 双 Sphere 肩 + 顶部 Cone 冠 | `THREAT #A62C6B`（深）+ emissive 脉冲 | 金属+emissive | 2.0 | 慢 pulse | 体型碾压级 + 冠 + 周期品红脉冲（Boss 威胁语义） |

> 敌人**全部**使用 THREAT 品红（含 Boss 脉冲），确保"红=敌"铁律一致；sentinel 的警示牌用暖金辅助表达"弱点"语义但不喧宾夺主。

---

## §5 美术方向注记（样本 → 最终美术的演进）

- 本样本集是**占位验证层**：确认 8 角色 + 玩家 + 敌人可在 3D 场景中可区分、可实例化、可注入数值。
- 演进路径（不阻塞 v1 可玩验证）：图元 → 替换为绑定网格（共用同一骨骼集，gacha.md §8 待批项 2）→ 材质升级 PBR → 特效（终结技/召唤演出）。
- 轮廓语言（职阶）在最终美术中保留，仅替换几何精度；配色严格沿用 `color-tokens.md`。

---

## §6 工程交付清单（程基岩）

| 产出 | 路径 | 说明 |
|---|---|---|
| 角色模型构建器 | `game/src/art/character_model.gd`（`class_name CharacterModel extends Node3D`） | 按 `character_id` / `archetype` 配置生成图元组合 + 材质 + 待机动画；从 Roster 实例化 |
| 敌人模型构建器 | 复用 `CharacterModel` 或独立 `enemy_model.gd` | 按 `enemy_id` 生成 THREAT 色样本 |
| 假人资源 | `game/resources/enemy_defs/dummy.tres` | 高 hp、不反击、不移动 |
| 材质/色引用 | 统一读 `ColorTokens` 常量 | 禁止 hex 字面量（尤其 THREAT） |

> 变更记录：v0.1 — 依用户「不同的卡池人物样本模型」需求，由主理人降级直写（agent 网络中断）。
