# Arena Shooter 3D — Kid's Guide

> 📘 English version first. 中文版在文件下半部分 ([跳到中文](#arena-shooter-3d--操作手册中文)).

> Hey kid: this is the multiplayer shooter you and your friends play and modify.
> Everything you need is laid out below — read it top to bottom.

---

## 🎮 Part 1: How to play

### Controls

| Device | Move | Look | Jump | Shoot | Reload | Switch weapon |
|---|---|---|---|---|---|---|
| Desktop | W / A / S / D | Mouse | Space | Left click | R | **Number keys 1 / 2 / 3** |
| Mobile | Left thumb stick | Right-half drag | JUMP button | FIRE button | RELOAD button | PIS / SMG / SHG chips |

### The two big menu buttons

- **▶ PLAY** (green) — go online, connect to the remote server and play with friends
- **🤖 PLAY vs BOTS** (purple) — pick 1 / 2 / 3 bots and practice solo
  - **On web**: fully local, no internet needed
  - **On desktop**: also opens a LAN host that friends can join

### Game rules

- **Win condition**: first to **10 kills** wins (counts kills against humans + bots)
- **When you die**: black screen → **wait 2.5 seconds** → teleport to the spawn point farthest from enemies → 1.5 s invincibility (character blinks)
- **After a match ends**: 5-second countdown in the screen center → next round auto-starts, scores reset

### Three weapons (press 1 / 2 / 3 to switch)

| Key | Weapon | Damage (body / head) | Mag | Fire rate | Best for |
|---|---|---|---|---|---|
| 1 | 🔫 **Pistol** | 50 / 100 | 12 | Slow | Long range + headshot one-shot |
| 2 | 💨 **SMG** (default) | 25 / 50 | 30 | Fast | Mid-range sustained |
| 3 | 💥 **Shotgun** | 18 / 36 × 5 pellets | 8 | Very slow | Point-blank ~90 damage |

> 💡 **Headshot detection**: if your crosshair lands on the upper third of an enemy, damage is ×2 and red `HEAD! -50` floats up from the impact.

### Map pickups (**find them!**)

- 🚀 **Jump pads** (cyan glowing discs, ×3) — step on one to launch 5 m into the air; lets you jump straight from the ground onto the bridge
- ❤️ **Health packs** (white box with red cross, ×2) — walk over for +50 HP (one on the bridge, one in the SW corner)
- 🔫 **Ammo crates** (amber glowing wooden boxes, ×2) — walk over for full ammo on all three weapons (one in the east tunnel, one in the NE corner)
- Once picked up, they **disappear for 30 seconds** and then respawn automatically

### Killstreak banners 🔥

If you keep killing without dying, the screen center flashes:

| Streak | Banner | Color |
|---|---|---|
| 2 | 🔥 DOUBLE KILL | Yellow |
| 3 | 🔥 TRIPLE KILL | Orange |
| 5 | 🔥 RAMPAGE | Red |
| 7 | 🔥 GODLIKE | Purple |

Die once → streak resets to 0, build it back up.

### Scoreboard

- **In-game top-right**: live K / D for everyone in this match
- **Menu right panel**: all-time leaderboard (sorted by wins, persisted forever)

> First launch picks a random English name + random skin for you. Change them once and they'll stick next time.

---

## 🚀 Part 2: Letting friends play

**Good news: the server runs 24/7 on a VPS, so you and Dad don't have to do anything**. Just share the link:

```
https://game.boobank.com/arena-shooter/
```

Friend opens it → picks a character → clicks **PLAY** → connected!

### Want to play solo vs bots (no internet)

Open the same link, click the purple **PLAY vs BOTS** button, pick 1/2/3 bots, and go. This doesn't need the server, so it still works on a flaky Wi-Fi.

### Server-check commands (Dad uses these occasionally)

If a friend says "I can't connect", have Dad SSH the VPS:

```bash
ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'
# all three should be: active

ssh root@207.148.98.206 'journalctl -u arena-game -n 30 --no-pager'
# recent game-server log
```

Full ops commands in [`OPERATIONS.md`](OPERATIONS.md).

---

## ✏️ Part 3: Modifying the game (small tweaks)

### Open the project in Godot

1. Launch Godot 4.6.2
2. Click **Import** → pick `/Users/longmao/projects/arena-shooter-3d/project.godot`
3. You're in the editor

### Local testing after edits

- Top menu **Debug → Run Multiple Instances → 2** (so two windows open at once, simulating two players)
- Press **⌘ + B** to launch both windows
- Window 1: pick a character → click **🤖 PLAY vs BOTS** (this window becomes the local host)
- Window 2: just click **▶ PLAY** (the IP field is pre-filled with `ws://127.0.0.1:7777`)

### Common tweaks cheatsheet

| What to change | File | Line |
|---|---|---|
| **Walk speed** | `scripts/player.gd` | `const SPEED := 6.0` |
| **Sprint speed** | `scripts/player.gd` | `const SPRINT_SPEED := 10.0` |
| **Jump height** | `scripts/player.gd` | `const JUMP_VELOCITY := 8.5` |
| **Jump pad boost** | `scripts/jump_pad.gd` | `const JUMP_BOOST := 16.0` |
| **Max HP** | `scripts/game.gd` | `const SERVER_MAX_HEALTH := 100` |
| **All 3 weapon stats** (damage / mag / fire rate / spread) | `scripts/player.gd` | `const WEAPONS := [...]` |
| **Server damage table** (body / headshot) | `scripts/game.gd` | `const SERVER_WEAPON_DAMAGE := [...]` |
| **Respawn delay after death** | `scripts/game.gd` | `const SERVER_RESPAWN_DELAY := 2.5` |
| **Post-respawn invincibility** | `scripts/game.gd` | `const SERVER_RESPAWN_INVINCIBILITY := 1.5` |
| **Kills to win** | `scripts/game.gd` | `const KILLS_TO_WIN := 10` |
| **New-round countdown** | `scripts/game.gd` | `const NEW_GAME_DELAY := 5.0` |
| **Bot view range / fire interval** | `scripts/player.gd` | `const BOT_VIEW_RANGE := 22.0` etc |
| **Streak thresholds** | `scripts/game.gd` `_handle_kill` | `if streak == 2 or 3 or 5 or 7:` |
| **Health pack heal amount** | `scripts/pickup.gd` | `@export var heal_amount: int = 50` |
| **Pickup respawn time** | `scripts/pickup.gd` | `@export var respawn_time: float = 30.0` |
| **Max players** | `scripts/network_manager.gd` | `const MAX_PLAYERS := 8` |
| **Default random names** | `scripts/network_manager.gd` | `const COMMON_NAMES := [...]` |

### Editing the map

- Open `scenes/game.tscn` in the Godot editor
- In the scene tree, the CSGBox3D nodes under `Game` (Floor, Wall_, Cover_, Tower_, Bridge_, Stair_, Tunnel_, Platform_) — drag their position / `size` to reshape walls, the bridge, stairs
- `Pickups` contains 8 items (HP_ / AM_ / JumpPad_) — drag to change where they appear
- `SpawnPoints` contains 6 Marker3D nodes — drag to change where players spawn

### Adding / removing the default bot count

The main menu's 1 / 2 / 3 buttons set the count. To make the default 3 instead of 2:

- In `scenes/main_menu.tscn`, find the `Bot2` node → copy `button_pressed = true` to `Bot3`, remove it from `Bot2`

---

## 🌐 Part 4: Pushing changes so friends see them

After editing code, **the web version won't auto-update**. Three steps:

### Step ① Export from Godot

1. Top menu **Project → Export**
2. Pick **Web (Runnable)** → click **Export Project**
3. Leave the path as default (`docs/index.html`) → save
4. Wait a few seconds for the export to finish

### Step ② Clean up Godot editor leftovers

In a terminal:

```bash
cd /Users/longmao/projects/arena-shooter-3d
find docs -name "*.import" -delete
```

### Step ③ Push to the VPS

```bash
./deploy.sh
```

Or manually:

```bash
git add -A
git commit -m "Update game: write what you changed here"
git push
```

> After pushing, hold ⌘+Shift+R in the browser to force a refresh. Friend should see the new version within a few seconds.

---

## 🐛 Part 5: Common problems

### Q1: Friend opens the page but PLAY does nothing / "Connection failed"
- The server runs 24/7 on the VPS, so it depends on whether the VPS services are alive
- Have Dad SSH in: `ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'`
- All three should say `active`. If any aren't, restart it: `ssh root@207.148.98.206 'systemctl restart arena-game'`
- Meanwhile your friend can click the purple **PLAY vs BOTS** for offline single-player while you fix the server

### Q2: Two-window debug, the second one fails to PLAY
- Window 1 must click **🤖 PLAY vs BOTS** first (so it becomes the local host)
- Window 2's IP field is already filled with `ws://127.0.0.1:7777`, **just click PLAY**
- If you changed the IP field, change it back to `ws://127.0.0.1:7777`

### Q3: Chinese characters show as squares in the browser
- Godot's Web export doesn't include CJK fonts (they'd bloat the wasm)
- Keep menu text in English / digits / symbols / emoji only

### Q4: Editor shows a flood of "Node not found: Game/Players/N"
- This used to happen when window 2's game scene wasn't loaded yet but window 1 was already broadcasting positions → fixed in v6.17: every player waits 1.5 s before its first state broadcast
- A few of these on the very first frame are still harmless — game runs fine

### Q5: Bullets don't hit anyone
- Fixed in v6.6: each Kenney character limb (hand / foot / head) has its own StaticBody3D collider, so the ray hits a child node rather than the main body. The shoot logic walks up the parent chain to find the right player.
- See `_find_player_root()` in `scripts/player.gd`
- There's also **headshot detection**: hits above Y > 1.4 m deal 2× damage

### Q6: Bots are too hard / too easy
- They spot you from too far → change `player.gd::BOT_VIEW_RANGE` (default 22 m → 12 m makes them "near-sighted")
- They fire too fast → `BOT_FIRE_INTERVAL` default 0.7 s → bump to 1.5 to slow them
- They never give up the chase → `BOT_LOSE_RANGE` default 30 m → smaller value makes them lose interest sooner

### Q7: Edited a file in Godot but the game doesn't reflect it
- Did you save? (a `*` in the title bar means unsaved)
- Try **Project → Reload Current Project**
- If still stuck, fully close and reopen Godot

### Q8: Mobile keyboard doesn't pop up
- Already fixed: `virtual_keyboard_enabled` is on in Project Settings
- Tapping the name input should bring it up

### Q9: Friends still see the old version
- Their browser cached the old pck. Have them **hard refresh**: ⌘+Shift+R (Mac) or Ctrl+Shift+R (Windows)
- Or fully close the tab and reopen

---

## 📁 Part 6: What each file is

```
arena-shooter-3d/
├── project.godot              ← Open this file in Godot
├── README.md                  ← Full README (developer overview)
├── KIDS_GUIDE.md              ← The one you're reading
├── OPERATIONS.md              ← VPS ops cheatsheet (Dad reads)
├── SERVER_GUIDE.md            ← VPS architecture + one-time setup
├── deploy.sh                  ← Deploy: git push + ssh server git pull + import + restart
├── run_server.sh              ← Local dedicated-server launcher (dev use; same script the VPS systemd unit calls)
│
├── scripts/                   ← All GDScript code
│   ├── player.gd              Player movement / shooting / weapons / bot AI / animations
│   ├── game.gd                Game rules / scoring / death / respawn / server damage table
│   ├── network_manager.gd     Connection state / player roster / settings
│   ├── hud.gd                 HP card / ammo / scoreboard / kill banner / streak banner
│   ├── main_menu.gd           Menu logic (PLAY / PLAY vs BOTS / bot count / name)
│   ├── pickup.gd              ❤️ Health pack + 🔫 ammo crate (visuals + pickup logic)
│   ├── jump_pad.gd            🚀 Jump pad (boost + glow pulse)
│   ├── stats_store.gd         Leaderboard persistence (JSON file)
│   ├── touch_controls.gd      Mobile joystick + action buttons + weapon chips
│   └── input_setup.gd         Keyboard / mouse key mappings
│
├── scenes/                    ← Scenes (open in Godot)
│   ├── main_menu.tscn         Main menu + leaderboard
│   ├── game.tscn              Arena (map + Pickups + SpawnPoints)
│   ├── player.tscn            Player (CharacterBody3D + Camera + Audio)
│   ├── hud.tscn               In-game HUD
│   └── touch_controls.tscn    Mobile control overlay
│
├── models/characters/         ← 18 Kenney blocky character GLBs
├── audio/                     ← Shoot / hit / death / respawn
├── fonts/                     ← Russo One (menu display font)
├── themes/                    ← arena_theme.tres (unified font theme)
└── docs/                      ← Web export output (Caddy serves this on the VPS)
```

---

## 🌟 Stretch ideas (real challenges)

Most basics are already done. Things that are still worth attempting:

1. **Weapon recoil**: on shoot, temporarily nudge `camera.rotation.x` up by 0.02 rad and let it ease back → punchy feel
2. **Map rotation**: copy `scenes/game.tscn` into `arena2.tscn`; each match randomly picks one
3. **Team mode**: pick red / blue team before the match, friendly fire off, first to 20 kills wins
4. **Room codes**: friends enter a 4-digit room number to join a specific lobby
5. **Crown on the leader**: add a 👑 emoji label above whoever currently leads
6. **Weapon pickups**: turn weapons into world items (Quake-style); on death you drop your current weapon
7. **Bot difficulty setting**: add Easy / Normal / Hard buttons that map to different `BOT_VIEW_RANGE` and `BOT_FIRE_INTERVAL`

For each feature: test locally with two windows first → if it works, `./deploy.sh` to ship it.

---

## 🆘 Really stuck?

Screenshot the error and send it to Dad with what you clicked and what went wrong.

Game development is just a long sequence of bumping into problems and solving them. **Nobody gets it right the first try — keep at it and it gets easier.**

Have fun! 🎯

---

# 📖 Appendix: How this game was actually built

> This section is Dad's running conversation with an AI assistant (Claude) while building the project — a kind of retrospective. Reading it tells you why each design decision was made, so you can do something similar from scratch later.

## A1. What we wanted to build

Dad asked the AI: **"My 12-year-old knows Python and Scratch and loves competitive games. What's a good next step?"**

We considered several options:

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **UE5 / Unreal Editor for Fortnite** | AAA visuals, same tools as Fortnite | Brutal learning curve, heavy hardware, Verse syntax not kid-friendly | Postpone |
| **Stick with Pygame** | Already knows it | 2D only, no easy networking | Already mastered, want next level |
| **Godot 4 (3D)** | Open source, lightweight, GDScript syntax like Python, great docs | Visuals a notch below UE5 | ✅ **This one** |
| **HTML5 / Three.js** | Runs directly in browsers | JavaScript more complex than GDScript | Too low-level |

**Final pick: Godot 4 + 3D + first-person shooter + multiplayer.**

## A2. Project version history

```
v1   → Single-player FPS (vs AI mobs) — establish the fundamentals
v4   → Originally split-screen; skipped (two gamepads on one device is awkward)
v5   → Multiplayer PvP — core feature shipped
v6   → Animations + SFX + kill feed + leaderboard
v6.1 → Bug fixes + shooting feel polish + random default identity
```

Every version was a **playable product**, not a half-finished thing. That's the rule: **keep the game running at every step, then add the next thing**.

## A3. Key technical decisions (and why)

### Decision 1: WebSocket instead of ENet for networking

- **ENet** is Godot's default — UDP, fast, but **browsers can't use it**
- **WebSocket** is a tiny bit slower (milliseconds), but **the same code works in browser and native**

> Trade-off: friends on phones / random PCs can play > absolute lowest latency. **Get something playable first, optimize later.**

### Decision 2: Server-authoritative architecture

Every shot, every HP change, every kill — **the server decides**, the client just displays.

```
Player A clicks shoot
  ↓ Client plays SFX + tracer locally (feels instant)
  ↓ Also RPCs the server: "I hit B"
  ↓ Server validates → deducts B's HP → broadcasts to everyone
  ↓ Everyone sees B's HP bar drop
```

Why? If clients could directly damage other clients, **cheating is trivial** — edit one line and one-shot everyone.

### Decision 3: Use Kenney CC0 models, don't model from scratch

- **Kenney.nl** has 18 free blocky characters with 27 baked animations (idle / walk / sprint / die / shoot)
- All under CC0 (**fully free, commercial OK, no attribution required**)
- Modeling + rigging + animating in Blender by hand would take 2 weeks

> Design principle: **don't reinvent the wheel. Use existing assets and spend your time on gameplay.**

### Decision 4: Start with Mac + Cloudflare Tunnel, end up on a VPS

- Cloud servers (Fly.io, AWS) want a credit card and cost monthly
- **Cloudflare Tunnel** is free, no credit card, gives you a public address
- Initial flow: friend's browser → `wss://game.boobank.com` → Cloudflare → your Mac's port 7777

Cost: **the Mac being off = no game**. Acceptable for early days, but eventually we moved to a real VPS for 24/7 uptime. See [SERVER_GUIDE.md](SERVER_GUIDE.md).

### Decision 5: Host the web build on GitHub Pages (initially)

- GitHub gives every user a free URL: `https://<user>.github.io/<repo>/`
- About a minute after `git push`, it's live
- $0, zero config, stable enough

Later we moved web hosting onto the same VPS so we control caching / cache-busting precisely.

## A4. Bugs we hit along the way (you'll likely meet these too)

### Bug 1: Godot says `Identifier not found: NetworkManager`

**Cause**: `NetworkManager` is an autoload (global singleton); you have to **register it in Project → Project Settings → Autoload** before other scripts can see it.

**Lesson**: autoloads must be registered first, used second.

### Bug 2: In multiplayer, player A can see B but can't kill them

**Cause**: server-authoritative architecture — client A calls `respawn_player.rpc_id(B)`, but the RPC mode `call_remote` **disallows targeting yourself**. When A == server (host), `rpc_id(self)` errors.

**Fix**: change `call_remote` to `call_local` so the local machine also runs the handler.

**Lesson**: **always be clear about "which machine does this RPC run on"**:
- `call_local` = also run on the sender
- `call_remote` = only on others
- `authority` = only the node's authority can call this
- `any_peer` = anyone can call this

### Bug 3: Chinese characters show as squares (口口口口) in the browser

**Cause**: Godot's Web export **doesn't bundle CJK fonts** (they're huge and would balloon the wasm).

**Fix**: convert all menu text to English. Keep CJK for user-typed names + the README.

**Lesson**: **the web build needs different font hygiene** — use English when you can.

### Bug 4: Browser host errors with `Host failed: 22`

**Cause**: browsers **can't bind a server socket** (security restriction), so the web build can't be a host.

**Fix**: in the web build, disable the Host button and rename it. (Later in v6.13 we made it fall back to `OfflineMultiplayerPeer` for single-player bot mode.)

**Lesson**: **understand your platform's limits** — know what browsers can and can't do.

### Bug 5: Browser keeps 404'ing `server.json`

**Cause**: when `HTTPRequest` uses a relative path `"server.json"`, **browsers resolve it relative to the page origin**, not the sub-path `/arena-shooter-3d/`.

**Fix**: use `JavaScriptBridge.eval(...)` to read `location.pathname` and build the absolute URL.

**Lesson**: **relative paths under a sub-path need extra care**. Godot client code looks like it's "loading a local file", but it's actually an HTTP fetch.

### Bug 6: Dedicated server fails to start: `port already in use`

**Cause**: previous Godot process didn't exit cleanly; port 7777 still held.

**Fix**: prepend `run_server.sh` with auto-cleanup:
```bash
existing_pids=$(lsof -nP -tiTCP:7777 -sTCP:LISTEN)
if [ -n "$existing_pids" ]; then kill $existing_pids; sleep 1; fi
```

**Lesson**: **scripts should handle "last run didn't clean up"**.

### Bug 7: Bullets stop hitting after switching to Kenney characters

**Cause**: Kenney's GLB model has its **own StaticBody3D colliders on each limb** (hand / foot / head). The ray hits one of these child nodes; the parent `CharacterBody3D` test fails.

**Fix**: after the ray hits, **walk up the parent chain** until you find a player root:
```gdscript
func _find_player_root(node: Node) -> CharacterBody3D:
    var n: Node = node
    while n:
        if n is CharacterBody3D and n.is_in_group("player"):
            return n
        n = n.get_parent()
    return null
```

**Lesson**: **inspect the scene tree of any imported third-party model** to see what hidden children it brought along.

### Bug 8: Animations not playing

**Cause**: Kenney GLBs ship with an `AnimationPlayer`, but the default animations **don't loop** (idle / walk play once and stop).

**Fix**: after import, iterate the animations and set looping mode for movement anims:
```gdscript
for n in _anim_player.get_animation_list():
    if n in ["idle", "walk", "sprint"]:
        _anim_player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
```

**Lesson**: **animation system gotchas (loop mode, transitions, blending) are invisible footguns**.

### Bug 9: Muzzle flash looks ugly (a single ugly flashing cube)

**Cause**: initial implementation used a BoxMesh scaled 2.5× → looked like **a yellow cube popping out of the gun**.

**Fix**: SphereMesh + material emission fade + unshaded shading. Combined with a tracer (a thin line from muzzle to impact).

**Lesson**: **better visual feedback isn't about more brightness, it's about natural movement**. Easing > hard cuts.

## A5. Building your own game like this

If you want to build something similar from scratch, here's a suggested order:

### Stage 1: Make it playable solo (1–2 weeks)

1. Learn Godot 4 basics: nodes / scenes / scripts (run through the "Your First Game" tutorial)
2. Build a 3D scene: ground + a few crates + a first-person player (CharacterBody3D + Camera3D + RayCast3D)
3. Implement: movement, jump, mouse look, left-click shoots a ray
4. Add HP, ammo, UI labels

> **This is the most important step**: get solo working *first*, then think about networking. **Never plan multiplayer before single-player works.**

### Stage 2: Add multiplayer (1 week)

1. Register the `NetworkManager` autoload
2. Use `WebSocketMultiplayerPeer` for server + client
3. Sync the player roster via `multiplayer.peer_connected`
4. The big one: **position sync, shoot sync, HP sync** all go through RPCs
5. Test with two windows (Debug → Run Multiple Instances → 2)

### Stage 3: Deploy on the web (half a day)

1. Project Settings → Web export, path `docs/index.html`
2. Create a GitHub repo, push `docs/`
3. Enable GitHub Pages in repo settings, point at `main` branch's `docs/` folder
4. The link looks like `https://<user>.github.io/<repo>/`

### Stage 4: Art + audio (1 week)

1. Browse [kenney.nl](https://kenney.nl) for CC0 assets
2. Characters: blocky-characters
3. SFX: sci-fi-sounds or impact-sounds
4. Preload everything with `preload()` — best performance

### Stage 5: Polish (open-ended)

- Kill feed
- Leaderboard
- Persistence (ConfigFile or JSON)
- Touch controls (mobile support)

## A6. A note from Dad

The biggest lessons from building this:

1. **Make it work, then make it good**. Every version should be playable, then you add one more thing.
2. **Read the logs first**. 99% of the time the Godot console's red text tells you exactly what's wrong — don't skim past it.
3. **Copying code isn't shameful**. GitHub, the Godot forum, official samples — copy freely.
4. **Print-debug a lot**. Sprinkle `print()` to see "where does the program get to before it breaks".
5. **`git commit` after every working chunk**. When something breaks, `git diff` shows what you changed; `git checkout` rewinds.

Game bugs are a kind of maze. Every one you solve makes you a notch sharper. **Finishing one full game (even a simple one) teaches you more than 100 tutorials.**

Good luck — looking forward to seeing what you build next 🚀

---

<a id="arena-shooter-3d--操作手册中文"></a>

# Arena Shooter 3D — 操作手册（中文）

> 给小作者：这是你和朋友一起玩、一起改的多人射击游戏。这份文档把所有要做的事都列清楚了，按顺序看就行。

---

## 🎮 第 1 部分：怎么玩

### 控制键

| 设备 | 移动 | 视角 | 跳跃 | 射击 | 换弹 | 切武器 |
|---|---|---|---|---|---|---|
| 电脑 | W / A / S / D | 鼠标 | 空格 | 鼠标左键 | R | **数字键 1 / 2 / 3** |
| 手机 | 左下虚拟摇杆 | 右半屏滑动 | JUMP 按钮 | FIRE 按钮 | RELOAD 按钮 | PIS / SMG / SHG 三个小键 |

### 主菜单两个绿/紫按钮

- **▶ PLAY**（绿色）—— 上线对战，连远程服务器跟朋友打
- **🤖 PLAY vs BOTS**（紫色）—— 选 1 / 2 / 3 个 bot 单机练习
  - 网页版：纯本地，不联网也能玩
  - 桌面版：本机当 LAN host，朋友也能加进来

### 游戏规则

- **赢的条件**：第一个杀到 **10 个** 人/bot 的赢
- **死了会怎样**：黑屏 → **等 2.5 秒** → 传送到离敌人最远的出生点 → 无敌 1.5 秒（小人闪烁）
- **每局结束后**：屏幕中央倒计时 5 秒 → 自动开下一局，分数清零

### 三把武器（数字键 1 / 2 / 3 切换）

| 键 | 武器 | 伤害（普通 / 爆头） | 弹夹 | 射速 | 适合 |
|---|---|---|---|---|---|
| 1 | 🔫 **手枪** | 50 / 100 | 12 | 慢 | 远距离精准、爆头一枪秒 |
| 2 | 💨 **SMG**（默认） | 25 / 50 | 30 | 快 | 中距离扫射 |
| 3 | 💥 **霰弹** | 18 / 36 × 5 颗弹丸 | 8 | 极慢 | 贴身一发 90 伤 |

> 💡 **爆头判定**：准心瞄到敌人**头部**时打中，伤害 ×2，屏幕中央会冒红字 "HEAD! -50"。

### 地图道具（**找它们！**）

- 🚀 **跳板**（青蓝色发光圆盘 ×3）—— 踩上去弹起 5 米，能从地面直接跳到桥上
- ❤️ **血包**（白色发光盒 + 红十字 ×2）—— 走过去回血 +50（桥面正中一个、西南角一个）
- 🔫 **弹药箱**（金色发光木箱 ×2）—— 走过去满弹（隧道里一个、东北角一个）
- 道具被拿走后**消失 30 秒**，然后自动复活

### 连击播报 🔥

不死的情况下连续杀人，屏幕中央会闪：

| 连杀 | 显示 | 颜色 |
|---|---|---|
| 2 | 🔥 DOUBLE KILL | 黄 |
| 3 | 🔥 TRIPLE KILL | 橙 |
| 5 | 🔥 RAMPAGE | 红 |
| 7 | 🔥 GODLIKE | 紫 |

死一次清零，继续刷。

### 排行榜

- **游戏中右上角**：本局当前所有玩家的 K / D
- **菜单右栏**：历史总排名（按胜场排序，永久存档）

> 第一次启动会自动给你一个英文随机名字 + 随机角色。改过之后下次会记住。

---

## 🚀 第 2 部分：让朋友也能玩

**好消息：服务器在 VPS 上 24 小时在线，你和爸爸什么都不用做**。直接把链接发给朋友：

```
https://game.boobank.com/arena-shooter/
```

朋友打开 → 选角色 → 点 **PLAY** → 自动连接！

### 想单人玩 vs Bot（不联网）

直接打开同一个链接，点紫色的 **PLAY vs BOTS**，选 1/2/3 个 bot，开打。这个不需要服务器，朋友的 wifi 不好也能玩。

### 服务器维护命令（爸爸偶尔用）

如果朋友说"连不上"，让爸爸 SSH 上 VPS 看：

```bash
ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'
# 三个都应该是 active

ssh root@207.148.98.206 'journalctl -u arena-game -n 30 --no-pager'
# 看最近的游戏服务器日志
```

详细运维命令在 [`OPERATIONS.md`](OPERATIONS.md)。

---

## ✏️ 第 3 部分：改游戏（小修改）

### 在 Godot 里打开项目

1. 打开 Godot 4.6.2
2. 点 **Import** → 选 `/Users/longmao/projects/arena-shooter-3d/project.godot`
3. 进入编辑器

### 改完之后本地测试

- 顶部菜单 **调试 → 运行多个实例 → 2**（这样能开两个窗口模拟两个玩家）
- 按 **⌘ + B** 启动两个窗口
- 窗口 1：选角色 → 点 **🤖 PLAY vs BOTS**（变本机 host）
- 窗口 2：直接点 **▶ PLAY**（IP 框已自动填 `ws://127.0.0.1:7777`）

### 常见的小修改清单

| 想改什么 | 打开哪个文件 | 改哪一行 |
|---|---|---|
| **跑步速度** | `scripts/player.gd` | `const SPEED := 6.0` |
| **冲刺速度** | `scripts/player.gd` | `const SPRINT_SPEED := 10.0` |
| **跳跃高度** | `scripts/player.gd` | `const JUMP_VELOCITY := 8.5` |
| **跳板弹起多高** | `scripts/jump_pad.gd` | `const JUMP_BOOST := 16.0` |
| **满血量** | `scripts/game.gd` | `const SERVER_MAX_HEALTH := 100` |
| **三把武器属性**（伤害 / 弹夹 / 射速 / 散布） | `scripts/player.gd` | `const WEAPONS := [...]` |
| **服务器伤害表**（爆头 / 普通） | `scripts/game.gd` | `const SERVER_WEAPON_DAMAGE := [...]` |
| **死后等多久复活** | `scripts/game.gd` | `const SERVER_RESPAWN_DELAY := 2.5` |
| **复活无敌时长** | `scripts/game.gd` | `const SERVER_RESPAWN_INVINCIBILITY := 1.5` |
| **多少杀算赢** | `scripts/game.gd` | `const KILLS_TO_WIN := 10` |
| **新一局等多久** | `scripts/game.gd` | `const NEW_GAME_DELAY := 5.0` |
| **Bot 视野距离 / 开火间隔** | `scripts/player.gd` | `const BOT_VIEW_RANGE := 22.0` 等 |
| **连击播报阈值** | `scripts/game.gd` 的 `_handle_kill` | `if streak == 2 or 3 or 5 or 7:` |
| **血包加多少血** | `scripts/pickup.gd` | `@export var heal_amount: int = 50` |
| **道具复活时间** | `scripts/pickup.gd` | `@export var respawn_time: float = 30.0` |
| **最多几个玩家** | `scripts/network_manager.gd` | `const MAX_PLAYERS := 8` |
| **默认随机名字列表** | `scripts/network_manager.gd` | `const COMMON_NAMES := [...]` |

### 改地图

- 在 Godot 编辑器里打开 `scenes/game.tscn`
- 场景树里找 `Game` 下面的 CSGBox3D 们（Floor、Wall_、Cover_、Tower_、Bridge_、Stair_、Tunnel_、Platform_）—— 拖位置和 `size` 改墙、桥、阶梯
- `Pickups` 节点下面是 8 个道具（HP_/ AM_/ JumpPad_）—— 拖位置改它们出现的地方
- `SpawnPoints` 节点下面是 6 个 Marker3D —— 拖它们改玩家出生位置

### 加 / 删 bot 默认数

主菜单的 1 / 2 / 3 按钮就是选数量。如果想让默认是 3 不是 2：

- `scenes/main_menu.tscn` 找 `Bot2` 节点 → 把 `button_pressed = true` 拷给 `Bot3`，从 `Bot2` 删掉

---

## 🌐 第 4 部分：改完了让朋友看到新版本

代码改了之后，**网页版不会自动更新**。要做这三步：

### 步骤 ① 在 Godot 里导出

1. 顶部菜单 **项目 → 导出**
2. 选 **Web (Runnable)** → 点 **导出项目**
3. 路径不用改（默认就是 `docs/index.html`）→ 保存
4. 等几秒钟导出完成

### 步骤 ② 清理 Godot 编辑器残留文件

在终端里：

```bash
cd /Users/longmao/projects/arena-shooter-3d
find docs -name "*.import" -delete
```

### 步骤 ③ 推送

```bash
./deploy.sh
```

或者手动：

```bash
git add -A
git commit -m "更新游戏：你做了什么改动写在这里"
git push
```

> 推完大概等几秒，让朋友 ⌘+Shift+R 硬刷新一下浏览器就能看到新版本。

---

## 🐛 第 5 部分：常见问题

### Q1：朋友打开网页，点 PLAY 没反应 / "Connection failed"
- 服务器在 VPS 上 24 小时跑，朋友能不能进取决于 VPS 服务有没有挂
- 让爸爸 SSH 上去看：`ssh root@207.148.98.206 'systemctl is-active arena-game caddy cloudflared'`
- 三个都应该是 `active`。哪个不是就重启它：`ssh root@207.148.98.206 'systemctl restart arena-game'`
- 同时朋友可以**先点紫色 PLAY vs BOTS 单机玩**，等服务器修好再上线

### Q2：自己开两个窗口测试，第二个 PLAY 报错
- 第一个窗口必须先点 **🤖 PLAY vs BOTS**（变成本机 host）
- 第二个窗口的 IP 框已经自动填了 `ws://127.0.0.1:7777`，**直接点 PLAY 就行**
- 如果 IP 框被你改过了，把它改回 `ws://127.0.0.1:7777`

### Q3：浏览器里中文显示成方块
- Godot Web 导出不带中文字体，所以菜单里全用英文
- 改菜单文字时记得只用英文 / 数字 / 符号 / emoji

### Q4：编辑器里报一堆 "Node not found: Game/Players/N"
- 这是窗口 2 的 game 场景没加载完时窗口 1 已经在广播位置 → 已经在 v6.17 修了：每个 player 头 1.5 秒不广播
- 还看到几条？正常，第一帧的少量错误不影响游戏

### Q5：子弹打不中人
- v6.6 修过：Kenney 角色每个肢体（手/脚/头）都有自己的碰撞体，子弹要沿父节点找到主角色才算命中
- 修复在 `scripts/player.gd` 的 `_find_player_root()` 函数
- 现在还有**爆头判定**：打到 Y > 1.4m 区域就 ×2 伤害

### Q6：Bot 太厉害打不过 / 太傻没挑战
- 视野太大让你被远距离秒：改 `player.gd::BOT_VIEW_RANGE`（默认 22m，调成 12m 就成"近视眼"）
- 开火太快：`BOT_FIRE_INTERVAL` 默认 0.7 秒，调到 1.5 让他慢点
- 永远缠着你：`BOT_LOSE_RANGE` 默认 30m，调小让他更容易"放弃追"

### Q7：在 Godot 里改了文件，但游戏里没生效
- 文件保存了吗？（标题栏有 `*` 表示没存）
- 试试 **项目 → 重新加载当前项目**
- 如果还不行，关掉 Godot 重新打开

### Q8：手机上键盘弹不出来
- 已经修过：项目设置里开了 `virtual_keyboard_enabled`
- 名字输入框点击之后应该会弹

### Q9：朋友在网页版看到的是旧版本
- 浏览器缓存了老 pck。让他**硬刷新**：⌘+Shift+R（Mac）或 Ctrl+Shift+R（Win）
- 或者关闭整个标签页重开

---

## 📁 第 6 部分：项目里有什么文件

```
arena-shooter-3d/
├── project.godot              ← 用 Godot 打开这个文件
├── README.md                  ← 给开发者看的总文档
├── KIDS_GUIDE.md              ← 你正在看的这份
├── OPERATIONS.md              ← VPS 运维命令速查（爸爸看）
├── SERVER_GUIDE.md            ← VPS 架构 + 一次性搭建步骤
├── deploy.sh                  ← 部署：git push + ssh 服务器 git pull + import + 重启
├── run_server.sh              ← 本地起 dedicated server（开发用，VPS 上 systemd 用同一份）
│
├── scripts/                   ← 所有 GDScript 代码
│   ├── player.gd              玩家移动 / 射击 / 武器 / Bot AI / 动画
│   ├── game.gd                游戏规则 / 计分 / 死亡 / 复活 / 服务器伤害表
│   ├── network_manager.gd     联网状态 / 玩家信息 / 设置
│   ├── hud.gd                 HP 卡 / 弹药 / 计分板 / 击杀提示 / 连击横幅
│   ├── main_menu.gd           主菜单逻辑（PLAY / PLAY vs BOTS / Bot 数 / 名字）
│   ├── pickup.gd              ❤️ 血包 + 🔫 弹药箱（视觉 + 拾取逻辑）
│   ├── jump_pad.gd            🚀 跳板（弹起 + 视觉脉冲）
│   ├── stats_store.gd         排行榜持久化（JSON 存档）
│   ├── touch_controls.gd      手机虚拟摇杆 + 按钮 + 武器键
│   └── input_setup.gd         键盘 / 鼠标按键映射
│
├── scenes/                    ← 场景（用 Godot 打开）
│   ├── main_menu.tscn         主菜单 + 排行榜
│   ├── game.tscn              竞技场（地图 + Pickups + SpawnPoints）
│   ├── player.tscn            玩家（CharacterBody3D + Camera + Audio）
│   ├── hud.tscn               游戏内 HUD
│   └── touch_controls.tscn    手机控制层
│
├── models/characters/         ← 18 个 Kenney 方块小人 GLB
├── audio/                     ← 射击 / 命中 / 死亡 / 复活
├── fonts/                     ← Russo One（菜单字体）
├── themes/                    ← arena_theme.tres（统一字体应用）
└── docs/                      ← Web 版导出产物（VPS 上 Caddy 直接服务这里）
```

---

## 🌟 进阶玩法（想挑战）

很多基础功能已经做完了。下面是真正可以挑战的：

1. **武器后坐力**：开枪时让 `camera.rotation.x` 临时上抬 0.02 rad，慢慢回正 → 现实感
2. **多张地图轮换**：复制 `scenes/game.tscn` 改成 `arena2.tscn`，每场比赛随机选一张
3. **队伍模式**：进游戏前选红 / 蓝队，友军免伤，谁先到 20 杀
4. **房间码加入**：让朋友输入 4 位数字房间号才能加入指定房间
5. **第一名头顶飘 👑**：把当前榜首的 Label3D 加个皇冠 emoji 字符
6. **武器拾取**：把武器变成地图上的物品（像 Quake），死后丢失现有武器
7. **Bot 难度设置**：菜单加 Easy / Normal / Hard，对应 BOT_VIEW_RANGE 和 BOT_FIRE_INTERVAL

每加一个功能，先在本地多窗口测试 → 没问题再 `./deploy.sh` 上线。

---

## 🆘 实在搞不定？

把出错的截图发给爸爸，告诉他你点了什么、出了什么错。

游戏开发就是不停遇到问题、解决问题的过程，**第一次都做不对，多试几次就熟了**。

Have fun! 🎯

---

# 📖 附录：这个游戏是怎么做出来的（中文）

> 这部分是爸爸和 AI 助手（Claude）一路对话做出来的"项目复盘"。看完你就能明白每个决定为什么这么选，以后想自己做类似的游戏，可以照着这个思路走。

## A1. 一开始想做什么

爸爸问 AI：**"我儿子 12 岁，对 Python 和 Scratch 都熟了，还很会玩对战类游戏，想找个进阶方向。"**

讨论过几个选项：

| 选项 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| **UE5 / Unreal Editor for Fortnite** | 商业级画质、Fortnite 同款工具 | 学习曲线极陡、对电脑配置要求高、Verse 语法对小学生不友好 | 暂缓 |
| **继续 Pygame** | 已经会了 | 2D 局限、不联网难做对战 | 已会，要进阶 |
| **Godot 4 (3D)** | 开源免费、轻量、GDScript 语法像 Python、官方文档全 | 比起 UE5 画质弱一些 | ✅ **选这个** |
| **HTML5 / Three.js** | 浏览器里直接玩 | JavaScript 比 GDScript 复杂 | 太底层 |

**最终决定：Godot 4 + 3D + 第一人称射击 + 多人对战**。

## A2. 整个项目分了几个版本

```
v1  → 单机 FPS（自己 vs AI 怪），先跑通基础
v4  → 本想做分屏，跳过（单设备双手柄太奇怪）
v5  → 联机 PvP（核心功能上线）
v6  → 加动画 + 音效 + 击杀提示 + 排行榜
v6.1→ 修 bug + 优化射击手感 + 随机默认身份
```

每个版本都是**可玩的成品**，不是半成品。这是关键原则：**永远保持游戏能跑，再加新东西**。

## A3. 关键技术决定（为什么这么选）

### 决定 1：用 WebSocket 而不是 ENet 做联网

- **ENet** 是 Godot 默认的联网协议，UDP 快，但浏览器**不能用**
- **WebSocket** 慢一点点（毫秒级），但**网页版和原生版同一套代码**就能跑

> 取舍：手机网页 / 朋友家电脑都能玩 > 极致延迟。**先能玩到，再想优化**。

### 决定 2：服务器权威架构（Server-Authoritative）

每次开枪、扣血、计分，都要让**服务器**说了算，客户端只是显示。

```
玩家A按下鼠标
  ↓ 客户端先播音效 + 弹道（看起来很流畅）
  ↓ 同时 RPC 给服务器："我打中了 B"
  ↓ 服务器验证 → 给 B 扣血 → 广播给所有人
  ↓ 大家看到 B 的血条变化
```

为什么这么做？因为如果让客户端直接扣别人血，**作弊就太容易了**——改个本地代码就一枪秒杀。

### 决定 3：用 Kenney CC0 模型，不自己建模

- **Kenney.nl** 上有 18 个免费方块小人，自带 27 个动画（待机/走路/冲刺/死亡/射击）
- 全部 CC0 协议（**完全免费，可以商用，不用署名**）
- 自己用 Blender 建模 + 绑骨 + 做动画大概要 2 周

> 设计原则：**别造轮子。能用现成的就用现成的，把时间花在游戏玩法上。**

### 决定 4：先 Mac + Cloudflare Tunnel，后来上 VPS

- 云服务器（Fly.io、AWS）要绑信用卡，且每月有钱
- **Cloudflare Tunnel** 免费、不要信用卡、给你一个公网地址
- 初期流程：朋友的浏览器 → `wss://game.boobank.com` → Cloudflare → 你 Mac 的 7777 端口

代价：**Mac 不开机就停服**。早期能接受，后来移到真 VPS 实现 24h 在线。详见 [SERVER_GUIDE.md](SERVER_GUIDE.md)。

### 决定 5：早期网页版托管 GitHub Pages

- GitHub 给每个用户一个免费网址：`https://用户名.github.io/项目名/`
- 每次 `git push` 之后大概 1 分钟自动上线
- 0 元、0 配置、足够稳

后来 Web 托管也搬到同一个 VPS，缓存控制（cache-busting）更精确。

## A4. 一路踩过的坑（你以后可能也会遇到）

### 坑 1：写好代码 Godot 报红 `Identifier not found: NetworkManager`

**原因**：`NetworkManager` 是个 autoload（全局单例），需要在 **项目 → 项目设置 → Autoload** 里注册才能让别的脚本看到。

**教训**：autoload 名字必须先注册，再用。

### 坑 2：联机时玩家 A 能看到 B，但开枪打不死

**原因**：服务器权威架构里，客户端 A 调用 `respawn_player.rpc_id(B)`，但 RPC 的 `call_remote` **不允许打给自己**。当 A == 服务器（Host）时，对自己 rpc_id 会报错。

**修法**：把 `call_remote` 改成 `call_local`，让本机也执行同样的逻辑。

**教训**：**RPC 的语义"在哪个机器上跑"要想清楚**：
- `call_local` = 本机也跑
- `call_remote` = 只在别人那跑
- `authority` = 只服务器能发起
- `any_peer` = 谁都能发

### 坑 3：浏览器里中文显示成方块（口口口口）

**原因**：Godot Web 导出**不会自带中文字体**（CJK 字体太大，会让 wasm 文件爆炸）。

**修法**：菜单文字全改成英文。中文文字塞在玩家名字（用户输入）和 README 文档里。

**教训**：**网页版要照顾字体大小**，能用英文就用英文。

### 坑 4：浏览器 Host 报错 `Host failed: 22`

**原因**：浏览器**不能监听 socket**（安全限制），所以网页版不能当服务器。

**修法**：网页版的 Host 按钮**直接禁用**，按钮文字改成 "Host (desktop only)"。（v6.13 后改成 `OfflineMultiplayerPeer` 兜底单机 vs Bot 模式）

**教训**：**先搞清楚目标平台的能力边界**——浏览器能做什么、不能做什么。

### 坑 5：朋友的浏览器一直 404 `server.json`

**原因**：HTTPRequest 用相对路径 `"server.json"` 时，**浏览器会从域名根解析**，而不是从子路径 `/arena-shooter-3d/`。

**修法**：用 `JavaScriptBridge.eval(...)` 直接读 `location.pathname` 拼绝对地址。

**教训**：**子路径下的网页要小心相对路径**。Godot 客户端代码看起来"是在加载本地文件"，但其实是浏览器代发的 HTTP 请求。

### 坑 6：服务器开不起来，提示 `port already in use`

**原因**：上次 Godot 进程没退干净，端口 7777 还被占着。

**修法**：在 `run_server.sh` 顶部加自动清理：
```bash
existing_pids=$(lsof -nP -tiTCP:7777 -sTCP:LISTEN)
if [ -n "$existing_pids" ]; then kill $existing_pids; sleep 1; fi
```

**教训**：**写脚本时考虑前一次没退干净的情况**。

### 坑 7：换上 Kenney 角色后，子弹打不中人了

**原因**：Kenney 的 GLB 模型每个肢体（手/脚/头）**都自带 StaticBody3D 碰撞体**。射线先撞到这些子节点，根节点的 `CharacterBody3D` 反而判定失败。

**修法**：射线击中后**沿父节点向上找**，直到找到 player 根：
```gdscript
func _find_player_root(node: Node) -> CharacterBody3D:
    var n: Node = node
    while n:
        if n is CharacterBody3D and n.is_in_group("player"):
            return n
        n = n.get_parent()
    return null
```

**教训**：**第三方模型导入后要先看一眼场景树**，看它带了哪些隐藏的子节点。

### 坑 8：动画没生效

**原因**：Kenney GLB 自带 `AnimationPlayer`，但默认动画**不循环**（idle/walk 都只播一次就停了）。

**修法**：导入后遍历动画，把循环类的设成 `LOOP_LINEAR`：
```gdscript
for n in _anim_player.get_animation_list():
    if n in ["idle", "walk", "sprint"]:
        _anim_player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
```

**教训**：**动画系统的细节（循环模式、过渡、混合）经常是"看不见的坑"**。

### 坑 9：枪口火光太丑（一闪而过的方块）

**原因**：最早用 BoxMesh 做枪口火光，scale 2.5x → 看起来像个**会跳出来的黄色方块**。

**修法**：换成 SphereMesh + 材质 emission 渐隐 + unshaded shading。再配合弹道轨迹（tracer，从枪口画到命中点的细线）。

**教训**：**视觉反馈不是越亮越好，是要"自然"**。渐变 > 硬切。

## A5. 怎么自己做一个类似的游戏

如果你想从零做一个差不多的，建议这个顺序：

### 阶段 1：先让自己一个人能玩（1-2 周）

1. 学 Godot 4 基础：节点 / 场景 / 脚本（官方教程 "Your First Game" 走一遍）
2. 做一个 3D 场景：地面、几个箱子、一个第一人称玩家（CharacterBody3D + Camera3D + RayCast3D）
3. 实现：移动、跳跃、鼠标看视角、按左键发射射线
4. 加血量、弹药、UI 标签

> 这一步**最重要**：单机能玩了，再考虑联机。**永远不要还没单机就想着联机**。

### 阶段 2：加联机（1 周）

1. 注册 `NetworkManager` autoload
2. 用 `WebSocketMultiplayerPeer` 做服务器和客户端
3. 玩家信息用 `multiplayer.peer_connected` 信号同步
4. 关键：**位置同步、射击同步、血量同步**都要走 RPC
5. 本地两个窗口（调试 → 运行多个实例 → 2）测试

### 阶段 3：部署到网页（半天）

1. 项目设置 → Web 导出，路径 `docs/index.html`
2. 在 GitHub 创建项目，把 `docs/` 推上去
3. 仓库设置里启用 GitHub Pages，源选 `main` 分支的 `docs` 文件夹
4. 链接长这样：`https://用户名.github.io/项目名/`

### 阶段 4：加美术 + 音效（1 周）

1. 去 [kenney.nl](https://kenney.nl) 找 CC0 资源
2. 角色模型：blocky-characters
3. 音效：sci-fi-sounds 或 impact-sounds
4. 全部用 `preload()` 加载，性能最好

### 阶段 5：加润色（继续做）

- 击杀提示
- 排行榜
- 持久化（用 ConfigFile 或 JSON 存数据）
- 触屏适配（手机也能玩）

## A6. 给小作者的话

做游戏最大的感受：

1. **先跑通，再优化**。让游戏每个版本都"能玩"，再一点点加东西。
2. **遇到问题先看日志**。Godot 控制台的红字 99% 都告诉你了答案，别绕过去。
3. **抄别人的代码不丢人**。GitHub、Godot 论坛、官方示例项目随便抄。
4. **多用 print 调试**。"程序在哪一步出问题"打印几行就知道。
5. **每次写完一段就 git commit**。出错了 `git diff` 能看出你改了啥，搞砸了 `git checkout` 能回退。

游戏里的 bug 就是迷宫，每解一个你的能力都上一个台阶。**坚持做完一个完整的游戏（哪怕很简单），收获比看 100 个教程都大**。

加油，期待你做出更酷的东西 🚀
