# 服务器运维指南

每次想跟同学联机时,按这套流程做。

服务器地址固定为 **`wss://game.boobank.com`**(Cloudflare 命名隧道),所以
开服流程比临时隧道时代简单很多 —— **不再需要每次推送 `server.json`**。

---

## 一次性准备(已完成,新机器才需要重做)

### 1. 安装 Cloudflare Tunnel

```bash
brew install cloudflared
```

### 2. 验证 Godot 路径

`run_server.sh` 会自动在常见位置搜 `Godot.app`。确认其中之一存在:

```bash
ls /Applications/Godot.app/Contents/MacOS/Godot 2>/dev/null \
 || ls ~/Downloads/Godot.app/Contents/MacOS/Godot 2>/dev/null \
 || echo "把 Godot.app 放到 /Applications 或 ~/Downloads"
```

如果都不在,把 Godot.app 放过去,或用环境变量:
```bash
GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot ./run_server.sh
```

### 3. 搭建 Cloudflare 命名隧道(第一次设置或换域名时)

#### 3.1 域名 DNS 托管到 Cloudflare

`boobank.com` 已经在 GoDaddy 注册,nameserver 已改为 Cloudflare:
```
arely.ns.cloudflare.com
jarred.ns.cloudflare.com
```

换域名时,在 Cloudflare 仪表盘 **Add a site** → 拿到 NS → 去注册商把
nameserver 改成 Cloudflare 给的两条。

#### 3.2 登录并创建隧道

```bash
cloudflared tunnel login                       # 浏览器选择域名,生成 ~/.cloudflared/cert.pem
cloudflared tunnel create arena-shooter        # 生成 ~/.cloudflared/<UUID>.json
cloudflared tunnel route dns arena-shooter game.boobank.com
```

最后一条会自动在 Cloudflare DNS 里加 CNAME(橙色云代理状态)。

#### 3.3 写隧道配置

`~/.cloudflared/config.yml`:
```yaml
tunnel: arena-shooter
credentials-file: /Users/longmao/.cloudflared/<UUID>.json

ingress:
  - hostname: game.boobank.com
    service: http://localhost:7777
  - service: http_status:404
```

把 `<UUID>` 换成 `cloudflared tunnel create` 输出里的真实 ID。验证:
```bash
cloudflared tunnel ingress validate            # 输出 OK
```

#### 3.4 `docs/server.json` 已硬编码

```json
{ "url": "wss://game.boobank.com" }
```

以后**永远不用再改**(除非换域名)。

---

## 每次开战流程(2 个终端,30 秒)

### 终端 1:启动游戏服务器

```bash
cd /Users/longmao/projects/arena-shooter-3d
./run_server.sh
```

应该看到:
```
→ Starting headless game server on port 7777...
[server] listening on port 7777
```

⚠️ 终端**别关**。脚本会自动清理上次没退干净的进程。

### 终端 2:启动命名隧道

```bash
cloudflared tunnel run arena-shooter
```

看到 `Registered tunnel connection` 就连上 Cloudflare 了。⚠️ 终端**别关**。

### 把链接发给同学

```
https://longmaolab.github.io/arena-shooter-3d/
```

同学打开 → 选角色 → **Join**(地址已自动加载 `wss://game.boobank.com`)→ 联机!

---

## 关服务器

两个终端各按一次 **Ctrl+C**,或一行命令:

```bash
pkill -f "Godot.*--server" && pkill -x cloudflared
```

下次开服重新跑两个终端即可,**URL 永远不变,不需要 push 任何东西**。

---

## 进阶:装成 launchd 服务,开机自启

不想每次手动开终端,可以装成系统服务。

### cloudflared 装成服务

```bash
sudo cloudflared service install
```

macOS 下会注册为 launchd 服务,开机自启。管理:
```bash
sudo launchctl list | grep cloudflared        # 查看
sudo cloudflared service uninstall            # 卸载
```

### Godot 服务器装成 launchd(可选)

写一个 plist `~/Library/LaunchAgents/com.longmao.arena-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.longmao.arena-server</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/longmao/projects/arena-shooter-3d/run_server.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/arena-server.log</string>
  <key>StandardErrorPath</key><string>/tmp/arena-server.err</string>
</dict>
</plist>
```

加载:
```bash
launchctl load ~/Library/LaunchAgents/com.longmao.arena-server.plist
```

卸载:
```bash
launchctl unload ~/Library/LaunchAgents/com.longmao.arena-server.plist
```

---

## 常见问题

### 同学打开链接看到 "Connection failed"
- 你的服务器(终端 1)跑着吗?`lsof -iTCP:7777 -sTCP:LISTEN` 应有 Godot
- 隧道(终端 2)跑着吗?日志最后应有 `Registered tunnel connection`
- 在浏览器打开 `https://game.boobank.com/` —— 502 = 后端没起来,1033 = 隧道没连上
- 浏览器 F12 → Console,截图发我

### 浏览器报 502
- 后端 `localhost:7777` 没起来,先启动 `./run_server.sh`
- 或 `~/.cloudflared/config.yml` 里的端口 / hostname 写错了,跑 `cloudflared tunnel ingress validate`

### 浏览器报 1033 / Tunnel not found
- 隧道没运行,跑 `cloudflared tunnel run arena-shooter`
- 或 DNS 没生效,`dig game.boobank.com +short` 应返回 Cloudflare IP

### 同学打开页面是旧版
- GitHub Pages 缓存,让同学**强制刷新**(电脑 Cmd/Ctrl+Shift+R;手机长按刷新键 → 不缓存重载)
- 或加查询参数:`https://longmaolab.github.io/arena-shooter-3d/?v=2`

### Godot 服务器报音频文件 "no resource loaders"
新加 `audio/` 资源后第一次跑 headless 会出现。在 Godot 编辑器里打开一次项目,
或命令行跑一次 import:
```bash
cd /Users/longmao/projects/arena-shooter-3d
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```
生成的 `audio/*.import` 记得 commit。

### 隧道偶尔断流
- 命名隧道默认 4 条 HA 连接(Mac 实测会降到 2 条),个别断了不影响
- 看终端 2 日志有没有 `Lost connection`,通常会自动重连
- 长期断流换网络环境(比如换 WiFi)
