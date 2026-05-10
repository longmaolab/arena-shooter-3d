# Arena Shooter 3D

第一人称多人对战 FPS。Godot 4.6 + WebSocket + 18 个 Kenney 方块小人。**浏览器、手机都能玩**。

🎮 **现场玩**(24h 在线):**https://game.boobank.com/arena-shooter/**
🏠 **门户首页**(所有游戏):https://game.boobank.com/(由 [longmaolab/portal](https://github.com/longmaolab/portal) 仓库托管)
🌐 **服务器**:Vultr Tokyo + Caddy + Cloudflare 命名隧道,固定不变

## 怎么玩

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 | 切武器 |
|---|---|---|---|---|---|---|
| 电脑 | WASD | 鼠标 | 空格 | 左键 | R | 1 / 2 / 3 |
| 手机 | 左下虚拟摇杆 | 右半屏滑动 | 蓝键 JUMP | 红键 FIRE | 黄键 RELOAD | PIS / SMG / SHG 三个小键 |

主菜单两个按钮：
- **▶ PLAY** —— 上线对战，连 wss://game.boobank.com 跟朋友打
- **🤖 PLAY vs BOTS** —— 选 1/2/3 个 bot 单机练习（网页版纯本地，桌面版顺便也是 LAN host）

游戏内：
- 18 个方块小人（< / > 切换），随机起一个
- **3 把武器**：手枪（重而准）/ SMG（中庸默认）/ 霰弹（近战王）
- **爆头 2 倍伤害**，准心瞄头会飘 "HEAD! -50" 红字
- **连击播报**：连杀 2/3/5/7 次屏幕中央闪 DOUBLE / TRIPLE / RAMPAGE / GODLIKE
- **地图道具**：3 跳板（弹高）+ 1 血包（桥上）+ 1 血包（西南） + 2 弹药箱（隧道 / 东北）
- 胜利条件：**先到 10 杀**，结束后 5 秒倒计时下一局

## 项目结构

```
arena-shooter-3d/
├── project.godot           Godot 项目入口
├── export_presets.cfg      Web 导出预设
├── run_server.sh           本地调试用:启动 Mac 上的 dedicated 服务器
├── deploy.sh               ⭐ 一键发布:git push + 通知服务器 git pull + 重启
├── OPERATIONS.md           ⭐ 日常运维速查(必看)
├── SERVER_GUIDE.md         全栈架构 + 一次性搭建步骤
├── docs/                   Web 客户端构建产物
│   ├── index.html / .wasm / .pck …
│   └── server.json         ← wss://game.boobank.com/arena-shooter/ws
├── audio/                  音效（射击 / 命中 / 死亡 / 复活，CC0 Kenney）
├── models/characters/      Kenney 方块角色（18 个 GLB + 18 张贴图 + 缩略图）
├── scenes/
│   ├── main_menu.tscn      主菜单 + 选角色界面
│   ├── game.tscn           竞技场地图
│   ├── player.tscn         联网玩家
│   ├── hud.tscn            HUD + 计分板 + 死亡黑屏 + 击杀提示
│   └── touch_controls.tscn 手机虚拟摇杆
└── scripts/
    ├── input_setup.gd      autoload：键盘映射
    ├── network_manager.gd  autoload：联网状态 / 房间列表 / 玩家信息
    ├── stats_store.gd      autoload：本地持久化排行榜
    ├── main_menu.gd        主菜单 + 选角色 + server.json 自动加载
    ├── game.gd             场景调度 / 计分 / 新开局 / dedicated 模式
    ├── player.gd           玩家移动 / 射击 / 动画 / 音效 / 换肤
    ├── hud.gd              HP / 弹药 / 计分榜 / 击杀提示 / 死亡红屏
    └── touch_controls.gd   虚拟摇杆 + 滑动看 + 三按钮
```

---

## 本机调试（不联网）

1. Godot 4.6 打开 `project.godot`
2. **调试 → 运行多个实例 → 2**
3. ⌘+B 同时开两个窗口
4. 窗口 1：**PLAY vs BOTS**（变本机 host，:7777）
5. 窗口 2：直接点 **PLAY** —— 编辑器调试时 IP 框已自动填 `ws://127.0.0.1:7777`

---

## 让同学联机(已 24h 在线,啥都不用做)

```
[Vultr Tokyo 服务器]                            [玩家手机/电脑]
──────────────────                             ──────────────
arena-game.service (Godot :7777)                  浏览器打开:
caddy.service     (反代 :80,静态 + WS 同域)      ←── wss:// ──   game.boobank.com/arena-shooter/
cloudflared.service (CF 命名隧道)
                  ↓
        游戏一直在 → game.boobank.com
```

直接把链接发给同学:
```
https://game.boobank.com/arena-shooter/
```

服务器 24h 跑,Mac 关机也不影响。详细架构和搭建过程见 [SERVER_GUIDE.md](SERVER_GUIDE.md);
日常运维命令速查见 [OPERATIONS.md](OPERATIONS.md)。

## 本地调试 + 测试服(可选)

只想本地两个窗口对打,跟"本机调试"一节一样。
想用 Mac 临时当服务器(比如服务器维护时):

```bash
./run_server.sh                          # 终端 1
cloudflared tunnel run arena-shooter     # 终端 2
```
**注意**:Mac 上 cloudflared 会和服务器一起注册到同一个隧道,Cloudflare 自动 HA 路由。
不想分流就别同时跑。

---

## 修改游戏

| 想改什么 | 改哪个文件 |
|---|---|
| 玩家速度 / 满血量 / 跳跃 / 换弹时间 / 武器属性 | `scripts/player.gd` 顶部常量 + `WEAPONS` 数组 |
| **武器伤害（爆头/普通）**——服务器权威 | `scripts/game.gd::SERVER_WEAPON_DAMAGE` |
| 胜利条件 / 新局倒计时 / 复活冷却 / 复活无敌时长 | `scripts/game.gd` 顶部常量 |
| Bot AI 行为（巡逻范围、开火间隔等） | `scripts/player.gd` 的 `BOT_*` 常量 + `_bot_tick` |
| 最大玩家数 / 端口 / 颜色 | `scripts/network_manager.gd` |
| 地图布局 / 桥 / 隧道 / 跳板位置 | Godot 里打开 `scenes/game.tscn`，拖 CSGBox3D / Pickups |
| 道具数量 / 复活时间 | `scripts/pickup.gd` 顶部 + `scenes/game.tscn` 的 Pickups 节点 |
| 主菜单外观 | `scenes/main_menu.tscn` + `scripts/main_menu.gd` |
| 计分板 / HUD / 连击横幅 | `scripts/hud.gd` + `scenes/hud.tscn` |
| 触屏按键位置 | `scripts/touch_controls.gd` 里的 `_recalc_layout()` |

## 重新发布

每次改了代码:

```bash
# 1) Godot 里:项目 → 导出 → Web → 导出项目(覆盖 docs/)
# 2) 一行发布
./deploy.sh
```

`deploy.sh` 会:`git commit + push` → ssh 到服务器 `git pull` → `systemctl restart arena-game`。
**5 秒后玩家硬刷新即可看到新版本**(不再依赖 GitHub Pages 缓存)。

---

## 进阶 / TODO

- [x] ~~角色走路 / 待机动画~~(v6)
- [x] ~~死亡音效 + 击杀提示~~(v6)
- [x] ~~排行榜 + 持久化数据~~(v6,本地存档)
- [x] ~~永久服务器 URL~~(`game.boobank.com`)
- [x] ~~24h 在线服务器~~(Vultr Tokyo + systemd 自启)
- [x] ~~多游戏门户~~([game.boobank.com](https://game.boobank.com))
- [x] ~~垂直地图（桥、隧道、跳板、阶梯）~~(v6.6)
- [x] ~~爆头 + 飘字伤害~~(v6.7)
- [x] ~~血包 / 弹药箱 / 跳板~~(v6.8)
- [x] ~~3 把武器（手枪 / SMG / 霰弹）切换~~(v6.9)
- [x] ~~连击播报（DOUBLE KILL / GODLIKE）~~(v6.10)
- [x] ~~Bot 单人模式（网页版也能打）~~(v6.11–v6.13)
- [x] ~~复活智能选点（远离敌人）+ 死亡冷却~~(v6.13.2 / v6.17)
- [ ] 多房间系统（房间码加入）
- [ ] 多张地图轮换
- [ ] 武器后坐力 / 摄像机 bob
- [ ] 队伍模式（红蓝分队，友军免伤）

## 版本里程碑

| 版本 | 内容 |
|---|---|
| v5  | 联机 PvP MVP |
| v6  | 角色动画 / 音效 / 击杀提示 / 排行榜 |
| v6.6  | 立体地图（中央桥 + 阶梯 + 东侧隧道 + 跳跃平台） |
| v6.7  | 爆头判定（服务器验证）+ 飘字 -25 / HEAD! -50 |
| v6.8  | 跳板（弹高 5m）+ 血包（+50）+ 弹药箱（满弹） |
| v6.9  | 3 把武器切换（PIS / SMG / SHG），各自弹药、爆头伤害表 |
| v6.10 | 连击播报（2 / 3 / 5 / 7 杀阈值） |
| v6.11 | Bot AI（巡逻 → 交战状态机），主菜单选 0–3 个 |
| v6.13 | 网页版可单机 vs Bot（OfflineMultiplayerPeer 兜底）|
| v6.17 | 死亡 2.5s 复活冷却 + RPC 启动错误静默 |

## 致谢

- 角色模型:[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)(CC0)
- 引擎:[Godot 4.6](https://godotengine.org/)
- 音效:[Kenney Audio Pack](https://kenney.nl/assets)(CC0)
- 部署:[Vultr](https://vultr.com/) + [Caddy](https://caddyserver.com/) + [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
