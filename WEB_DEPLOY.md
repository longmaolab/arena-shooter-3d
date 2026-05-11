# Web Deployment Guide (HISTORICAL)

> ⚠️ **This document is outdated.** It describes the original GitHub Pages
> deployment from v5/v6.0. The project now runs on a VPS with Caddy and
> Cloudflare Tunnel — see [SERVER_GUIDE.md](SERVER_GUIDE.md) for the current
> architecture and [OPERATIONS.md](OPERATIONS.md) for day-to-day operations.
> Kept here as a development-history snapshot.

> ⚠️ **这个文档已过期。** 这是 v5/v6.0 时期的 GitHub Pages 部署说明。
> 项目已迁移到 VPS + Caddy + Cloudflare 隧道 —— 当前架构见
> [SERVER_GUIDE.md](SERVER_GUIDE.md)，日常运维命令见 [OPERATIONS.md](OPERATIONS.md)。
> 保留在这里作为开发历史快照。

---

# Web 部署完全指南

把游戏发布到网上，让同学打开链接就能玩——一步步来。

---

## 总体架构

```
┌─────────────────────────────┐                  ┌─────────────────────────┐
│ 你的 Mac                    │                  │ 同学的手机/电脑         │
│ ─────────                   │                  │ ─────────               │
│ 1. Godot 跑游戏（Host）     │ ←── ngrok ───→   │ 浏览器打开你的链接      │
│ 2. ngrok 暴露成公网 URL     │     wss://       │ → GitHub Pages 加载游戏 │
└─────────────────────────────┘                  │ → 用 ngrok URL 加入对战 │
                                                  └─────────────────────────┘
```

**两个东西要部署：**
1. **客户端（HTML5 游戏）** → 部署一次到 GitHub Pages，永久在线
2. **服务器（Host）** → 你的 Mac 上跑 Godot 游戏点 Host，配 ngrok 临时暴露

---

## 第一步：安装 Web 导出模板（**只做一次，约 5 分钟**）

Godot 默认不带 Web 导出能力，需要下载约 200MB 模板。

1. 打开 Godot 编辑器
2. 顶部菜单 **编辑器（Editor）→ 管理导出模板（Manage Export Templates）**
3. 点 **从 godotengine.org 下载（Download from godotengine.org）**
4. 等下载（约 200MB，2-5 分钟）
5. 完成后关闭对话框

---

## 第二步：导出 HTML5（**每次发布前做**）

1. 顶部菜单 **项目（Project）→ 导出（Export）**
2. 应该看到 **Web** 预设（项目里已经配好 `export_presets.cfg`）
3. 点底部 **导出项目（Export Project）**
4. **不勾选** "仅以调试模式导出"
5. 路径默认 `docs/index.html` —— 直接确认
6. 等待导出完成（约 30 秒）

完成后 `docs/` 文件夹下应该有：
```
docs/
├── index.html
├── index.js
├── index.wasm     (~30MB，游戏引擎)
├── index.pck      (你的游戏资源)
├── index.png      (启动图)
└── index.audio.worklet.js
```

---

## 第三步：发到 GitHub Pages

### A) 第一次发布

```bash
cd /Users/longmao/projects/arena-shooter-3d

# 初始化 git（如果还没）
git init
git add .
git commit -m "Initial commit"

# 创建 GitHub 仓库（用 gh 命令）
gh repo create longmaolab/arena-shooter-3d --public --source=. --remote=origin --push

# 启用 GitHub Pages（指向 docs/ 文件夹）
gh api -X POST /repos/longmaolab/arena-shooter-3d/pages \
  -f "source[branch]=main" \
  -f "source[path]=/docs"
```

约 1 分钟后，游戏就在这个地址：
**https://longmaolab.github.io/arena-shooter-3d/**

### B) 之后每次更新

```bash
# 在 Godot 里重新导出（覆盖 docs/）
# 然后：
git add docs/
git commit -m "Update build"
git push
```

GitHub Pages 自动重新部署，~1 分钟后链接更新。

---

## 第四步：跟同学联机（用 ngrok）

### 安装 ngrok（**只做一次**）

```bash
brew install ngrok
ngrok config add-authtoken <你的-token>   # 去 https://dashboard.ngrok.com/get-started/your-authtoken 注册免费账号拿 token
```

### 每次开战前

**你这边（Mac，当 Host）：**

1. 打开 Godot，⌘+B 跑游戏，**点 Host**
2. 开终端，运行：
   ```bash
   ngrok http 7777
   ```
3. 看到类似输出：
   ```
   Forwarding   https://abc-123-xyz.ngrok-free.app -> http://localhost:7777
   ```
4. **复制那个 ngrok URL**（去掉 `https://`，例如 `abc-123-xyz.ngrok-free.app`）
5. 把这个 URL 发给同学

**同学那边（手机/电脑）：**

1. 浏览器打开 `https://longmaolab.github.io/arena-shooter-3d/`
2. 等加载（首次约 30 秒，~30MB）
3. 进入主菜单
4. 在 IP 输入框填 **`wss://abc-123-xyz.ngrok-free.app`** （你给他们的 URL，开头加 `wss://`）
5. 点 **Join**
6. 应该进入对战！

---

## 操作（手机版会自动出现触屏控件）

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 |
|---|---|---|---|---|---|
| 电脑 | WASD | 鼠标 | 空格 | 左键 | R |
| 手机 | 左下虚拟摇杆 | 右半屏滑动 | 右下蓝键 | 右下红键 | 黄键 |

---

## 常见问题

### "连不上" / 同学一直转圈
- 你这边 Godot 里**真的点了 Host** 吗？（不只是开了游戏）
- ngrok 终端是不是还**开着**？关了就断了
- 同学输入的 URL 是不是 **`wss://`** 开头（不能用 `ws://`，因为 GitHub Pages 是 https 站点）

### "首次加载好慢"
- 正常，~30MB 要下载。**第二次访问秒开**（浏览器缓存）

### 微信里打不开
- 微信内置浏览器对 WebAssembly 支持差。**让同学用 Safari/Chrome 打开链接**（长按链接 → 在浏览器打开）

### ngrok 免费版提示页
- ngrok 免费档每次开会让访问者点一次"Visit Site"按钮才能继续，正常
- 想跳过就升级 ngrok 付费版（$8/月）或换 Cloudflare Tunnel（免费）

### 我电脑关了同学就玩不了
- 是的——你的 Mac 是服务器，关了就没人当裁判了
- 想 24h 在线 → 把服务器部署到 Fly.io / Railway 免费档（这是更进阶的话题）

---

## 一键导出 + 部署脚本（可选）

把这个存成 `deploy.sh` 在项目根目录：

```bash
#!/usr/bin/env bash
set -e
echo "→ 在 Godot 里手动导出 HTML5 (Project → Export → Export Project)"
echo "→ 完成后回来按回车"
read

git add docs/
git commit -m "Build $(date '+%Y-%m-%d %H:%M')" || echo "(无改动)"
git push
echo "✅ 已部署：https://longmaolab.github.io/arena-shooter-3d/"
```

赋予执行权限：`chmod +x deploy.sh`，之后每次更新跑 `./deploy.sh`。
