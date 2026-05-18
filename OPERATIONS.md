# Operations Cheatsheet

> 📘 English version first. 中文版在文件下半部分 ([跳到中文](#运维速查手册中文)).

Day-to-day commands. For the full architecture, see [SERVER_GUIDE.md](SERVER_GUIDE.md).

---

## Key facts

| Item | Value |
|---|---|
| Server | Vultr Tokyo, Ubuntu 24.04 |
| Public URL | https://game.boobank.com/arena-shooter/ |
| WebSocket | wss://game.boobank.com/arena-shooter/ws |
| Portal | https://game.boobank.com/ (hosted in [longmaolab/portal](https://github.com/longmaolab/portal)) |
| Server path | `/opt/games/arena-shooter-3d/` |
| SSH | `ssh root@207.148.98.206` |

---

## Deploying code changes

### Web client changed (scripts / scenes / project.godot)

```bash
cd /Users/longmao/projects/arena-shooter-3d
./deploy.sh
```

`deploy.sh` does **everything**:

1. **Auto-detects** if any GDScript / scene / asset / project setting changed since the last build
2. **Auto-exports** the web build via `godot --headless --export-release "Web"` (~30-60s when needed; skipped when not)
3. Cleans up `.import` editor leftovers
4. `git commit + push`
5. `ssh server → git pull → godot --headless --import → sudo systemctl restart arena-game`

**Players see the new version after a hard refresh, ~5 seconds (no source changes) or ~60 seconds (with re-export).**

> ⚠️ `git push` alone is not enough — that only pushes source to GitHub but doesn't update the VPS or rebuild the web client. Always use `./deploy.sh`.

> ⚠️ Without the server-side `--import` step, any newly added asset (font, texture, model) will fail to load on the server with `Cannot open file 'res://.godot/imported/...'`. `deploy.sh` handles this automatically.

### Server-side only (GDScript that doesn't change the web client)

```bash
git push
ssh root@207.148.98.206 'cd /opt/games/arena-shooter-3d && git pull && godot --headless --path . --import && systemctl restart arena-game'
```

### Portal only

```bash
cd /Users/longmao/projects/portal
git add -A && git commit -m "..." && git push
ssh root@207.148.98.206 'cd /opt/games/portal && git pull'
```

---

## Service management

SSH in first: `ssh root@207.148.98.206`

| Action | Command |
|---|---|
| Check all 3 services (should all be `active`) | `systemctl is-active arena-game caddy cloudflared` |
| Live game-server log | `journalctl -u arena-game -f` |
| Live tunnel log | `journalctl -u cloudflared -f` |
| Live web-server log | `journalctl -u caddy -f` |
| Restart game server | `systemctl restart arena-game` |
| Restart tunnel | `systemctl restart cloudflared` |
| Restart Caddy | `systemctl reload caddy` (config change); `systemctl restart caddy` (full restart) |
| Listening ports | `ss -ltnp \| grep -E ':80\|:7777'` |
| Memory | `free -h` |
| Disk | `df -h /` |

---

## Adding a new game to the portal

1. **Write the new game in its own repo** (say `tetris-clone`), push to GitHub.
2. **Clone + deploy on the server**:
   ```bash
   ssh root@207.148.98.206
   git clone https://github.com/longmaolab/tetris-clone.git /opt/games/tetris-clone
   ```
3. **Edit Caddy config** (`/etc/caddy/Caddyfile`), add 3 lines:
   ```
   handle_path /tetris-clone/* {
       root * /opt/games/tetris-clone/docs
       file_server
   }
   ```
   (If it's a multiplayer game, also add `handle /tetris-clone/ws { reverse_proxy localhost:<port> }`)
4. **Reload Caddy**: `systemctl reload caddy`
5. **Update the portal home page**: `/Users/longmao/projects/portal/index.html` — add a new card, push, server pulls.

---

## Troubleshooting

### Players see errors when opening https://game.boobank.com/arena-shooter/

**Step 1: Check the 3 services**
```bash
ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'
```
Any one not `active` → check its log:
```bash
journalctl -u <service-name> -n 50 --no-pager
```

**Step 2: External probe**

```bash
# Portal should return 200
curl -I https://game.boobank.com/

# Game page should return 200
curl -I https://game.boobank.com/arena-shooter/

# server.json should return the wss URL
curl -s https://game.boobank.com/arena-shooter/server.json
```

| Error | Cause |
|---|---|
| 502 / 521 | Caddy is down, or Caddy is up but Godot isn't listening on 7777 |
| 522 | cloudflared can't reach Caddy (port 80 not listening) |
| 1033 / Tunnel not found | cloudflared isn't running |
| 404 | Caddy route didn't match |
| Browser console: mixed content | Client is using ws:// instead of wss:// (check server.json) |

### Player gets in but the game lags
- `journalctl -u arena-game -n 100` — look for GDScript errors
- Check memory: `free -h` — if swap is being used → upgrade the Vultr plan
- Check CPU: `top` — Godot process > 80% CPU sustained = laggy

### Caddyfile edited but no effect
```bash
caddy validate --config /etc/caddy/Caddyfile      # validate first
systemctl reload caddy                             # reload without restart
journalctl -u caddy -n 20 --no-pager               # check for errors
```

### Tunnel occasionally drops
- cloudflared keeps 4 HA connections by default; a partial drop is fine
- Long disconnect: `systemctl restart cloudflared`
- Logs: `journalctl -u cloudflared -n 30 | grep -i 'error\|lost'`

---

## Global restart (nuclear option)

Server is having issues but you can't tell where → restart everything:

```bash
ssh root@207.148.98.206 'systemctl restart arena-game caddy cloudflared && sleep 4 && systemctl is-active arena-game caddy cloudflared'
```

If SSH itself doesn't connect → use the Vultr console **Server Restart** to force-reboot the VM. All systemd services auto-restart on boot.

---

## Backup & recovery

All code is in git. **If the server is destroyed**:

1. Spin up a new server (any provider, Ubuntu 24.04)
2. Follow [SERVER_GUIDE.md](SERVER_GUIDE.md) from the top
3. `scp` `~/.cloudflared/cert.pem` and `82154cfb-...json` from the Mac to the new server
4. Done — full recovery in ~30 minutes

> The Mac's `~/.cloudflared/` is the real tunnel credential — **don't lose it**. Back it up to a password manager or encrypted vault.

---

<a id="运维速查手册中文"></a>

# 运维速查手册（中文）

日常操作命令清单。架构总览见 [SERVER_GUIDE.md](SERVER_GUIDE.md)。

---

## 关键信息

| 项目 | 值 |
|---|---|
| 服务器 | Vultr Tokyo, Ubuntu 24.04 |
| 公网入口 | https://game.boobank.com/arena-shooter/ |
| WebSocket | wss://game.boobank.com/arena-shooter/ws |
| 门户 | https://game.boobank.com/（由 [longmaolab/portal](https://github.com/longmaolab/portal) 仓库托管） |
| 服务器路径 | `/opt/games/arena-shooter-3d/` |
| SSH | `ssh root@207.148.98.206` |

---

## 改完代码，部署上线

### Web 客户端改了（scripts / scenes / project.godot）

```bash
cd /Users/longmao/projects/arena-shooter-3d
./deploy.sh
```

`deploy.sh` 自己搞定全部事:

1. **检测**有没有 GDScript / 场景 / 资源 / 项目设置改过
2. **自动 export**(`godot --headless --export-release "Web"`,约 30-60 秒;没改源文件就跳过,5 秒)
3. 清理 `.import` 编辑器残留
4. `git commit + push`
5. `ssh server → git pull → godot --headless --import → sudo systemctl restart arena-game`

**玩家硬刷新就能看到新版本**(无源码改动约 5 秒;带 re-export 约 60 秒)。

> ⚠️ 单独 `git push` 不够 —— 只推源码到 GitHub,不会更新 VPS,不会重新打包网页版。永远用 `./deploy.sh`。

> ⚠️ 不跑服务器端 `--import` 的话,新加的资源(字体/贴图/模型)启动时会报 `Cannot open file 'res://.godot/imported/...'`。`deploy.sh` 已自动处理。

### 只改了服务器端（GDScript 但不影响 Web 客户端）

```bash
git push
ssh root@207.148.98.206 'cd /opt/games/arena-shooter-3d && git pull && godot --headless --path . --import && systemctl restart arena-game'
```

### 只改了门户

```bash
cd /Users/longmao/projects/portal
git add -A && git commit -m "..." && git push
ssh root@207.148.98.206 'cd /opt/games/portal && git pull'
```

---

## 服务器服务管理

进服务器：`ssh root@207.148.98.206`

| 操作 | 命令 |
|---|---|
| 查看 3 个服务状态（应全 active） | `systemctl is-active arena-game caddy cloudflared` |
| 实时看游戏服务器日志 | `journalctl -u arena-game -f` |
| 实时看隧道日志 | `journalctl -u cloudflared -f` |
| 实时看 Web 服务器日志 | `journalctl -u caddy -f` |
| 重启游戏服务器 | `systemctl restart arena-game` |
| 重启隧道 | `systemctl restart cloudflared` |
| 重启 Caddy | `systemctl reload caddy`（配置变更）；`systemctl restart caddy`（重启） |
| 看监听端口 | `ss -ltnp \| grep -E ':80\|:7777'` |
| 看内存 | `free -h` |
| 看磁盘 | `df -h /` |

---

## 加新游戏到门户

1. **在新 repo 写好游戏**（假设叫 `tetris-clone`），push 到 GitHub。
2. **服务器 clone + 部署**：
   ```bash
   ssh root@207.148.98.206
   git clone https://github.com/longmaolab/tetris-clone.git /opt/games/tetris-clone
   ```
3. **改 Caddy 配置**（`/etc/caddy/Caddyfile`），加 3 行：
   ```
   handle_path /tetris-clone/* {
       root * /opt/games/tetris-clone/docs
       file_server
   }
   ```
   （如果是联机游戏，再加一段 `handle /tetris-clone/ws { reverse_proxy localhost:<端口> }`）
4. **重载 Caddy**：`systemctl reload caddy`
5. **改门户首页**：`/Users/longmao/projects/portal/index.html` 加一张新卡片，push，服务器 pull。

---

## 常见故障排查

### 玩家访问 https://game.boobank.com/arena-shooter/ 报错

**步骤 1：看 3 个服务**
```bash
ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'
```
任何一个不是 `active` → 看对应日志：
```bash
journalctl -u <服务名> -n 50 --no-pager
```

**步骤 2：从外部探测**

```bash
# 门户应返回 200
curl -I https://game.boobank.com/

# 游戏页应返回 200
curl -I https://game.boobank.com/arena-shooter/

# server.json 应返回 wss URL
curl -s https://game.boobank.com/arena-shooter/server.json
```

| 错误 | 原因 |
|---|---|
| 502 / 521 | Caddy 没起来，或 Caddy 起来但 Godot 没监听 7777 |
| 522 | cloudflared 连不上 Caddy（localhost:80 没监听） |
| 1033 / Tunnel not found | cloudflared 没运行 |
| 404 | Caddy 路由没匹配上 |
| 浏览器 console 报 mixed content | 客户端在用 ws:// 不是 wss://（检查 server.json） |

### 玩家进了游戏但卡顿
- `journalctl -u arena-game -n 100`，看有没有 GDScript 报错
- 看服务器内存：`free -h` —— 如果 swap 在用 → 升级 4GB 套餐
- 看服务器 CPU：`top` —— Godot 进程 > 80% CPU 持续就卡顿

### 改了 Caddyfile 但没生效
```bash
caddy validate --config /etc/caddy/Caddyfile      # 先验证
systemctl reload caddy                             # 不重启的方式重载
journalctl -u caddy -n 20 --no-pager               # 看有没有报错
```

### 隧道偶尔断流
- cloudflared 默认 4 条 HA，部分掉了不影响
- 长时间没连上：`systemctl restart cloudflared`
- 看日志：`journalctl -u cloudflared -n 30 | grep -i 'error\|lost'`

---

## 全局重启（核选项）

服务器有问题但不知道哪里 → 全部重启一次：

```bash
ssh root@207.148.98.206 'systemctl restart arena-game caddy cloudflared && sleep 4 && systemctl is-active arena-game caddy cloudflared'
```

如果连 SSH 都进不去 → Vultr 控制台里 **Server Restart** 强制重启整个虚拟机。所有 systemd 服务会随系统启动自动恢复。

---

## 备份恢复

代码全在 git。**服务器爆掉的话**：

1. 开新服务器（任意厂家，Ubuntu 24.04）
2. 跟着 [SERVER_GUIDE.md](SERVER_GUIDE.md) 走一遍
3. 把 `~/.cloudflared/cert.pem` 和 `82154cfb-...json` 从 Mac scp 过去
4. 完成，30 分钟内可恢复

> Mac 上的 `~/.cloudflared/` 是隧道的真正凭证，**不要丢**。建议复制一份到密码管理器或加密备份。
