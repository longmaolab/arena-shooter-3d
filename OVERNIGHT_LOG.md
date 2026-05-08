# Overnight Autonomous Session — 2026-05-09

> AI 助手在用户睡觉期间的工作日志。
> 早上你只看这份就知道发生了什么。

---

## 闭环验证

✅ **CLI 导出可用**：`~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" docs/index.html` 一行能完整导出 Web 包，不需要打开 GUI。这是整个夜里能闭环的关键。

✅ **完整流水线**：改代码 → **`rm -rf .godot/exported .godot/imported`** → CLI 导出 → `find docs -name "*.import" -delete` → commit → push → 等 ~60s GitHub Pages 部署 → Chrome MCP 检查 console / 截图 / DOM。

⚠️ **重要陷阱**：CLI 导出会用 `.godot/exported/` 里的旧 .gdc 编译产物，**即便源代码改了也可能不会重编**。我第一次因此白跑了一轮（pck 大小都增了，但 main_menu 改动没生效）。**每次 export 之前都得清缓存**。

❌ **不能做**：截图 Godot 渲染的 canvas（计算机使用工具需要弹窗授权，你睡了）。所以无法目视判断画面质感，只能靠代码审计 + 控制台错误。

---

## 提交时间线

| 时间 | Commit | 说明 |
|---|---|---|
| (你睡前) | `fc73260` | v6.3 移动端触屏改进（按钮 DPI 缩放、按下反馈、摇杆死区、look 死区、视角灵敏度降低） |
| ~20 min | `e85638d` | v6.4 第一轮自动调优（见下） |
| ~35 min | `709333e` | v6.4.1 修 server.json 加载死锁（HOTFIX） |
| ~40 min | `1a8f384` | v6.4.1 重编 pck（之前的 export 用了 .godot/exported/ 旧 .gdc 缓存导致改动没真的进 pck） |
| ~50 min | `805e245` | v6.4.2 加诊断 probe 验证 pipeline |
| ~55 min | `7e464f3` | v6.4.3 改 JS 轮询用字符串 sentinel |
| ~60 min | `d569ebb` | v6.4.4 加 `console.log` 诊断（追踪 JS eval 实际行为） |
| ~75 min | `9545381` | **v6.5 大改：把生产 wss URL 写死进 default**，server.json 降为软覆盖 |
| ~80 min | `e0ee00f` | v6.5.1 加 cache-bust shim（每个新 build 强制重拉 pck/wasm/js）|

---

## 第 1 轮：手感 + RPC 竞态修复

### 工作流程

派出 **2 个并行 Explore 代理**做静态审计：
1. 代理 A：手感 audit（player.gd, hud.gd, touch_controls.gd, scenes/*.tscn）
2. 代理 B：网络/生命周期 audit（game.gd, network_manager.gd, stats_store.gd, main_menu.gd）

总共发现 **30 个**问题（15+15）。我做了 95% 把握的"小改动"，跳过涉及新资源 / 重构 / 边缘场景的那些。

### 已应用 — 手感（9 项）

| 项目 | 旧 | 新 | 文件 |
|---|---|---|---|
| 跳跃速度 / 重力 | 7.0 / 22 | 8.5 / 24 | player.gd:12-13 |
| 动画过渡 | `play(name)` 直接切 | `play(name, 0.12)` 12ms 渐变 | player.gd:_play_anim |
| 上下视角钳制 | ±1.4 rad（80°） | ±1.25 rad（72°） | player.gd 两处 |
| 命中提示动画 | scale 120ms + fade 250ms | scale 60ms + fade 140ms（snappy） | hud.gd:_on_hit_marker |
| 受伤遮罩积累 | 系数 0.012，封顶 0.7 | 系数 0.007，封顶 0.45 | hud.gd:_on_damage_taken |
| 枪口光持续 | 0.10s | 0.15s（60fps 下从 6 帧→9 帧可见） | player.gd:_flash_muzzle |
| 死亡黑屏淡入 | 0.15s 太突兀 | 0.35s 给冲击力的喘息 | hud.gd: DEATH_FADE_IN |
| 准星 | font 36 / alpha 0.85 | font 48 / alpha 0.92 / outline 5 | scenes/hud.tscn |
| 3D 音频衰减 | unit_size 8 / max 60m | 4 / 50m（远近能听出来） | scenes/player.tscn |

### 已应用 — RPC 竞态 / 安全（3 项）

| 项目 | 修法 | 文件 |
|---|---|---|
| `take_damage_remote` 在被打者节点 queue_free 后到达 | 加 `is_instance_valid` + `is_queued_for_deletion` 检查 | game.gd:server_report_hit |
| `take_damage_remote` 验证顺序：先 sender 后 authority | 改成 authority 优先，永不在非权威节点改状态 | player.gd:take_damage_remote |
| `_remote_state` RPC 在 `queue_free` 后仍会发 | physics_process 加 `is_inside_tree() and not is_queued_for_deletion()` 守卫 | player.gd:_physics_process |

### 故意没改的（30 项里跳过的 18 项）

- **加摄像机 bob**（土，但需要新逻辑，不在 95% 把握里）
- **加跳跃音效**（缺音频资源，需要去 Kenney 找新文件）
- **加换弹动画**（GLB 里不一定有 reload anim，要先确认）
- **`_start_new_game` 双重 respawn 守卫**（边缘场景，朋友局基本碰不到）
- **player dict desync invincible 广播**（按设计就是服务器单边状态，无需广播）
- **stats.json 每次击杀就落盘**（防崩溃，但磁盘抖动，朋友局接受）
- **late-joining peer 看到旧 leaderboard**（交互窗口很小）
- **`_show_respawn` 命名 / 重构**（不影响行为）
- **Audio2D 用作脚步音/受伤音**（资源缺失）
- **代理 A 关于 move_toward 'slidey' 的判断**（实际读代码 deceleration 已是瞬时，agent 误判）
- **代理 A 关于 fire-rate 'sluggish' 的判断**（120ms cadence 是设计选择）
- **代理 A 关于 first-person arm 可见**（model_holder 在 `_setup_authority_visuals` 已 hide，无 bug）

---

## 第 2 轮：server.json fetch 死锁 + 浏览器缓存

**起因**：Chrome MCP smoke test 发现 v6.2 的 "Join 按钮等 server.json 加载完才解锁" 是个回归 —— Godot 4.6 web 单线程 build 的 `HTTPRequest.request_completed` 信号根本不触发，所以 Join 永远是禁用的。朋友点不开。

**绕过 1（v6.4.1-v6.4.4）**：用 `JavaScriptBridge.eval` 调浏览器原生 `fetch`，写到 `window.__sj_url`，GDScript 轮询。结论是 fetch 本身能用，但 GDScript `await` 协程很可能因为 `_ready` 没 await 它而被 GC，所以读不到。

**最终方案（v6.5）**：直接放弃这条路，把生产 URL **写死** 进 `NetworkManager.default_server_url := "wss://game.boobank.com"`。server.json 退化为"如果加载成功就软覆盖"，Join 按钮**永远立刻可用**。如果将来换隧道，改这个常量重新编一次就行。

**额外收获（v6.5.1）**：发现一个潜在的用户痛点 —— **Godot Web 重新部署后，回访的浏览器还会用缓存的旧 pck**。写了 `scripts/post_export.sh`，自动给 `index.html` 注入一个 fetch 拦截器，把 `?v=<pck-hash>` 加到所有 `.pck/.wasm/.js` URL 上。现在新 build = 新 hash = 新 URL = 必定 cache miss。**这个修复对朋友升级体验帮助巨大**，以前你 push 了新版本他们要手动 hard-refresh，现在自动生效。

✅ 已经在 Chrome MCP 里端到端验证：fresh tab 加载 → 日志 `[main_menu] fetching server.json (via JS, soft override)` → JS fetch 拿到 `wss://game.boobank.com` → Join 按钮可用。

---

## 你早上要做的

如果觉得**任何一项调过头**，找对应文件改回去，或者：

```bash
git diff e85638d~1 e85638d   # 看这一轮所有改动
git revert e85638d            # 整轮回退
```

如果**手感更好了**，继续下一轮调（见下面"待办池"）。

---

## 还没动的待办池（明天可以挑）

### 手感（需要新增逻辑）
- [ ] 摄像机 bob（落地 + 冲刺时纵向轻摇 0.05m）
- [ ] 准星击中时短暂放大 1.5x（增加 hit feedback）
- [ ] 武器后坐力（开枪时 camera.rotation.x += 0.02 然后回弹）
- [ ] 脚步音（需要找 CC0 footsteps 包）
- [ ] 跳跃音效（同上）

### 网络（边缘场景）
- [ ] 防止 _start_new_game 给在 respawn 中的玩家再 respawn 一次
- [ ] late-joining peer 收到当前 game_over / countdown 状态
- [ ] StatsStore 每次击杀就落盘（trade-off 自己定）

### 视觉
- [ ] 弹道轨迹粗细随距离变化（远的更细）
- [ ] 击杀时受害者 ragdoll 或者 fall-back 动画
- [ ] 复活点视觉提示（光柱）

### UX
- [ ] 主菜单加按钮"快速本地测试"，自动开 host + 起 dummy bot

---

## 下一轮（自动）

预计 ~30 分钟后再起一轮。每轮做的事：
1. Chrome MCP 重新加载游戏，看 console 有无新错误
2. 跑下一个 agent 做更深的 audit
3. 应用 < 5 个高把握改动
4. CLI 导出 + push
5. 更新本日志的"提交时间线"

如果某轮发现严重问题、需要决策、或 export 失败 —— **会立刻停下不再 push**，等你早上看。
