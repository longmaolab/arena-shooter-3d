# Arena Shooter 3D

> 📘 English version first. 中文版在文件下半部分 ([跳到中文](#中文)).

A first-person multiplayer arena FPS built in Godot 4.6 + WebSocket, starring
18 Kenney blocky characters. **Plays in any browser, including on phones.**

🎮 **Play live** (24/7): **https://game.boobank.com/arena-shooter/**
🏠 **Game portal** (all games): https://game.boobank.com/ (hosted in [longmaolab/portal](https://github.com/longmaolab/portal))
🌐 **Server**: Vultr Tokyo + Caddy + Cloudflare Named Tunnel, fixed URL

## How to play

| Device | Move | Look | Jump | Shoot | Reload | Switch weapon |
|---|---|---|---|---|---|---|
| Desktop | WASD | Mouse | Space | Left click | R | 1 / 2 / 3 |
| Mobile | Left thumb stick | Right-half drag | Blue JUMP | Red FIRE | Yellow RELOAD | PIS / SMG / SHG chips |

Two big menu buttons:
- **▶ PLAY** — go online, connects to `wss://game.boobank.com` and joins your friends
- **🤖 PLAY vs BOTS** — single player vs 1/2/3 bots (web: fully offline; desktop: also hosts a LAN server)

In-game:
- 18 blocky characters (< / > to switch), one randomly picked on first launch
- **3 weapons**: Pistol (heavy + precise) / SMG (default all-rounder) / Shotgun (close-range king)
- **Headshots deal 2× damage**, red `HEAD! -50` floats up from the impact point
- **Killstreak banners**: 2 / 3 / 5 / 7 consecutive kills trigger DOUBLE / TRIPLE / RAMPAGE / GODLIKE
- **Map pickups**: 3 jump pads + 2 health packs (bridge, SW) + 2 ammo boxes (tunnel, NE)
- **Win condition**: first to **10 kills**, then 5-second countdown auto-starts the next round

## Project layout

```
arena-shooter-3d/
├── project.godot           Godot project entry point
├── export_presets.cfg      Web export preset
├── run_server.sh           Local debug: start a dedicated server on the Mac
├── deploy.sh               ⭐ One-shot deploy: git push → ssh server → pull → import → restart
├── OPERATIONS.md           ⭐ Day-to-day ops cheatsheet (read this)
├── SERVER_GUIDE.md         Full architecture + one-time setup
├── docs/                   Web client build artifacts
│   ├── index.html / .wasm / .pck …
│   └── server.json         ← wss://game.boobank.com/arena-shooter/ws
├── audio/                  SFX (shoot / hit / death / respawn, Kenney CC0)
├── models/characters/      Kenney blocky characters (18 GLBs + textures + previews)
├── fonts/                  Russo One display font
├── themes/                 arena_theme.tres (project-wide font theme)
├── scenes/
│   ├── main_menu.tscn      Main menu + character picker
│   ├── game.tscn           The arena (geometry + Pickups + SpawnPoints)
│   ├── player.tscn         Networked player (CharacterBody3D + Camera + Audio)
│   ├── hud.tscn            HUD: HP card / ammo / scoreboard / kill feed / streak banner
│   └── touch_controls.tscn Mobile thumb stick + buttons
└── scripts/
    ├── input_setup.gd      autoload: key bindings
    ├── network_manager.gd  autoload: connection state / player roster / settings
    ├── stats_store.gd      autoload: persistent leaderboard
    ├── main_menu.gd        Menu logic (PLAY / PLAY vs BOTS / bot count / name)
    ├── game.gd             Scene driver / scoring / kill flow / dedicated mode
    ├── player.gd           Movement / shooting / weapons / animations / bot AI
    ├── hud.gd              HP / ammo / scoreboard / kill banner / streak / vignette
    ├── pickup.gd           Health pack + ammo crate (visuals + pickup logic)
    ├── jump_pad.gd         Jump pad (velocity boost + glowing chevron)
    └── touch_controls.gd   Joystick + drag-to-look + action buttons + weapon chips
```

---

## Local debug (no network)

1. Open `project.godot` in Godot 4.6
2. **Debug → Run Multiple Instances → 2**
3. ⌘+B to launch two windows at once
4. Window 1: click **🤖 PLAY vs BOTS** (becomes the local host on :7777)
5. Window 2: just click **▶ PLAY** — the IP field is pre-filled with `ws://127.0.0.1:7777` in editor builds

---

## Letting friends play (already 24/7 online, nothing to do)

```
[Vultr Tokyo server]                            [Player phone/PC]
──────────────────                              ────────────────
arena-game.service (Godot :7777)                Browser opens:
caddy.service     (reverse-proxy :80,           ←── wss:// ──   game.boobank.com/arena-shooter/
                   static + WS same domain)
cloudflared.service (Cloudflare named tunnel)
                  ↓
        Game is always reachable at game.boobank.com
```

Just share the link:
```
https://game.boobank.com/arena-shooter/
```

The server runs 24/7, so even if your Mac is off, friends can still play.
Full architecture and setup steps in [SERVER_GUIDE.md](SERVER_GUIDE.md);
day-to-day ops commands in [OPERATIONS.md](OPERATIONS.md).

## Mac as backup public server (optional, only when the VPS is down)

> This section is **not** for local play with your kid — local Godot
> debug uses `127.0.0.1` and doesn't need cloudflared at all (see the
> "Local debug" section above). This is only if you want the **Mac to
> stand in for the VPS** as the internet-facing server (e.g. during
> VPS maintenance).

```bash
./run_server.sh                          # terminal 1
cloudflared tunnel run arena-shooter     # terminal 2
```

The Mac's cloudflared and the VPS's cloudflared share the same tunnel,
so Cloudflare will HA-route between them. Don't run both at the same
time unless you mean to split traffic.

---

## Tweaking the game

| What you want to change | Where |
|---|---|
| Player speed / max HP / jump / reload time / weapon stats | `scripts/player.gd` top constants + the `WEAPONS` array |
| **Weapon damage (body / headshot)** — server-authoritative | `scripts/game.gd::SERVER_WEAPON_DAMAGE` |
| Win condition / new-round countdown / respawn delay / invincibility window | `scripts/game.gd` top constants |
| Bot AI behavior (view range, fire interval, etc.) | `scripts/player.gd` `BOT_*` constants + `_bot_tick` |
| Max players / port / colors | `scripts/network_manager.gd` |
| Map layout / bridge / tunnel / jump pad positions | Open `scenes/game.tscn` in Godot, drag the CSGBox3D / Pickups nodes |
| Pickup count / respawn time | `scripts/pickup.gd` top + the Pickups node in `scenes/game.tscn` |
| Main menu look | `scenes/main_menu.tscn` + `scripts/main_menu.gd` |
| Scoreboard / HUD / streak banner | `scripts/hud.gd` + `scenes/hud.tscn` |
| Touch button positions | `scripts/touch_controls.gd` `_recalc_layout()` |

## Re-deploying

After each code change, one command:

```bash
./deploy.sh
```

The script handles everything:
- Detects if any `scripts/` / `scenes/` / `audio/` / `fonts/` / `models/` / `themes/` / `project.godot` is newer than `docs/index.pck`
- If yes → re-exports the web build headlessly (~30-60s)
- If no → skips export (~5s)
- Cleans up `.import` leftovers, commits, pushes, ssh's server, pulls, re-imports, restarts the game server

**Players see the new version after a hard refresh** (~5s without re-export, ~60s with).

---

## Roadmap

- [x] ~~Character walk / idle animations~~ (v6)
- [x] ~~Death SFX + kill feed~~ (v6)
- [x] ~~Persistent leaderboard~~ (v6)
- [x] ~~Permanent server URL~~ (`game.boobank.com`)
- [x] ~~24/7 hosted server~~ (Vultr Tokyo + systemd auto-start)
- [x] ~~Multi-game portal~~ ([game.boobank.com](https://game.boobank.com))
- [x] ~~Vertical map (bridge / tunnel / jump pads / stairs)~~ (v6.6)
- [x] ~~Headshots + floating damage numbers~~ (v6.7)
- [x] ~~Health packs / ammo crates / jump pads~~ (v6.8)
- [x] ~~3 weapons (pistol / SMG / shotgun) with switching~~ (v6.9)
- [x] ~~Killstreak announcer (DOUBLE KILL / GODLIKE)~~ (v6.10)
- [x] ~~Bot single-player (works on web too)~~ (v6.11–v6.13)
- [x] ~~Smart respawn (far from enemies) + death cooldown~~ (v6.13.2 / v6.17)
- [ ] Multi-room support (room codes)
- [ ] Multiple maps in rotation
- [ ] Weapon recoil / camera bob
- [ ] Team mode (red vs blue, friendly fire off)

## Version milestones

| Version | What shipped |
|---|---|
| v5  | Multiplayer PvP MVP |
| v6  | Character animations / SFX / kill feed / leaderboard |
| v6.6  | 3D map (central bridge + stairs + east tunnel + jumpable platforms) |
| v6.7  | Headshots (server-validated) + floating `-25` / `HEAD! -50` |
| v6.8  | Jump pads (5 m boost) + health packs (+50) + ammo crates (full refill) |
| v6.9  | 3-weapon switching (PIS / SMG / SHG), per-weapon ammo, headshot table |
| v6.10 | Killstreak banners (2 / 3 / 5 / 7 thresholds) |
| v6.11 | Bot AI (wander → engage state machine), 0–3 from main menu |
| v6.13 | Web build can PLAY vs BOTS without a server (OfflineMultiplayerPeer) |
| v6.17 | 2.5 s respawn cooldown + RPC startup-error silence |

## Credits

- Character models: [Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters) (CC0)
- Engine: [Godot 4.6](https://godotengine.org/)
- SFX: [Kenney Audio Pack](https://kenney.nl/assets) (CC0)
- Hosting: [Vultr](https://vultr.com/) + [Caddy](https://caddyserver.com/) + [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)

---

<a id="中文"></a>

# Arena Shooter 3D（中文）

第一人称多人对战 FPS。Godot 4.6 + WebSocket + 18 个 Kenney 方块小人。**浏览器、手机都能玩**。

🎮 **现场玩**（24h 在线）：**https://game.boobank.com/arena-shooter/**
🏠 **门户首页**（所有游戏）：https://game.boobank.com/（由 [longmaolab/portal](https://github.com/longmaolab/portal) 仓库托管）
🌐 **服务器**：Vultr Tokyo + Caddy + Cloudflare 命名隧道，固定不变

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
├── run_server.sh           本地调试用：启动 Mac 上的 dedicated 服务器
├── deploy.sh               ⭐ 一键发布：git push + 通知服务器 git pull + import + 重启
├── OPERATIONS.md           ⭐ 日常运维速查（必看）
├── SERVER_GUIDE.md         全栈架构 + 一次性搭建步骤
├── docs/                   Web 客户端构建产物
│   ├── index.html / .wasm / .pck …
│   └── server.json         ← wss://game.boobank.com/arena-shooter/ws
├── audio/                  音效（射击 / 命中 / 死亡 / 复活，CC0 Kenney）
├── models/characters/      Kenney 方块角色（18 个 GLB + 18 张贴图 + 缩略图）
├── fonts/                  Russo One 显示字体
├── themes/                 arena_theme.tres（项目统一字体主题）
├── scenes/
│   ├── main_menu.tscn      主菜单 + 选角色界面
│   ├── game.tscn           竞技场地图
│   ├── player.tscn         联网玩家
│   ├── hud.tscn            HUD + 计分板 + 死亡黑屏 + 击杀提示 + 连击横幅
│   └── touch_controls.tscn 手机虚拟摇杆
└── scripts/
    ├── input_setup.gd      autoload：键盘映射
    ├── network_manager.gd  autoload：联网状态 / 房间列表 / 玩家信息
    ├── stats_store.gd      autoload：本地持久化排行榜
    ├── main_menu.gd        主菜单（PLAY / PLAY vs BOTS / Bot 数 / 名字）
    ├── game.gd             场景调度 / 计分 / 死亡流 / dedicated 模式
    ├── player.gd           玩家移动 / 射击 / 武器 / 动画 / Bot AI
    ├── hud.gd              HP / 弹药 / 计分榜 / 击杀提示 / 连击横幅
    ├── pickup.gd           血包 + 弹药箱（视觉 + 拾取逻辑）
    ├── jump_pad.gd         跳板（弹起 + 视觉脉冲）
    └── touch_controls.gd   虚拟摇杆 + 滑动看 + 动作 + 武器键
```

---

## 本机调试（不联网）

1. Godot 4.6 打开 `project.godot`
2. **调试 → 运行多个实例 → 2**
3. ⌘+B 同时开两个窗口
4. 窗口 1：**🤖 PLAY vs BOTS**（变本机 host，:7777）
5. 窗口 2：直接点 **▶ PLAY** —— 编辑器调试时 IP 框已自动填 `ws://127.0.0.1:7777`

---

## 让同学联机（已 24h 在线，啥都不用做）

```
[Vultr Tokyo 服务器]                            [玩家手机/电脑]
──────────────────                             ──────────────
arena-game.service (Godot :7777)                  浏览器打开:
caddy.service     (反代 :80，静态 + WS 同域)     ←── wss:// ──   game.boobank.com/arena-shooter/
cloudflared.service (CF 命名隧道)
                  ↓
        游戏一直在 → game.boobank.com
```

直接把链接发给同学：
```
https://game.boobank.com/arena-shooter/
```

服务器 24h 跑，Mac 关机也不影响。详细架构和搭建过程见 [SERVER_GUIDE.md](SERVER_GUIDE.md)；
日常运维命令速查见 [OPERATIONS.md](OPERATIONS.md)。

## Mac 当临时公网服务器(可选,只在 VPS 挂了时用)

> 这一节**不是**给你和孩子本地玩用的 —— **本地两个窗口对打** 直接走 `127.0.0.1`,不需要 cloudflared,见上面"本机调试"一节。
> 这一节只在你想用 **Mac 顶替 VPS 当公网服务器**(比如 VPS 维护时)才用得到。

```bash
./run_server.sh                          # 终端 1
cloudflared tunnel run arena-shooter     # 终端 2
```

Mac 上 cloudflared 会和 VPS 上 cloudflared 注册到同一个隧道,Cloudflare 自动 HA 路由。
**不想分流就别同时跑两边**(VPS 没维护就别开 Mac 这边)。

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

改完代码,一行命令:

```bash
./deploy.sh
```

脚本会全自动:
- 检测 `scripts/` / `scenes/` / `audio/` / `fonts/` / `models/` / `themes/` / `project.godot` 里是否有比 `docs/index.pck` 新的文件
- 是 → headless 调 Godot 重新 export 网页版(~30-60 秒)
- 否 → 跳过 export(~5 秒)
- 然后:清理 `.import` 残留、commit、push、ssh 服务器、git pull、重建 import 缓存、重启 arena-game

**玩家硬刷新就能看到新版本**(不需要 export 时约 5 秒;需要 export 时约 60 秒)。

---

## 进阶 / TODO

- [x] ~~角色走路 / 待机动画~~（v6）
- [x] ~~死亡音效 + 击杀提示~~（v6）
- [x] ~~排行榜 + 持久化数据~~（v6，本地存档）
- [x] ~~永久服务器 URL~~（`game.boobank.com`）
- [x] ~~24h 在线服务器~~（Vultr Tokyo + systemd 自启）
- [x] ~~多游戏门户~~（[game.boobank.com](https://game.boobank.com)）
- [x] ~~垂直地图（桥、隧道、跳板、阶梯）~~（v6.6）
- [x] ~~爆头 + 飘字伤害~~（v6.7）
- [x] ~~血包 / 弹药箱 / 跳板~~（v6.8）
- [x] ~~3 把武器（手枪 / SMG / 霰弹）切换~~（v6.9）
- [x] ~~连击播报（DOUBLE KILL / GODLIKE）~~（v6.10）
- [x] ~~Bot 单人模式（网页版也能打）~~（v6.11–v6.13）
- [x] ~~复活智能选点（远离敌人）+ 死亡冷却~~（v6.13.2 / v6.17）
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
| v6.13 | 网页版可单机 vs Bot（OfflineMultiplayerPeer 兜底） |
| v6.17 | 死亡 2.5s 复活冷却 + RPC 启动错误静默 |

## 致谢

- 角色模型：[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)（CC0）
- 引擎：[Godot 4.6](https://godotengine.org/)
- 音效：[Kenney Audio Pack](https://kenney.nl/assets)（CC0）
- 部署：[Vultr](https://vultr.com/) + [Caddy](https://caddyserver.com/) + [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
