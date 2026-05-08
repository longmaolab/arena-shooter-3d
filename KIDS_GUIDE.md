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

---

# 📖 附录：这个游戏是怎么做出来的

> 这部分是爸爸和 AI 助手（Claude）一路对话做出来的"项目复盘"。看完你就能明白每个决定为什么这么选，以后想自己做类似的游戏，可以照着这个思路走。

## A1. 一开始想做什么

爸爸问 AI：**"我儿子 12 岁，对 Python 和 Scratch 都熟了，还很会玩对战类游戏，想找个进阶方向。"**

讨论过几个选项：

| 选项 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| **UE5 / Unreal Editor for Fortnite** | 商业级画质、Fortnite 同款工具 | 学习曲线极陡、对电脑配置要求高、Verse 语法对小学生不友好 | 暂缓 |
| **继续 Pygame** | 已经会了 | 2D 局限、不联网难做对战 | 已会，要进阶 |
| **Godot 4 (3D)** | 开源免费、轻量、GDScript 语法像 Python、官方文档全 | 比起 UE5 画质弱一些 | ✅ **选这个** |
| **HTML5 / Three.js** | 浏览器里直接玩 | JavaScript 比 GDScript 复杂 | 太底层 |

**最终决定：Godot 4 + 3D + 第一人称射击 + 多人对战**。

## A2. 整个项目分了几个版本

```
v1  → 单机 FPS（自己 vs AI 怪），先跑通基础
v4  → 本想做分屏，跳过（单设备双手柄太奇怪）
v5  → 联机 PvP（核心功能上线）
v6  → 加动画 + 音效 + 击杀提示 + 排行榜
v6.1→ 修 bug + 优化射击手感 + 随机默认身份
```

每个版本都是**可玩的成品**，不是半成品。这是关键原则：**永远保持游戏能跑，再加新东西**。

## A3. 关键技术决定（为什么这么选）

### 决定 1：用 WebSocket 而不是 ENet 做联网

- **ENet** 是 Godot 默认的联网协议，UDP 快，但浏览器**不能用**
- **WebSocket** 慢一点点（毫秒级），但**网页版和原生版同一套代码**就能跑

> 取舍：手机网页 / 朋友家电脑都能玩 > 极致延迟。**先能玩到，再想优化**。

### 决定 2：服务器权威架构（Server-Authoritative）

每次开枪、扣血、计分，都要让**服务器**说了算，客户端只是显示。

```
玩家A按下鼠标
  ↓ 客户端先播音效 + 弹道（看起来很流畅）
  ↓ 同时 RPC 给服务器："我打中了 B"
  ↓ 服务器验证 → 给 B 扣血 → 广播给所有人
  ↓ 大家看到 B 的血条变化
```

为什么这么做？因为如果让客户端直接扣别人血，**作弊就太容易了**——改个本地代码就一枪秒杀。

### 决定 3：用 Kenney CC0 模型，不自己建模

- **Kenney.nl** 上有 18 个免费方块小人，自带 27 个动画（待机/走路/冲刺/死亡/射击）
- 全部 CC0 协议（**完全免费，可以商用，不用署名**）
- 自己用 Blender 建模 + 绑骨 + 做动画大概要 2 周

> 设计原则：**别造轮子。能用现成的就用现成的，把时间花在游戏玩法上。**

### 决定 4：服务器跑在爸爸 Mac 上 + Cloudflare Tunnel 暴露公网

- 云服务器（Fly.io、AWS）要绑信用卡，且每月有钱
- **Cloudflare Tunnel** 免费、不要信用卡、给你一个公网地址
- 流程：朋友的浏览器 → `wss://game.boobank.com` → Cloudflare → 你 Mac 的 7777 端口

代价：**Mac 不开机就停服**。可以接受。

### 决定 5：网页版托管在 GitHub Pages

- GitHub 给每个用户一个免费网址：`https://用户名.github.io/项目名/`
- 每次 `git push` 之后大概 1 分钟自动上线
- 0 元、0 配置、足够稳

## A4. 一路踩过的坑（你以后可能也会遇到）

### 坑 1：写好代码 Godot 报红 `Identifier not found: NetworkManager`

**原因**：`NetworkManager` 是个 autoload（全局单例），需要在 **项目 → 项目设置 → Autoload** 里注册才能让别的脚本看到。

**教训**：autoload 名字必须先注册，再用。

### 坑 2：联机时玩家 A 能看到 B，但开枪打不死

**原因**：服务器权威架构里，客户端 A 调用 `respawn_player.rpc_id(B)`，但 RPC 的 `call_remote` **不允许打给自己**。当 A == 服务器（Host）时，对自己 rpc_id 会报错。

**修法**：把 `call_remote` 改成 `call_local`，让本机也执行同样的逻辑。

**教训**：**RPC 的语义"在哪个机器上跑"要想清楚**：
- `call_local` = 本机也跑
- `call_remote` = 只在别人那跑
- `authority` = 只服务器能发起
- `any_peer` = 谁都能发

### 坑 3：浏览器里中文显示成方块（口口口口）

**原因**：Godot Web 导出**不会自带中文字体**（CJK 字体太大，会让 wasm 文件爆炸）。

**修法**：菜单文字全改成英文。中文文字塞在玩家名字（用户输入）和 README 文档里。

**教训**：**网页版要照顾字体大小**，能用英文就用英文。

### 坑 4：浏览器 Host 报错 `Host failed: 22`

**原因**：浏览器**不能监听 socket**（安全限制），所以网页版不能当服务器。

**修法**：网页版的 Host 按钮**直接禁用**，按钮文字改成 "Host (desktop only)"。

**教训**：**先搞清楚目标平台的能力边界**——浏览器能做什么、不能做什么。

### 坑 5：朋友的浏览器一直 404 `server.json`

**原因**：HTTPRequest 用相对路径 `"server.json"` 时，**浏览器会从域名根解析**，而不是从子路径 `/arena-shooter-3d/`。

**修法**：用 `JavaScriptBridge.eval(...)` 直接读 `location.pathname` 拼绝对地址。

**教训**：**子路径下的网页要小心相对路径**。Godot 客户端代码看起来"是在加载本地文件"，但其实是浏览器代发的 HTTP 请求。

### 坑 6：服务器开不起来，提示 `port already in use`

**原因**：上次 Godot 进程没退干净，端口 7777 还被占着。

**修法**：在 `run_server.sh` 顶部加自动清理：
```bash
existing_pids=$(lsof -nP -tiTCP:7777 -sTCP:LISTEN)
if [ -n "$existing_pids" ]; then kill $existing_pids; sleep 1; fi
```

**教训**：**写脚本时考虑前一次没退干净的情况**。

### 坑 7：换上 Kenney 角色后，子弹打不中人了

**原因**：Kenney 的 GLB 模型每个肢体（手/脚/头）**都自带 StaticBody3D 碰撞体**。射线先撞到这些子节点，根节点的 `CharacterBody3D` 反而判定失败。

**修法**：射线击中后**沿父节点向上找**，直到找到 player 根：
```gdscript
func _find_player_root(node: Node) -> CharacterBody3D:
    var n: Node = node
    while n:
        if n is CharacterBody3D and n.is_in_group("player"):
            return n
        n = n.get_parent()
    return null
```

**教训**：**第三方模型导入后要先看一眼场景树**，看它带了哪些隐藏的子节点。

### 坑 8：动画没生效

**原因**：Kenney GLB 自带 `AnimationPlayer`，但默认动画**不循环**（idle/walk 都只播一次就停了）。

**修法**：导入后遍历动画，把循环类的设成 `LOOP_LINEAR`：
```gdscript
for n in _anim_player.get_animation_list():
    if n in ["idle", "walk", "sprint"]:
        _anim_player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
```

**教训**：**动画系统的细节（循环模式、过渡、混合）经常是"看不见的坑"**。

### 坑 9：枪口火光太丑（一闪而过的方块）

**原因**：最早用 BoxMesh 做枪口火光，scale 2.5x → 看起来像个**会跳出来的黄色方块**。

**修法**：换成 SphereMesh + 材质 emission 渐隐 + unshaded shading。再配合弹道轨迹（tracer，从枪口画到命中点的细线）。

**教训**：**视觉反馈不是越亮越好，是要"自然"**。渐变 > 硬切。

## A5. 怎么自己做一个类似的游戏

如果你想从零做一个差不多的，建议这个顺序：

### 阶段 1：先让自己一个人能玩（1-2 周）

1. 学 Godot 4 基础：节点 / 场景 / 脚本（官方教程 "Your First Game" 走一遍）
2. 做一个 3D 场景：地面、几个箱子、一个第一人称玩家（CharacterBody3D + Camera3D + RayCast3D）
3. 实现：移动、跳跃、鼠标看视角、按左键发射射线
4. 加血量、弹药、UI 标签

> 这一步**最重要**：单机能玩了，再考虑联机。**永远不要还没单机就想着联机**。

### 阶段 2：加联机（1 周）

1. 注册 `NetworkManager` autoload
2. 用 `WebSocketMultiplayerPeer` 做服务器和客户端
3. 玩家信息用 `multiplayer.peer_connected` 信号同步
4. 关键：**位置同步、射击同步、血量同步**都要走 RPC
5. 本地两个窗口（调试 → 运行多个实例 → 2）测试

### 阶段 3：部署到网页（半天）

1. 项目设置 → Web 导出，路径 `docs/index.html`
2. 在 GitHub 创建项目，把 `docs/` 推上去
3. 仓库设置里启用 GitHub Pages，源选 `main` 分支的 `docs` 文件夹
4. 链接长这样：`https://用户名.github.io/项目名/`

### 阶段 4：加美术 + 音效（1 周）

1. 去 [kenney.nl](https://kenney.nl) 找 CC0 资源
2. 角色模型：blocky-characters
3. 音效：sci-fi-sounds 或 impact-sounds
4. 全部用 `preload()` 加载，性能最好

### 阶段 5：加润色（继续做）

- 击杀提示
- 排行榜
- 持久化（用 ConfigFile 或 JSON 存数据）
- 触屏适配（手机也能玩）

## A6. 给小作者的话

做游戏最大的感受：

1. **先跑通，再优化**。让游戏每个版本都"能玩"，再一点点加东西。
2. **遇到问题先看日志**。Godot 控制台的红字 99% 都告诉你了答案，别绕过去。
3. **抄别人的代码不丢人**。GitHub、Godot 论坛、官方示例项目随便抄。
4. **多用 print 调试**。"程序在哪一步出问题"打印几行就知道。
5. **每次写完一段就 git commit**。出错了 `git diff` 能看出你改了啥，搞砸了 `git checkout` 能回退。

游戏里的 bug 就是迷宫，每解一个你的能力都上一个台阶。**坚持做完一个完整的游戏（哪怕很简单），收获比看 100 个教程都大**。

加油，期待你做出更酷的东西 🚀
