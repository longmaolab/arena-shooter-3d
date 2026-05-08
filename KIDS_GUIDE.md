# Arena Shooter 3D — 操作手册

> 给小作者：这是你和朋友一起玩、一起改的多人射击游戏。这份文档把所有要做的事都列清楚了，按顺序看就行。

---

## 🎮 第 1 部分：怎么玩

### 玩家进入游戏

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 |
|---|---|---|---|---|---|
| 电脑 | W / A / S / D | 鼠标 | 空格 | 鼠标左键 | R |
| 手机 | 左下虚拟摇杆 | 右半边屏幕滑动 | JUMP 按钮 | FIRE 按钮 | RELOAD 按钮 |

### 游戏规则

- **目标**：先打到 **10 杀** 的玩家获胜
- **死了会怎样**：原地爆开 → 黑屏 1.5 秒 → 在随机出生点复活，无敌 1.5 秒
- **每局结束后**：5 秒倒计时 → 自动开下一局，分数清零
- **看排行榜**：右上角是本场积分，右下角是总历史排行（爸爸 Mac 上保存）

### 主菜单的两栏

- **左栏**：输入名字、选角色（< / > 翻页，18 个 Kenney 小人）、Host/Join 按钮
- **右栏**：历史排行榜（按胜场排序）

> 第一次启动会自动给你一个英文随机名字 + 随机角色。改过之后下次会记住。

---

## 🚀 第 2 部分：让朋友也能玩（爸爸 Mac 上做）

每次想和朋友玩，都要这两步。**两个终端窗口都要保持开着，玩完才关。**

### 步骤 ① 开服务器

打开一个终端：

```bash
cd /Users/longmao/projects/arena-shooter-3d
./run_server.sh
```

看到 `[server] listening on port 7777` 就是成功了。

### 步骤 ② 开 Cloudflare 隧道

再开一个终端：

```bash
cloudflared tunnel run arena-shooter
```

看到 `Registered tunnel connection` 就是成功了。

### 步骤 ③ 把链接发给朋友

```
https://longmaolab.github.io/arena-shooter-3d/
```

朋友打开 → 选角色 → 点 **Join** → 自动连接！

### 玩完了想关掉

每个终端按一次 `Ctrl + C` 就行。或者一行命令同时关：

```bash
pkill -f "Godot.*--server" && pkill -x cloudflared
```

---

## ✏️ 第 3 部分：改游戏（小修改）

### 在 Godot 里打开项目

1. 打开 Godot 4.6.2
2. 点 **Import** → 选 `/Users/longmao/projects/arena-shooter-3d/project.godot`
3. 进入编辑器

### 改完之后本地测试

- 顶部菜单 **调试 → 运行多个实例 → 2**（这样能开两个窗口模拟两个玩家）
- 按 **⌘ + B** 启动两个窗口
- 窗口 1 选角色 → Host
- 窗口 2 选角色 → Join（IP 默认 127.0.0.1）

### 常见的小修改清单

| 想改什么 | 打开哪个文件 | 改哪一行 |
|---|---|---|
| 跑步速度 | `scripts/player.gd` | `const SPEED := 6.0` |
| 冲刺速度 | `scripts/player.gd` | `const SPRINT_SPEED := 10.0` |
| 跳跃高度 | `scripts/player.gd` | `const JUMP_VELOCITY := 7.0` |
| 满血量 | `scripts/player.gd` | `const MAX_HEALTH := 100` |
| 子弹伤害 | `scripts/player.gd` | `const BULLET_DAMAGE := 25` |
| 满弹夹 | `scripts/player.gd` | `const MAX_AMMO := 30` |
| 换弹时间 | `scripts/player.gd` | `const RELOAD_TIME := 1.4` |
| 多少杀算赢 | `scripts/game.gd` | `const KILLS_TO_WIN := 10` |
| 新一局等多久 | `scripts/game.gd` | `const NEW_GAME_DELAY := 5.0` |
| 最多几个玩家 | `scripts/network_manager.gd` | `const MAX_PLAYERS := 8` |
| 默认随机名字列表 | `scripts/network_manager.gd` | `const COMMON_NAMES := [...]` |

### 改地图

- 在 Godot 编辑器里打开 `scenes/game.tscn`
- 场景树里找 `Arena` 节点下面的 `CSGBox3D` 们
- 拖动它们的位置 / 大小，就能改墙、改地形

---

## 🌐 第 4 部分：改完了让朋友看到新版本

代码改了之后，**网页版不会自动更新**。要做这三步：

### 步骤 ① 在 Godot 里导出

1. 顶部菜单 **项目 → 导出**
2. 选 **Web (Runnable)** → 点 **导出项目**
3. 路径不用改（默认就是 `docs/index.html`）→ 保存
4. 等几秒钟导出完成

### 步骤 ② 清理 Godot 编辑器残留文件

在终端里：

```bash
cd /Users/longmao/projects/arena-shooter-3d
find docs -name "*.import" -delete
```

### 步骤 ③ 推送到 GitHub

```bash
./deploy.sh
```

或者手动：

```bash
git add -A
git commit -m "更新游戏：你做了什么改动写在这里"
git push
```

> 推完大概等 1 分钟，GitHub Pages 才会更新。可以让朋友刷新一下浏览器试试。

---

## 🐛 第 5 部分：常见问题

### Q1：朋友打开网页，点 Join 没反应
- 先确认你 Mac 上的两个终端（服务器 + 隧道）还在跑
- 隧道终端有没有 `Registered tunnel connection`？没有的话再开一次

### Q2：自己开两个窗口测试，第二个 Join 报错
- 第一个窗口必须先点 **Host**，再开第二个
- 第二个窗口的 IP 框里填 `127.0.0.1`（默认就是这个）

### Q3：浏览器里中文显示成方块
- Godot Web 导出不带中文字体，所以菜单里全用英文
- 改菜单文字时记得只用英文 / 数字 / 符号

### Q4：开服务器报错 `port already in use`
- 上次的服务器没关干净
- `run_server.sh` 已经会自动清理，再跑一遍就行
- 万一不行：`pkill -f "Godot.*--server"`

### Q5：子弹打不中人
- 这是已修过的 bug：Kenney 角色身体每个部位（手 / 脚 / 头）都有自己的碰撞体，子弹要沿父节点找到主角色才算命中
- 修复在 `scripts/player.gd` 的 `_find_player_root()` 函数

### Q6：在 Godot 里改了文件，但游戏里没生效
- 文件保存了吗？（标题栏有 `*` 表示没存）
- 试试 **项目 → 重新加载当前项目**
- 如果还不行，关掉 Godot 重新打开

### Q7：手机上键盘弹不出来
- 已经修过：项目设置里开了 `virtual_keyboard_enabled`
- 名字输入框点击之后应该会弹

---

## 📁 第 6 部分：项目里有什么文件

```
arena-shooter-3d/
├── project.godot              ← 用 Godot 打开这个文件
├── README.md                  ← 给开发者看的总文档
├── KIDS_GUIDE.md              ← 你正在看的这份
├── SERVER_GUIDE.md            ← Cloudflare 隧道详细搭建步骤
├── run_server.sh              ← 启动服务器脚本
├── deploy.sh                  ← 部署到 GitHub Pages 脚本
│
├── scripts/                   ← 所有 GDScript 代码
│   ├── player.gd              玩家移动/射击/动画
│   ├── game.gd                游戏规则/计分/换局
│   ├── network_manager.gd     联网/玩家信息/设置
│   ├── hud.gd                 HUD/血条/弹药/击杀提示
│   ├── main_menu.gd           主菜单
│   ├── stats_store.gd         排行榜数据保存
│   └── input_setup.gd         键盘按键映射
│
├── scenes/                    ← 场景文件（用 Godot 打开）
│   ├── main_menu.tscn         主菜单界面
│   ├── game.tscn              竞技场地图
│   ├── player.tscn            玩家
│   ├── hud.tscn               HUD
│   └── touch_controls.tscn    手机虚拟摇杆
│
├── models/characters/         ← 18 个 Kenney 方块小人
├── audio/                     ← 4 个音效（射击/命中/死亡/复活）
└── docs/                      ← 网页版（GitHub Pages 自动发布这里）
```

---

## 🌟 进阶玩法（想挑战）

如果以上的都熟练了，可以试试加新功能：

1. **加新地图**：复制 `scenes/game.tscn` 改名 `arena2.tscn`，主菜单加按钮切换
2. **加武器**：在 `player.gd` 里新增几个常量（伤害、射速），按数字键 `1/2/3` 切换
3. **加道具**：地图上放个红十字方块，碰到回血 50
4. **加房间码**：让朋友输入 4 位数字房间号才能加入
5. **加排行榜表情**：第一名头顶飘个 👑

每加一个功能，先在本地多窗口测试 → 没问题再 export + push。

---

## 🆘 实在搞不定？

把出错的截图发给爸爸，告诉他你点了什么、出了什么错。

游戏开发就是不停遇到问题、解决问题的过程，**第一次都做不对，多试几次就熟了**。

Have fun! 🎯
