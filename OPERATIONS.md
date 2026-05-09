# 运维速查手册

日常操作命令清单。架构总览见 [SERVER_GUIDE.md](SERVER_GUIDE.md)。

---

## 关键信息

| 项目 | 值 |
|---|---|
| 服务器 | Vultr Tokyo, Ubuntu 24.04 |
| 公网入口 | https://game.boobank.com/arena-shooter/ |
| WebSocket | wss://game.boobank.com/arena-shooter/ws |
| 门户 | https://game.boobank.com/(由 [longmaolab/portal](https://github.com/longmaolab/portal) 仓库托管) |
| 服务器路径 | `/opt/games/arena-shooter-3d/` |
| SSH | `ssh root@207.148.98.206` |

---

## 改完代码,部署上线

### Web 客户端改了(scripts / scenes / project.godot)

```bash
# 1) 在 Godot 里:项目 → 导出 → Web → 导出项目(覆盖 docs/)
# 2) 一键发布:
cd /Users/longmao/projects/arena-shooter-3d
./deploy.sh
```

`deploy.sh` 会:`git push` → `ssh 服务器 git pull` → `systemctl restart arena-game`,**5 秒后玩家硬刷新即可**。

### 只改了服务器端(GDScript 但不影响 Web 客户端)

```bash
git push
ssh root@207.148.98.206 'cd /opt/games/arena-shooter-3d && git pull && systemctl restart arena-game'
```

### 只改了门户

```bash
cd /Users/longmao/projects/portal
git add -A && git commit -m "..." && git push
ssh root@207.148.98.206 'cd /opt/games/portal && git pull'
```

---

## 服务器服务管理

进服务器:`ssh root@207.148.98.206`

| 操作 | 命令 |
|---|---|
| 查看 3 个服务状态(应全 active) | `systemctl is-active arena-game caddy cloudflared` |
| 实时看游戏服务器日志 | `journalctl -u arena-game -f` |
| 实时看隧道日志 | `journalctl -u cloudflared -f` |
| 实时看 Web 服务器日志 | `journalctl -u caddy -f` |
| 重启游戏服务器 | `systemctl restart arena-game` |
| 重启隧道 | `systemctl restart cloudflared` |
| 重启 Caddy | `systemctl reload caddy`(配置变更);`systemctl restart caddy`(重启) |
| 看监听端口 | `ss -ltnp \| grep -E ':80\|:7777'` |
| 看内存 | `free -h` |
| 看磁盘 | `df -h /` |

---

## 加新游戏到门户

1. **在新 repo 写好游戏**(假设叫 `tetris-clone`),push 到 GitHub。
2. **服务器 clone + 部署**:
   ```bash
   ssh root@207.148.98.206
   git clone https://github.com/longmaolab/tetris-clone.git /opt/games/tetris-clone
   ```
3. **改 Caddy 配置**(`/etc/caddy/Caddyfile`),加 3 行:
   ```
   handle_path /tetris-clone/* {
       root * /opt/games/tetris-clone/docs
       file_server
   }
   ```
   (如果是联机游戏,再加一段 `handle /tetris-clone/ws { reverse_proxy localhost:<端口> }`)
4. **重载 Caddy**:`systemctl reload caddy`
5. **改门户首页**:`/Users/longmao/projects/portal/index.html` 加一张新卡片,push,服务器 pull。

---

## 常见故障排查

### 玩家访问 https://game.boobank.com/arena-shooter/ 报错

**步骤 1:看 3 个服务**
```bash
ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'
```
任何一个不是 `active` → 看对应日志:
```bash
journalctl -u <服务名> -n 50 --no-pager
```

**步骤 2:从外部探测**

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
| 502 / 521 | Caddy 没起来,或 Caddy 起来但 Godot 没监听 7777 |
| 522 | cloudflared 连不上 Caddy(localhost:80 没监听) |
| 1033 / Tunnel not found | cloudflared 没运行 |
| 404 | Caddy 路由没匹配上 |
| 浏览器 console 报 mixed content | 客户端在用 ws:// 不是 wss://(检查 server.json) |

### 玩家进了游戏但卡顿
- `journalctl -u arena-game -n 100`,看有没有 GDScript 报错
- 看服务器内存:`free -h` —— 如果 swap 在用 → 升级 4GB 套餐
- 看服务器 CPU:`top` —— Godot 进程 > 80% CPU 持续就卡顿

### 改了 Caddyfile 但没生效
```bash
caddy validate --config /etc/caddy/Caddyfile      # 先验证
systemctl reload caddy                             # 不重启的方式重载
journalctl -u caddy -n 20 --no-pager              # 看有没有报错
```

### 隧道偶尔断流
- cloudflared 默认 4 条 HA,部分掉了不影响
- 长时间没连上:`systemctl restart cloudflared`
- 看日志:`journalctl -u cloudflared -n 30 | grep -i 'error\|lost'`

---

## 全局重启(核选项)

服务器有问题但不知道哪里 → 全部重启一次:

```bash
ssh root@207.148.98.206 'systemctl restart arena-game caddy cloudflared && sleep 4 && systemctl is-active arena-game caddy cloudflared'
```

如果连 SSH 都进不去 → Vultr 控制台里 **Server Restart** 强制重启整个虚拟机。所有 systemd 服务会随系统启动自动恢复。

---

## 备份恢复

代码全在 git。**服务器爆掉的话**:

1. 开新服务器(任意厂家,Ubuntu 24.04)
2. 跟着 [SERVER_GUIDE.md](SERVER_GUIDE.md) 走一遍
3. 把 `~/.cloudflared/cert.pem` 和 `82154cfb-...json` 从 Mac scp 过去
4. 完成,30 分钟内可恢复

> Mac 上的 `~/.cloudflared/` 是隧道的真正凭证,**不要丢**。建议复制一份到密码管理器或加密备份。
