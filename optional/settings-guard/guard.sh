#!/usr/bin/env bash
# agent-bark-notify settings-guard —— 通用 Claude Code settings.json 字段守卫
# launchd 用 WatchPaths 监听 settings.json，发现受保护字段被丢/被改就原子写回
# 幂等：写回会再触发监听，但下次检查变成 no-op，自稳定，不死循环
#
# 依赖：jq（brew install jq）
# 配置：见同目录 guard.conf
set -uo pipefail

SETTINGS_JSON="${SETTINGS_JSON:-$HOME/.claude/settings.json}"
GUARD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-bark-notify/settings-guard"
GUARD_CONF="${GUARD_CONF:-$GUARD_DIR/guard.conf}"
LOG_FILE="${LOG_FILE:-/tmp/agent-bark-notify-guard.log}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true; }

[ -f "$SETTINGS_JSON" ] || { log "settings.json 不存在，退出"; exit 0; }
[ -f "$GUARD_CONF" ]    || { log "guard.conf 不存在，退出"; exit 0; }
command -v jq >/dev/null 2>&1 || { log "jq 未安装，退出"; exit 0; }

# 检查并按需原子写回一条规则
apply_rule() {
  local path="$1" strategy="$2" expect="$3"
  local current restore=false
  current=$(jq -ce "$path" "$SETTINGS_JSON" 2>/dev/null || echo "null")

  if [[ "$current" == "null" || -z "$current" ]]; then
    # 字段缺失或为空
    [[ "$strategy" == "missing" || "$strategy" == "both" ]] && restore=true
  else
    # 字段存在，比对是否偏离期望
    if [[ "$strategy" == "change" || "$strategy" == "both" ]]; then
      if ! diff \
        <(printf '%s' "$expect"  | jq -ce . 2>/dev/null) \
        <(printf '%s' "$current" | jq -ce . 2>/dev/null) >/dev/null 2>&1; then
        restore=true
      fi
    fi
  fi

  if $restore; then
    local tmp
    tmp=$(mktemp)
    if jq -ce "$path = \$x" --argjson x "$expect" "$SETTINGS_JSON" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$SETTINGS_JSON"
      log "restored $path (strategy=$strategy)"
    else
      rm -f "$tmp"
      log "WARN: 写回 $path 失败（expect 是否合法 JSON？）"
    fi
  fi
}

while IFS=$'\t' read -r path strategy expect; do
  [[ -z "${path:-}" ]] && continue
  [[ "${path:0:1}" == "#" ]] && continue
  expect="${expect//\$HOME/$HOME}"   # 展开 $HOME
  apply_rule "$path" "$strategy" "$expect"
done < "$GUARD_CONF"

exit 0
