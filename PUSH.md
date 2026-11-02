# 推送到 GitHub

这台机器上目前**没有安装 Git**，而且当前网络到 GitHub 不通（`github.com` 被解析到 198.18.x 代理地址、连接被拒）。
所以仓库已经整理好，按下面任一方式推送即可。

## 方式 A：网页上传（最省事，不需要 Git）

1. 打开 GitHub，新建仓库（例如 `campus-hollow`，不要勾选自动生成 README）。
2. 把本目录打成 zip（或直接用同级目录的 `harvest-hollow-repo.zip`）。
3. 在仓库页面点 **Add file → Upload files**，把解压后的全部文件拖进去，提交。

## 方式 B：命令行（装好 Git 后）

```powershell
# 1) 安装 Git（需要网络）：winget install --id Git.Git -e
# 2) 进入本目录
cd C:\Users\Jasmine\harvest-hollow-repo

git init
git add .
git commit -m "Campus Hollow 2D: pixel-art campus (layout + procedural art + tests)"
git branch -M main

# 3) 关联你的仓库（把 <你的用户名>/<仓库名> 换掉）
git remote add origin https://github.com/<你的用户名>/<仓库名>.git

# 4) 推送（第一次会要求登录：用 GitHub 用户名 + Personal Access Token 当密码）
git push -u origin main
```

> 如果仓库已经有提交（比如建库时勾了 README），先 `git pull --rebase origin main` 再 `git push`。

## 仓库内容说明

- `project.godot`：Godot 4.7 工程（2D 像素校园）
- `scenes/`、`scripts/`：主场景、世界生成、玩家、NPC、HUD
- `data/estate.json`：整张校园的布局数据（建筑/道路/树/球场/池塘/花园）
- `assets/`：外部素材覆盖说明（可选）
- `dev/`：无头自检 `test_game.tscn` 与截图 `capture.tscn`
- `screenshots/`：当前版本截图
- 已排除：`.godot/`（引擎缓存）、`.shots/`、`.backup-*`、`addons/terrain_3d/`、`demo/`、`harvest/`（与本项目无关的第三方插件/旧实验）

## 自检

```powershell
godot --headless --path . res://dev/test_game.tscn
```

应输出 `ALL TESTS PASSED`。
