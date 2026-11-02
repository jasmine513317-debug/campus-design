# 外部素材包（assets/）

本项目的画面默认为**程序化像素素材**（`scripts/art/pixel_art.gd` 运行时生成），不依赖任何外部图片，克隆下来就能跑。

但项目已经预留了**外部素材覆盖**接口：把同名 PNG 放进 `assets/sprites/`，运行时会自动替换对应程序化素材。

## 覆盖命名规则

| 文件 | 覆盖对象 | 建议尺寸 |
| --- | --- | --- |
| `tree_oak.png` / `tree_ginkgo.png` / `tree_maple.png` / `tree_plane.png` / `tree_cypress.png` / `tree_cherry.png` / `tree_crabapple.png` / `tree_pine.png` / `tree_willow.png` / `tree_bamboo.png` | 树 | 16–48 px 宽，底部对齐 |
| `prop_bench.png` / `prop_lamp.png` / `prop_bin.png` / `prop_sign.png` / `prop_boat.png` / `prop_bell.png` / `prop_stele.png` / `prop_fountain.png` / `prop_flagpole.png` / `prop_bike_rack.png` / `prop_planter.png` | 道具 | 16–190 px 宽 |
| `player_*.png` 等角色图 | 暂未接入（人物按衣服颜色动态生成） | — |

树和道具图请保持**透明背景、像素对齐（无抗锯齿）**，底部居中对齐；导入后在 Godot 里把 Texture 的 Filter 设为 Nearest（项目已全局设为 nearest）。

## 可用的免费素材来源（需自行下载）

> 本环境的出网被限制（`godotengine.org`、`store.godotengine.org`、`itch.io`、`raw.githubusercontent.com` 在本机都解析到内网地址），所以我无法替你下载。以下是我按“像素校园/俯视角”筛选过、许可证允许免费使用的来源，下载后按上表改名即可直接生效：

1. **Kenney — Tiny Town / Tiny Dungeon / Roguelike RPG Pack**（CC0，可商用、无需署名）
   `kenney.nl/assets` 里搜索 "Tiny Town"、"RPG Urban Pack"，16×16 地砖与俯视建筑最贴合本项目。
2. **Kenney — Pixel Platformer / Pixel Shmup**（CC0）：适合补充图标、路牌、树木。
3. **OpenGameArt — LPC / Tiny 16 系列**（多为 CC0 或 CC-BY-SA，注意逐项看许可证）。
4. **Godot Asset Store** 的 2D 像素分类（如 "Free - Pixel Art Asset Pack - Sidescroller Fantasy"）——侧视素材，可用其树木/道具，地砖需自行裁切。

## 许可提醒

- CC0：可自由使用、修改、商用，建议仍保留来源说明。
- CC-BY / CC-BY-SA：必须在项目 `README` 或 credits 里署名，SA 还要求衍生作品同协议。
- 商用前请再确认一次素材页的许可声明。
