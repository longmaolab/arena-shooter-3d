# Arena Shooter 3D

用 Godot 4.6 写的第一人称竞技场对战，**支持联机 PvP**。  
玩法：4 人 PvP，先达到 10 杀获胜。

## 怎么跑起来（Mac）

1. **下载 Godot 4.6**：https://godotengine.org/download/macos/
2. 打开 Godot，点 **Import**，选本目录的 `project.godot`
3. 在 **调试** 菜单 → **运行多个实例** → 选 **2**
4. 按 **⌘+B** 一次开两个窗口
5. 窗口 1 → 点 **Host**
6. 窗口 2 → 点 **Join**（IP 默认 `127.0.0.1`）
7. 互射对打

## 操作

| 键位 | 动作 |
|---|---|
| W A S D | 前后左右移动 |
| 鼠标 | 视角 |
| 空格 | 跳跃 |
| Shift | 冲刺 |
| 鼠标左键 | 射击 |
| R | 换弹 |
| Esc | 释放/捕获鼠标 |
| Enter | 游戏结束后返回菜单 |

## 游戏机制

- **玩家**：100 HP，30 发弹夹，伤害 25/发，换弹 1.4 秒
- **联机架构**：WebSocket，Host/Client 模式，服务器权威伤害判定
- **死亡复活**：HP 归零后瞬移到随机出生点，无敌期 0
- **胜利条件**：先到 10 杀

## 想自己改？打开这些文件

| 想改什么 | 改哪个文件 |
|---|---|
| 玩家速度/血量/伤害/换弹时间 | `scripts/player.gd` 顶部 const |
| 胜利条件、最大玩家数 | `scripts/game.gd`、`scripts/network_manager.gd` |
| 地图布局 | 在 Godot 里打开 `scenes/game.tscn`，拖动 CSGBox3D 节点 |
| 颜色 | `scenes/game.tscn` 里的 Material 资源 |
| 计分板 / HUD | `scripts/hud.gd` + `scenes/hud.tscn` |
| 主菜单外观 | `scripts/main_menu.gd` + `scenes/main_menu.tscn` |

## 项目结构

```
arena-shooter-3d/
├── project.godot
├── scenes/
│   ├── main_menu.tscn   主菜单（Host/Join）
│   ├── game.tscn        竞技场地图
│   ├── player.tscn      联网玩家
│   └── hud.tscn         HUD + 计分板
└── scripts/
    ├── input_setup.gd      autoload：注册按键
    ├── network_manager.gd  autoload：联网状态
    ├── main_menu.gd
    ├── game.gd            场景调度 / 计分 / 胜利判定
    ├── player.gd          玩家移动 / 射击 / 受伤
    └── hud.gd             血量 / 弹药 / 计分榜
```

## 下一步可以加什么

- [ ] 死亡视觉反馈（受击闪红、复活无敌）
- [ ] 武器切换（手枪 / 散弹 / 狙击）
- [ ] 拾取道具（医疗包、弹药盒）
- [ ] 多张地图 + 投票系统
- [ ] 触屏控制（手机能玩）
- [ ] **Web 导出 + 部署到 Cloudflare Pages**（让外网同学打开链接就能玩）
- [ ] 角色模型 + 动画（Mixamo 免费下）
- [ ] 房间码系统（不用记 IP）
