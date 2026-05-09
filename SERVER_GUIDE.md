# 服务器架构与一次性搭建指南

日常运维命令速查见 [OPERATIONS.md](OPERATIONS.md)。
本文档描述**当前架构**和**从零到上线的完整步骤**(用于换服务器或别的域名时复刻)。

---

## 当前架构总览

```
玩家(浏览器/手机)
   │
   ▼  https://game.boobank.com/...
[Cloudflare 边缘网络] (Tokyo / HK / 全球节点)
   │
   ▼  Cloudflare 命名隧道(QUIC,出向连接,无需开放服务器入向端口)
[Vultr Tokyo Ubuntu 24.04 服务器] root@207.148.98.206
   │
   ├── cloudflared.service        ────► localhost:80
   │
   ├── caddy.service (端口 80)
   │     ├── /                     ───► /opt/games/portal/(门户静态页)
   │     ├── /arena-shooter/       ───► /opt/games/arena-shooter-3d/docs/(游戏静态页)
   │     └── /arena-shooter/ws     ───► localhost:7777(反代到 Godot)
   │
   └── arena-game.service          ────► Godot --headless,监听 :7777
                                          (WebSocketMultiplayerPeer)
```

**关键设计**:
- **TLS 在 Cloudflare 边缘终止**,源站只跑 HTTP :80,**不需要管证书**
- **入向 SSH 才开放** (UFW 22/tcp);所有玩家流量都走 cloudflared 出向连接
- **Caddy 同一域名** 同时处理静态文件和 WebSocket(基于路径 / Upgrade 头)
- **多游戏靠路径区分**(`/arena-shooter/`、`/{下个游戏}/`)
- **代码 → 服务器** 全靠 git。服务器 = git 的运行时镜像,**任何东西都能从 git 重建**

---

## 一次性搭建步骤(新服务器或换厂商时按此走)

### 0. 准备前提

- 域名(本项目用 `boobank.com`)已托管到 Cloudflare DNS
- 已在 Cloudflare 创建命名隧道 `arena-shooter` 并 `cloudflared tunnel route dns arena-shooter game.boobank.com`
- Mac 上有 `~/.cloudflared/cert.pem` + `<UUID>.json`(隧道凭证)

如果上述都没有,先在你 Mac 上做一遍:
```bash
brew install cloudflared
cloudflared tunnel login                               # 浏览器选 boobank.com
cloudflared tunnel create arena-shooter                # 生成 UUID + JSON
cloudflared tunnel route dns arena-shooter game.boobank.com
```

### 1. 开 VPS

任意 Linux VPS 都行,本项目用 **Vultr Tokyo Cloud Compute Shared CPU $12/mo**:
- 2GB RAM / 1 vCPU / 55GB SSD / 2TB 流量
- Ubuntu 24.04 LTS x64
- 添加 SSH key

### 2. SSH 进去 + 系统初始化

```bash
ssh root@<IP>

apt-get update && apt-get upgrade -y
apt-get install -y curl wget git unzip ufw htop tmux jq ca-certificates

timedatectl set-timezone Asia/Shanghai
hostnamectl set-hostname arena-game

# 防火墙:只放 SSH。游戏流量走 cloudflared 出向连接,不需要入向端口。
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable
```

### 3. 装 cloudflared

```bash
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main' | tee /etc/apt/sources.list.d/cloudflared.list
apt-get update && apt-get install -y cloudflared
```

### 4. 把 Mac 上的隧道凭证传到服务器

**在 Mac 上**:
```bash
ssh root@<IP> 'mkdir -p /etc/cloudflared && chmod 700 /etc/cloudflared'
scp ~/.cloudflared/cert.pem ~/.cloudflared/<UUID>.json root@<IP>:/etc/cloudflared/
ssh root@<IP> 'chmod 600 /etc/cloudflared/*.json /etc/cloudflared/cert.pem'
```

**回服务器**,写 cloudflared 配置:
```yaml
# /etc/cloudflared/config.yml
tunnel: arena-shooter
credentials-file: /etc/cloudflared/<UUID>.json

ingress:
  - hostname: game.boobank.com
    service: http://localhost:80
  - service: http_status:404
```

```bash
cloudflared --config /etc/cloudflared/config.yml tunnel ingress validate   # 应输出 OK
```

### 5. 装 Godot 4.6.2 headless

```bash
cd /tmp
wget https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip
unzip Godot_v4.6.2-stable_linux.x86_64.zip
mv Godot_v4.6.2-stable_linux.x86_64 /usr/local/bin/godot
chmod +x /usr/local/bin/godot
godot --version    # 应输出 4.6.2.stable.official...
```

### 6. clone 仓库

```bash
mkdir -p /opt/games
git clone https://github.com/longmaolab/arena-shooter-3d.git /opt/games/arena-shooter-3d
git clone https://github.com/longmaolab/portal.git /opt/games/portal
cd /opt/games/arena-shooter-3d
godot --headless --path . --import     # 生成 .import 文件(已在 git 里就跳过)
```

### 7. 装 Caddy

```bash
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
apt-get update && apt-get install -y caddy
```

`/etc/caddy/Caddyfile`:
```
{
	auto_https off
	admin off
}

:80 {
	# Arena Shooter 3D
	handle /arena-shooter/ws {
		reverse_proxy localhost:7777
	}
	handle_path /arena-shooter/* {
		root * /opt/games/arena-shooter-3d/docs
		file_server
	}
	handle /arena-shooter {
		redir /arena-shooter/ permanent
	}

	# Portal (root)
	handle {
		root * /opt/games/portal
		file_server
	}
}
```

```bash
caddy validate --config /etc/caddy/Caddyfile     # 应输出 Valid configuration
```

### 8. systemd 单元

`/etc/systemd/system/arena-game.service`:
```ini
[Unit]
Description=Arena Shooter 3D Dedicated Game Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/games/arena-shooter-3d
Environment=GODOT_BIN=/usr/local/bin/godot
Environment=GODOT_SILENCE_ROOT_WARNING=1
Environment=PORT=7777
ExecStart=/opt/games/arena-shooter-3d/run_server.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

cloudflared 自带 systemd 单元生成命令:
```bash
cloudflared service install
```

### 9. 全部启动

```bash
systemctl daemon-reload
systemctl enable --now arena-game caddy cloudflared
sleep 4
systemctl is-active arena-game caddy cloudflared       # 三个都应是 active
```

### 10. 验证

```bash
# 在你 Mac 上(或任何机器)
curl -I https://game.boobank.com/                            # 200, 门户
curl -I https://game.boobank.com/arena-shooter/              # 200, 游戏页
curl -s https://game.boobank.com/arena-shooter/server.json   # {"url": "wss://..."}

# WSS 握手(应回 101 Switching Protocols)
python3 -c "
import ssl, socket, base64, os
ctx = ssl.create_default_context()
sock = socket.create_connection(('game.boobank.com', 443), timeout=10)
s = ctx.wrap_socket(sock, server_hostname='game.boobank.com')
key = base64.b64encode(os.urandom(16)).decode()
req = (
    'GET /arena-shooter/ws HTTP/1.1\r\nHost: game.boobank.com\r\n'
    'Upgrade: websocket\r\nConnection: Upgrade\r\n'
    f'Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n'
)
s.sendall(req.encode())
print(s.recv(2048).decode(errors='replace')[:200])
"
```

打开浏览器 https://game.boobank.com/arena-shooter/ → 选角色 → Join → 上线!

---

## 加新游戏到这套架构

参考 [OPERATIONS.md](OPERATIONS.md) 的"加新游戏"一节。简单说就是:

1. 仓库 clone 到 `/opt/games/<game>/`
2. Caddy 加 `handle_path /<game>/*` 一段
3. 联机的话再加 `handle /<game>/ws { reverse_proxy localhost:<端口> }` 和对应的 systemd 单元

---

## 故障排查

见 [OPERATIONS.md](OPERATIONS.md) 的"常见故障排查"章节。
