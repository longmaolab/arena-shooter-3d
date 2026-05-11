# v5 LAN Testing Guide (HISTORICAL)

> ⚠️ **This document is outdated.** It describes the v5 / pre-bot LAN smoke
> test. For current two-window editor testing instructions, see
> [KIDS_GUIDE.md](KIDS_GUIDE.md) Part 3.
> Kept here as a development-history snapshot.

> ⚠️ **这个文档已过期。** 这是 v5 / 引入 bot 之前的 LAN 冒烟测试说明。
> 当前的双窗口编辑器测试流程见 [KIDS_GUIDE.md](KIDS_GUIDE.md) 第 3 部分。
> 保留在这里作为开发历史快照。

---

# v5 联机阶段 1 — 本地测试指南

## 验收目标
**两个 Godot 窗口同时打开，一个 Host 一个 Join，能互相对打到 10 杀。**

## 怎么测（5 步）

### 1. 在 Godot 里打开两个窗口
- 先按 ⌘+B 启动游戏 → 窗口 1
- **保持窗口 1 不关**，**回到 Godot 编辑器再按 ⌘+B** → 窗口 2

### 2. 窗口 1：开主机
- 看到主菜单 → 点 **Host** 按钮
- 应该进入竞技场，能用 WASD 移动

### 3. 窗口 2：加入
- 看到主菜单 → IP 框已填 `127.0.0.1`
- 点 **Join** 按钮
- 应该进入同一个竞技场，能看到窗口 1 的玩家（彩色胶囊 + 头顶 P1 名字）

### 4. 互打
- 鼠标左键射击对方
- 看到对方掉血、被击杀、复活
- 右上角计分板显示双方击杀数

### 5. 决出胜负
- 先到 10 杀的一方屏幕中央显示"你赢了！"
- 另一方显示对方名字 + "赢了"
- 按 Esc 返回主菜单

## 操作
| 键 | 动作 |
|---|---|
| WASD | 移动 |
| 鼠标 | 视角 |
| 空格 | 跳 |
| Shift | 冲刺 |
| 左键 | 射击 |
| R | 换弹 |
| Esc | 释放鼠标 / 游戏结束后返回菜单 |

## 出错排查

### "Host 失败"
- 可能端口 7777 被占用 → 改 `network_manager.gd` 里的 `PORT` 常量

### "连接失败 — 请确认主机已开"
- 窗口 1 没先点 Host，或者关掉了
- 顺序必须：**先 Host，后 Join**

### 看不到对方
- 看 Godot 输出面板有没有红字错误
- 把窗口 1 和窗口 2 各自的输出截图发我

### 玩家位置卡顿/抖动
- 正常的网络同步抖动，本地两个窗口几乎不会有
- 如果严重，调 `player.gd` 里的 `SYNC_INTERVAL`（越小越平滑越费 CPU）

## 阶段 2 预告（下次做）
- Web 导出（HTML5 + WebAssembly）
- 部署到 Cloudflare Pages 或 Fly.io（让同学外网能连）
- 触屏控制（手机能玩）
- 房间码系统（不用记 IP）
