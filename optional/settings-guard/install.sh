#!/usr/bin/env bash
# settings-guard 安装：拷脚本 + 生成 launchd plist + load
set -euo pipefail

DEST="${XDG_CONFIG_HOME:-$HOME/.config}/agent-bark-notify/settings-guard"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.user.claude-settings-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SETTINGS_JSON="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "✗ 需要 jq：brew install jq"; exit 1; }

echo "→ 安装到：$DEST"
mkdir -p "$DEST"
cp "$HERE/guard.sh" "$DEST/"
[ -f "$DEST/guard.conf" ] || cp "$HERE/guard.conf.example" "$DEST/guard.conf"
chmod +x "$DEST/guard.sh"

echo "→ 生成 launchd plist：$PLIST"
mkdir -p "$(dirname "$PLIST")"
sed -e "s|__LABEL__|$LABEL|g" \
    -e "s|__GUARD_SH__|$DEST/guard.sh|g" \
    -e "s|__SETTINGS_JSON__|$SETTINGS_JSON|g" \
    "$HERE/com.user.claude-settings-guard.plist.template" > "$PLIST"

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
launchctl start "$LABEL" 2>/dev/null || true

echo
echo "✅ 守卫已加载：$LABEL"
echo "   ⚠️  先编辑你的规则：$DEST/guard.conf"
echo "      改完跑 launchctl start $LABEL 让它立刻执行一次"
echo "   日志：/tmp/agent-bark-notify-guard.log"
echo
echo "卸载：launchctl unload $PLIST && rm $PLIST && rm -rf $DEST"
