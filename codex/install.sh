#!/usr/bin/env bash
# Codex CLI 安装脚本 —— 把 agent-bark-notify 装到 ~/.config/agent-bark-notify/
# 并在 ~/.codex/config.toml 写入 notify 配置（幂等）
set -euo pipefail

DEST="${XDG_CONFIG_HOME:-$HOME/.config}/agent-bark-notify"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # 仓库根

# ---- 依赖检查 ----
if ! command -v python3 >/dev/null 2>&1; then
  echo "✗ 需要 python3（macOS 自带；其它系统请先装）" >&2
  exit 1
fi

echo "→ 安装到：$DEST"
mkdir -p "$DEST/scripts" "$DEST/config"

# ---- 拷脚本和文案 ----
cp "$HERE/scripts/notify.sh" "$DEST/scripts/"
cp "$HERE/scripts/lib.sh"    "$DEST/scripts/"
cp "$HERE/config/messages.default.conf" "$DEST/config/"
[ -f "$HERE/config/messages.example.conf" ] && cp "$HERE/config/messages.example.conf" "$DEST/config/"
chmod +x "$DEST/scripts/notify.sh" 2>/dev/null || true

# ---- 写 Codex config.toml 的 notify（幂等）----
NOTIFY_LINE="notify = [\"bash\", \"$DEST/scripts/notify.sh\"]"
mkdir -p "$(dirname "$CODEX_CONFIG")"
touch "$CODEX_CONFIG"
if grep -q "agent-bark-notify" "$CODEX_CONFIG" 2>/dev/null; then
  echo "→ $CODEX_CONFIG 已含 agent-bark-notify，跳过"
elif grep -qi '^notify[[:space:]]*=' "$CODEX_CONFIG"; then
  echo "⚠️  $CODEX_CONFIG 已有别的 notify 配置，请手动改成："
  echo "    $NOTIFY_LINE"
else
  printf '\n# agent-bark-notify: turn 完成时推送 Bark\n%s\n' "$NOTIFY_LINE" >> "$CODEX_CONFIG"
  echo "→ 已写入 $CODEX_CONFIG"
fi

# ---- key ----
KEY_FILE="$DEST/bark.key"
if [ ! -f "$KEY_FILE" ]; then
  echo
  echo "→ 最后一步：配置 Bark device key（打开 iPhone Bark app 复制）"
  echo "    echo '你的key' > \"$KEY_FILE\""
  echo "  或在 shell rc 里："
  echo "    export BARK_KEY='你的key'"
else
  echo "→ bark.key 已存在，跳过"
fi

echo
echo "✅ Codex 安装完成。下一次 turn 完成会推送到 iPhone/Apple Watch。"
echo "   自定义文案：cp \"$DEST/config/messages.default.conf\" \"$DEST/config/messages.conf\" 后编辑"
