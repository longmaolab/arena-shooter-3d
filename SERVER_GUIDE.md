# 服务器运维指南

每次想跟同学联机时，按这套流程做。

---

## 一次性准备（30 分钟，只做一次）

### 1. 安装 Cloudflare Tunnel

```bash
brew install cloudflared
```

### 2. 验证 Godot 路径

`run_server.sh` 默认假设 Godot 在 `/Applications/Godot.app`。确认：

```bash
ls /Applications/Godot.app/Contents/MacOS/Godot
```

如果路径不同，编辑 `run_server.sh` 改 `GODOT_BIN`。

---

## 每次开战流程（5 分钟）

### 步骤 1：在 Mac 上启动游戏服务器

打开**终端窗口 1**：
```bash
cd /Users/longmao/projects/arena-shooter-3d
./run_server.sh
```

应该看到：
```
→ Starting headless game server on port 7777...
[server] listening on port 7777
```

⚠️ 这个终端**别关**。

### 步骤 2：开 Cloudflare Tunnel

打开**终端窗口 2**：
```bash
cloudflared tunnel --url http://localhost:7777
```

几秒后会看到一段类似这样的输出：
```
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at:                                          |
|  https://abc-def-xyz-123.trycloudflare.com                                                 |
+--------------------------------------------------------------------------------------------+
```

**复制那个 https URL**。

⚠️ 这个终端也**别关**，关了同学就连不上了。

### 步骤 3：把 URL 写进 server.json 并推送

打开**终端窗口 3**：
```bash
cd /Users/longmao/projects/arena-shooter-3d

# 把上面的 URL 写进配置（注意 https → wss）
cat > docs/server.json <<'EOF'
{
  "url": "wss://abc-def-xyz-123.trycloudflare.com"
}
EOF

# 用你刚才那个真实的 URL 替换上面的 abc-def-xyz-123

git add docs/server.json
git commit -m "Update server URL"
git push
```

约 1 分钟后 GitHub Pages 更新完毕。

### 步骤 4：把链接发给同学

```
https://longmaolab.github.io/arena-shooter-3d/
```

同学手机/电脑打开，按一下 **Join**（地址已自动填好），开打！

---

## 关服务器

- 在终端 1 按 `Ctrl+C`
- 在终端 2 按 `Ctrl+C`

下次重新启动，每次 cloudflared 给的 URL 都不一样，所以**每次都要重新走一遍步骤 2 和 3**。

---

## 想要永久 URL（高级）？

每次 URL 变要 push 比较烦。如果想固定 URL：

1. 注册 Cloudflare 账号（免费）+ 买/转一个域名（最便宜的 .xyz 约 ¥10/年）
2. 把域名托管到 Cloudflare
3. 用 `cloudflared tunnel create arena` 创建命名隧道
4. 用 `cloudflared tunnel route dns arena game.你的域名.xyz` 绑定
5. 之后启动用 `cloudflared tunnel run arena`，URL 永远是 `wss://game.你的域名.xyz`

跳过这一步也完全可以玩，只是要多 push 一次 server.json。

---

## 常见问题

### 同学打开链接看到 "Connection failed"
- 你的服务器（终端 1）跑着吗？
- cloudflared（终端 2）跑着吗？
- 浏览器 F12 看 Console，截图发我

### server.json 推上去了但同学没生效
- GitHub Pages 缓存约 1-2 分钟，让同学**强制刷新**（手机：长按刷新键 → 不缓存重载）
- 或者手动加查询参数：`https://longmaolab.github.io/arena-shooter-3d/?v=2`

### 服务器报错关闭了
- 终端 1 输出里看 Error
- 重新跑 `./run_server.sh`
- 重新跑 `cloudflared`（URL 会变，要更新 server.json）

### 同学进了游戏但卡住
- 原因可能是 cloudflared 不稳定或限流
- 重启 cloudflared，更新 URL，让同学重连
