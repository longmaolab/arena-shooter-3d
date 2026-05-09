# Arena Shooter 3D

第一人称多人对战 FPS。Godot 4.6 + WebSocket + 18 个 Kenney 方块小人。**浏览器、手机都能玩**。

🎮 **现场玩**(24h 在线):**https://game.boobank.com/arena-shooter/**
🏠 **门户首页**(所有游戏):https://game.boobank.com/(由 [longmaolab/portal](https://github.com/longmaolab/portal) 仓库托管)
🌐 **服务器**:Vultr Tokyo + Caddy + Cloudflare 命名隧道,固定不变

## 怎么玩

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 |
|---|---|---|---|---|---|
| 电脑 | WASD | 鼠标 | 空格 | 左键 | R |
| 手机 | 左下虚拟摇杆 | 右半屏滑动 | 蓝键 JUMP | 红键 FIRE | 黄键 RELOAD |

- **进入主菜单后先点 < / > 选角色**（18 个方块小人可选：忍者、商人、机器人、骑士…）
- **胜利条件**：先到 10 杀
- **新一局**：每局结束后 5 秒倒计时自动开下一局，分数清零

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
4. 窗口 1 → 选个角色 → Host
5. 窗口 2 → 选不同角色 → Join（IP 默认 127.0.0.1）

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
| 玩家速度 / 血量 / 伤害 / 换弹时间 | `scripts/player.gd` 顶部常量 |
| 胜利条件 / 新局倒计时 | `scripts/game.gd` 顶部常量 |
| 最大玩家数 / 端口 / 颜色 | `scripts/network_manager.gd` |
| 地图布局 | Godot 里打开 `scenes/game.tscn`，拖动 CSGBox3D |
| 主菜单外观 | `scenes/main_menu.tscn` + `scripts/main_menu.gd` |
| 计分板 / HUD | `scripts/hud.gd` + `scenes/hud.tscn` |
| 触屏按键位置 | `scripts/touch_controls.gd` 里的 `_recalc_buttons()` |

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
- [x] ~~永久服务器 URL(Cloudflare 命名隧道)~~(`game.boobank.com`)
- [x] ~~24h 在线服务器~~(Vultr Tokyo + systemd 自启)
- [x] ~~多游戏门户~~([game.boobank.com](https://game.boobank.com))
- [ ] 武器切换(手枪 / 狙击 / 散弹)
- [ ] 多房间系统(房间码加入)
- [ ] 多张地图轮换

## 致谢

- 角色模型:[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)(CC0)
- 引擎:[Godot 4.6](https://godotengine.org/)
- 音效:[Kenney Audio Pack](https://kenney.nl/assets)(CC0)
- 部署:[Vultr](https://vultr.com/) + [Caddy](https://caddyserver.com/) + [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
