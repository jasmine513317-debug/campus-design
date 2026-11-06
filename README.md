# Campus Hollow · 秋日来信

以校园总平面为基础的 Godot 像素漫游游戏。保留教学楼、操场、体育区、行政庭院和国际学院；以温暖的田园像素色彩重新绘制校园，所有素材由项目内代码生成。

使用 **Godot 4.7+** 打开 [project.godot](project.godot)，按 **F5** 运行。

## 校园布局修订

- 移除左侧从下向上第二栋原 C3 楼；保留 C1、C2、C4 三栋 U 形楼，调整为等间隔的三座扩大庭院，以两条玻璃连廊连接。
- 沙船扩大为 256×200 像素素材，保留沙堆，增加桅杆、双白帆、帆缝、横桁、索具、木肋和铜钉；同步扩大实体碰撞。
- 原独立直跑道并入椭圆跑道东侧八条分道，直线段向南北延伸，统一胶面颜色、分道宽度及起终点标记。
- 全校园的仪式中轴采用 `axis_x = 208`：北侧教学楼间通路、四栋成对教学楼、对称行政建筑、中心花园、木铎、校训石和校门保持共轴。
- 行政建筑以居中门厅、等宽双翼和镜像底层组成；建筑入口居中绘制，补充石材转角、窗帘、草坪修剪带和球门网。

[查看 3200×1440 无界面全景](screenshots/campus_panorama.png)

## 美术改造

- **树木与人物**：分簇树冠、叶片高光、分叉树干、树皮和根系；银杏、枫树、樱花与常绿树使用不同调色板。学生增加轮廓、衣服细节与书包口袋。
- **校园铺装**：内路改为暖色错缝石铺步道，外环保留沥青、路缘、车道线和斑马线；X 形步道补充石板接缝。
- **建筑**：青灰屋顶、暖米色立面、陶瓦与砖墙；窗台花箱、金属落水管、屋面细节和统一投影。保留原有五层楼与校园建筑轮廓。
- **庭园**：中央花林增加花簇和草叶；东北庭园改为环形步道、十字通路、凉亭和四片薰衣草花境；池塘增加睡莲与波光，内院湖岸增加石材收边和岩石切面。
- **室内**：木地板、浅绿色石铺走廊、木框窗、盆栽、日光、课桌与校园公告栏。
- **界面**：深青色木框、纸质日历与地图、简洁键盘提示。触控设备继续提供摇杆与互动按钮。
- **氛围**：轻微飘叶、蝴蝶和水面光点；保留昼夜色调。默认使用整数倍率与最近邻过滤，可通过 `+ / -` 调整视野。

## 道路、碰撞与遮挡

- 道路与建筑基础不再相交：E 楼前道路改为绕行，行政楼前支路向南调整。
- 全部植树入口使用同一套限制，避开车道、石铺步道、X 形小径、外围人行道、广场、入口铺装、花坛和其他实体。
- 中央 X 形步道绘制和避树判断共用中心坐标，避免原先的坐标偏移。
- 29 个建筑部分、校门、树木、人物与 17 件室内家具按各自地面基点排序。
- 道具和路灯的碰撞框对齐实际底座；水面、假山、校门柱和室内设施具有碰撞。
- 室外与室内 NPC 都通过 `CharacterBody2D.move_and_slide()` 行走；整条闭环路线经过几何检查。学生迎面相遇会错身避让，交谈时会短暂停留。
- 修复教学 A 楼入口，进入室内后可以返回原门外位置。

## 操作

| 按键 | 功能 |
| --- | --- |
| WASD / 方向键 | 漫步 |
| Shift | 奔跑 |
| 空格 / Enter | 与 NPC、道具或入口互动 |
| + / - | 整数倍率缩放 |
| T | 进入次日清晨 |
| F1 | 显示 / 隐藏键盘提示 |

从教学 A 楼南面中央玻璃门附近朝上互动，可进入教室；在室内南门朝下互动离开。

## 验证

Windows PowerShell 一键运行全部检查：

```powershell
.\dev\verify.ps1 -Godot "D:\app\Godot_v4.7.2-stable_win64_console.exe"
```

也可以单独运行：

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script res://dev/test_art.gd
godot --headless --path . res://dev/test_game.tscn
godot --headless --path . --script res://dev/test_world_safety.gd
godot --headless --path . --script res://dev/test_interior_safety.gd
godot --headless --path . --script res://dev/test_interior_transition.gd
```

检查涵盖地图、区域识别、相机、NPC 移动、全部树木的步道避让、道路与楼体交叉、道具底座、完整 NPC 路线、建筑与家具排序、高速位移碰撞、室内入口和出口。

生成真实游戏截图到 `.shots/`：

```powershell
godot --path . --resolution 1280x720 res://dev/capture.tscn
godot --path . --resolution 1280x720 res://dev/capture_interior.tscn
godot --path . res://dev/capture_panorama.tscn
```

本次改造的预览保存在 [screenshots/](screenshots/)。

## 结构

| 文件 | 作用 |
| --- | --- |
| `data/estate.json` | 校园平面、道路、建筑、绿化和道具 |
| `scripts/world/estate_map.gd` | 地表、布局、避树、碰撞和互动 |
| `scripts/art/pixel_art.gd` | 像素图集、树木、人物和道具 |
| `scripts/art/campus_building.gd` | 建筑立面与屋面渲染 |
| `scripts/art/campus_gate.gd` | 校门遮挡层 |
| `scripts/art/interior_furniture.gd` | 室内家具遮挡层 |
| `scripts/world/campus_atmosphere.gd` | 飘叶、蝴蝶和水面高光 |
| `scripts/world/teaching_interior.gd` | 教学楼内部布局与碰撞 |
| `scripts/world/npc_student.gd` | 有碰撞的学生角色 |
| `scripts/ui/hud.gd` | 日历、地图、互动与触屏控制 |

还可以将同名 PNG 放入 `assets/sprites/` 覆盖程序化素材，参见 [assets/README.md](assets/README.md)。
