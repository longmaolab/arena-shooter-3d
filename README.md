# Arena Shooter 3D

第一人称竞技场对战，**最多 8 人 PvP**。  
用 Godot 4.6 + WebSocket 做的客户端-服务器架构。

🎮 **现场玩**：https://longmaolab.github.io/arena-shooter-3d/

（需要服务器在线，见下方指南）

## 怎么玩

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 |
|---|---|---|---|---|---|
| 电脑 | WASD | 鼠标 | 空格 | 左键 | R |
| 手机 | 左下虚拟摇杆 | 右半屏滑动 | 蓝键 | 红键 | 黄键 |

**胜利条件**：先到 10 杀。胜利后 5 秒倒计时自动开始下一局。

## 文件总览

```
arena-shooter-3d/
├── project.godot          Godot 项目入口
├── export_presets.cfg     Web 导出配置
├── run_server.sh          ← 一键启动服务器（Mac）
├── deploy.sh              ← 一键推送 docs/ 到 GitHub Pages
├── docs/                  ← Web 客户端构建产物（GitHub Pages 服务）
│   └── server.json        ← 当前服务器 URL（每次开服更新）
├── scenes/
│   ├── main_menu.tscn     主菜单
│   ├── game.tscn          竞技场
│   ├── player.tscn        玩家
│   ├── hud.tscn           HUD + 计分板
│   └── touch_controls.tscn 手机触屏 UI
└── scripts/
    ├── input_setup.gd     按键映射 (autoload)
    ├── network_manager.gd 联网状态 (autoload)
    ├── main_menu.gd       主菜单逻辑 + --server 启动检测
    ├── game.gd            场景调度 + 计分 + 新开局
    ├── player.gd          玩家移动 + 射击 + 受伤反馈
    ├── hud.gd             HUD + 屏幕受伤提示
    └── touch_controls.gd  虚拟摇杆
```

## 自己跑（本机调试）

1. Godot 4.6 打开 `project.godot`
2. **调试 → 运行多个实例 → 2**
3. ⌘+B 同时开两个窗口
4. 窗口 1 → Host
5. 窗口 2 → Join（IP 默认 127.0.0.1）

## 跟同学联机

完整步骤见 **[SERVER_GUIDE.md](SERVER_GUIDE.md)**：

简版：
1. `./run_server.sh` 跑服务器
2. `cloudflared tunnel --url http://localhost:7777` 暴露成公网
3. 把得到的 URL 写进 `docs/server.json`，git push
4. 把 https://longmaolab.github.io/arena-shooter-3d/ 发给同学

## 部署 Web 客户端

```bash
# 1. 在 Godot 里：项目 → 导出 → Web → 导出项目（路径默认 docs/index.html）
# 2. 推送：
./deploy.sh
```

## 进阶 / TODO

- [ ] 多房间系统（房间码加入）
- [ ] 永久服务器 URL（Cloudflare 命名隧道）
- [ ] 武器切换
- [ ] 死亡音效（拖个 freesound.org 的 .ogg 进去）
- [ ] 角色模型 + 动画
- [ ] 24h 在线服务器（Fly.io / Hetzner VPS）
