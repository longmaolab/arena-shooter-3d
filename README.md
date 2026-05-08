# Arena Shooter 3D

第一人称多人对战 FPS。Godot 4.6 + WebSocket + 18 个 Kenney 方块小人。**浏览器、手机都能玩**。

🎮 **现场玩**（需要 host 在线）：https://longmaolab.github.io/arena-shooter-3d/

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
├── run_server.sh           ⭐ 一键启动 dedicated 服务器（Mac）
├── deploy.sh               一键推送 docs/ 到 GitHub Pages
├── docs/                   Web 客户端构建产物（GitHub Pages）
│   ├── index.html / .wasm / .pck …
│   └── server.json         ← 当前线上服务器 URL（每次开服更新）
├── models/characters/      Kenney 方块角色（18 个 GLB + 18 张贴图 + 缩略图）
├── scenes/
│   ├── main_menu.tscn      主菜单 + 选角色界面
│   ├── game.tscn           竞技场地图
│   ├── player.tscn         联网玩家
│   ├── hud.tscn            HUD + 计分板 + 死亡黑屏
│   └── touch_controls.tscn 手机虚拟摇杆
└── scripts/
    ├── input_setup.gd      autoload：键盘映射
    ├── network_manager.gd  autoload：联网状态 / 房间列表 / 玩家信息
    ├── main_menu.gd        主菜单 + 选角色 + server.json 自动加载
    ├── game.gd             场景调度 / 计分 / 新开局 / dedicated 模式
    ├── player.gd           玩家移动 / 射击 / 受伤反馈 / 换肤
    ├── hud.gd              HP / 弹药 / 计分榜 / 死亡红屏
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

## 让同学联机（生产环境）

总览：

```
[你 Mac]                                   [同学手机/电脑]
─────────────                              ─────────────
1. ./run_server.sh        ←── wss:// ──→  浏览器打开:
   (Godot 无头服务器)                       longmaolab.github.io/arena-shooter-3d/
2. cloudflared tunnel
   (公网代理)
```

### 第一次准备（10 分钟，只做一次）

```bash
# 装 cloudflared（公网代理工具）
brew install cloudflared

# 注册 GitHub 仓库（如果还没）
gh repo create longmaolab/arena-shooter-3d --public --source=. --remote=origin --push

# 启用 GitHub Pages 指向 docs/
gh api -X POST /repos/longmaolab/arena-shooter-3d/pages \
  -f "source[branch]=main" -f "source[path]=/docs"
```

### 每次开战流程（5 分钟）

#### 终端 1：启动游戏服务器
```bash
cd /Users/longmao/projects/arena-shooter-3d
./run_server.sh
```
看到 `[server] listening on port 7777` 即成功。**保持终端别关**。

> ✨ 脚本会自动检测并清理上次没退出干净的服务器进程，**不用再手动 pkill**。

#### 终端 2：开 Cloudflare Tunnel
```bash
cloudflared tunnel --url http://localhost:7777
```

输出里会有一行：
```
https://abc-def-xyz.trycloudflare.com
```
**复制这个 URL**。**保持终端别关**。

#### 终端 3：把 URL 写进 server.json 并推送
```bash
cd /Users/longmao/projects/arena-shooter-3d

# ⚠️ 把 abc-def-xyz 换成你刚才得到的真实 URL，注意 https → wss
cat > docs/server.json <<'EOF'
{"url": "wss://abc-def-xyz.trycloudflare.com"}
EOF

git add docs/server.json
git commit -m "Update live server URL"
git push
```

约 1 分钟后，发链接给同学：
```
https://longmaolab.github.io/arena-shooter-3d/
```

同学在浏览器打开 → 选角色 → 点 **Join**（地址已自动加载）→ 联机！

#### 玩完关服务器
- 终端 1 按 **Ctrl+C**
- 终端 2 按 **Ctrl+C**

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

## 重新发布 Web 版

每次改了代码后：

1. Godot 里 **项目 → 导出 → Web → 导出项目**（路径默认 `docs/index.html`）
2. ```bash
   cd /Users/longmao/projects/arena-shooter-3d
   find docs -name "*.import" -delete   # 清掉 Godot 编辑器残留
   ./deploy.sh
   ```

约 1 分钟后线上版本更新。

---

## 进阶 / TODO

- [ ] 角色走路 / 待机动画
- [ ] 武器切换（手枪 / 狙击 / 散弹）
- [ ] 多房间系统（房间码加入）
- [ ] 永久服务器 URL（Cloudflare 命名隧道，需要域名）
- [ ] 死亡音效 + 击杀提示
- [ ] 24h 在线服务器（Fly.io / Hetzner VPS，需要每月几块钱）
- [ ] 排行榜 + 持久化数据

## 致谢

- 角色模型：[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)（CC0）
- 引擎：[Godot 4.6](https://godotengine.org/)
- 部署：[GitHub Pages](https://pages.github.com/) + [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
