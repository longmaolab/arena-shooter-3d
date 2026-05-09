#!/usr/bin/env bash
# 一键部署:导出 docs/ → 提交 → 推送 → 服务器 pull
# 用法:./deploy.sh
# 前提:先在 Godot 里 "项目 → 导出 → Web → 导出项目" 生成 docs/

set -e

cd "$(dirname "$0")"

# ---- 配置(改服务器时改这里) ----
SERVER_HOST="${ARENA_SERVER_HOST:-root@207.148.98.206}"
SERVER_PATH="${ARENA_SERVER_PATH:-/opt/games/arena-shooter-3d}"
PUBLIC_URL="https://game.boobank.com/arena-shooter/"

# ---- 1. 检查 docs/ 已导出 ----
if [ ! -f docs/index.html ]; then
  echo "❌ 找不到 docs/index.html"
  echo "👉 请先在 Godot 里:项目 → 导出 → Web → 导出项目"
  exit 1
fi

echo "✓ docs/ 已生成"
ls -lh docs/ | awk '{print "    " $9 "  " $5}'
echo ""

# ---- 2. git 提交 ----
if [ ! -d .git ]; then
  echo "⚠️  这个项目还没用 git 初始化。"
  exit 1
fi

git add docs/ export_presets.cfg .gitignore 2>/dev/null || true
if git diff --cached --quiet; then
  echo "(没有新的 docs/ 改动,跳过 commit)"
else
  git commit -m "Build $(date '+%Y-%m-%d %H:%M')"
fi

# ---- 3. 推到 GitHub ----
echo ""
echo "→ 推送到 GitHub..."
git push

# ---- 4. 触发服务器 pull + 重启 game server ----
echo ""
echo "→ 通知服务器拉取并重启 ..."
ssh "$SERVER_HOST" "cd '$SERVER_PATH' && git pull --rebase && systemctl restart arena-game"

# ---- 5. done ----
echo ""
echo "✅ 部署完成,立即生效:"
echo "   $PUBLIC_URL"
