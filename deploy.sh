#!/usr/bin/env bash
# 一键部署：检查 docs/ 已导出 → 提交 → 推送
# 用法：./deploy.sh
# 前提：先在 Godot 里 "项目 → 导出 → Web → 导出项目" 生成 docs/

set -e

cd "$(dirname "$0")"

if [ ! -f docs/index.html ]; then
  echo "❌ 找不到 docs/index.html"
  echo "👉 请先在 Godot 里：项目 → 导出 → Web → 导出项目"
  exit 1
fi

echo "✓ docs/ 已生成"
ls -lh docs/ | awk '{print "    " $9 "  " $5}'
echo ""

# 确认 git 已初始化
if [ ! -d .git ]; then
  echo "⚠️  这个项目还没用 git 初始化。先跑一次："
  echo "    git init"
  echo "    git remote add origin git@github.com:longmaolab/arena-shooter-3d.git"
  exit 1
fi

git add docs/ export_presets.cfg .gitignore
git commit -m "Build $(date '+%Y-%m-%d %H:%M')" || echo "(无新改动)"

echo ""
echo "→ 推送到 GitHub..."
git push

echo ""
echo "✅ 完成！约 1 分钟后可访问："
echo "   https://longmaolab.github.io/arena-shooter-3d/"
