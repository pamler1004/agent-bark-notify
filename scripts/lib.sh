#!/usr/bin/env bash
# agent-bark-notify 核心库 —— 被 notify.sh source
# Claude Code Stop hook 触发，payload 从 stdin 传入（JSON）
# 唯一运行时依赖：bash 3.2+ 和 python3（用 python3 解析 JSON，不依赖 jq）

# ---------------- 默认配置（可被环境变量覆盖）----------------
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-5}"
COOLDOWN_FILE="${COOLDOWN_FILE:-/tmp/agent-bark-notify-last}"
LOG_FILE="${LOG_FILE:-/tmp/agent-bark-notify.log}"
DEFAULT_BARK_SERVER="https://api.day.app"   # Bark 官方默认服务器，开箱即用
DEFAULT_SOUND=""                              # 留空 = 用 Bark app 默认提示音
DEFAULT_ICON=""                               # 留空 = 用 Bark app 默认图标；可设 HTTPS 图标 URL

ABN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------- 日志 ----------------
abn_log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true; }

# ---------------- Bark key / server / sound 优先级链 ----------------
# key: 环境变量 BARK_KEY > Claude Code plugin userConfig > ~/.config/agent-bark-notify/bark.key > ~/.claude/.bark-key（兼容旧路径）
abn_resolve_key() {
  if [[ -n "${BARK_KEY:-}" ]]; then printf '%s' "$BARK_KEY"; return 0; fi
  if [[ -n "${CLAUDE_PLUGIN_OPTION_BARK_KEY:-}" ]]; then printf '%s' "$CLAUDE_PLUGIN_OPTION_BARK_KEY"; return 0; fi
  local user_conf="${XDG_CONFIG_HOME:-$HOME/.config}/agent-bark-notify/bark.key"
  if [[ -f "$user_conf" ]]; then cat "$user_conf" 2>/dev/null; return 0; fi
  if [[ -f "$HOME/.claude/.bark-key" ]]; then cat "$HOME/.claude/.bark-key" 2>/dev/null; return 0; fi
  return 1
}
abn_resolve_server() {
  printf '%s' "${CLAUDE_PLUGIN_OPTION_BARK_SERVER:-${BARK_SERVER:-$DEFAULT_BARK_SERVER}}"
}
abn_resolve_sound() {
  printf '%s' "${CLAUDE_PLUGIN_OPTION_SOUND:-${BARK_SOUND:-$DEFAULT_SOUND}}"
}
abn_resolve_icon() {
  printf '%s' "${CLAUDE_PLUGIN_OPTION_ICON:-${BARK_ICON:-$DEFAULT_ICON}}"
}

# ---------------- 冷却 ----------------
abn_check_cooldown() {
  if [[ -f "$COOLDOWN_FILE" ]]; then
    local last now
    last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    if (( now - last < COOLDOWN_SECONDS )); then return 1; fi
  fi
  return 0
}
abn_update_cooldown() { date +%s > "$COOLDOWN_FILE" 2>/dev/null || true; }

# ---------------- 摘要清洗（去行首 markdown 前缀，截断 100 字）----------------
abn_clean_summary() {
  python3 -c '
import sys, re
t = sys.stdin.read().strip()
bt = chr(96)
candidate = ""
for ln in t.split("\n"):
    s = ln.strip()
    if not s or s.startswith(bt * 3):
        continue
    candidate = s
    break
candidate = re.sub(r"^\s*(#{1,6}\s*|>\s*|[-*+]\s+|\d+\.\s+)+", "", candidate)
candidate = candidate.strip(bt).strip()
candidate = re.sub(r"^\*\*(.+?)\*\*$", r"\1", candidate).strip()
if len(candidate) > 100:
    candidate = candidate[:100] + "..."
print(candidate)
'
}

# ---------------- 从 Claude Code payload 提摘要 ----------------
# 官方推荐用 last_assistant_message；transcript_path 仅作兜底（异步写不保证落盘）
abn_summary_cc() {
  local payload="$1" text
  text=$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
text = d.get("last_assistant_message") or ""
if not text:
    p = d.get("transcript_path")
    if p:
        try:
            last = ""
            with open(p) as f:
                for line in f:
                    try:
                        o = json.loads(line)
                    except Exception:
                        continue
                    if o.get("type") != "assistant":
                        continue
                    c = o.get("message", {}).get("content", [])
                    if isinstance(c, list):
                        for b in c:
                            if isinstance(b, dict) and b.get("type") == "text":
                                t = (b.get("text") or "").strip()
                                if t:
                                    last = t
            text = last
        except Exception:
            pass
print(text)
')
  if [[ -n "$text" ]]; then printf '%s' "$text" | abn_clean_summary; fi
}

# ---------------- 文案加载 ----------------
# 优先用户自定义 ~/.config/agent-bark-notify/messages.conf，否则打包默认
abn_messages_file() {
  local user_conf="${XDG_CONFIG_HOME:-$HOME/.config}/agent-bark-notify/messages.conf"
  if [[ -f "$user_conf" ]]; then echo "$user_conf"; return 0; fi
  local default="$ABN_LIB_DIR/../config/messages.default.conf"
  if [[ -f "$default" ]]; then echo "$default"; return 0; fi
  return 1
}

# 随机返回指定 state 的一条文案，格式 "title|body"
abn_pick_message() {
  local state="$1" file line
  file=$(abn_messages_file) || { echo "任务完成|Claude 已完成当前任务"; return; }
  line=$(awk -v sect="$state" '
    BEGIN { in_sec = 0 }
    /^\[/ { gsub(/[\[\]]/, "", $0); in_sec = ($0 == sect); next }
    in_sec && $0 !~ /^[[:space:]]*#/ && NF { print }
  ' "$file" | sort -R | head -1)
  echo "${line:-任务完成|Claude 已完成当前任务}"
}

# ---------------- 发送（含重试，应对服务器偶发抖动）----------------
# 2 次尝试，单次 3s + 间隔 0.5s，最坏 6.5s（< Claude Code hook timeout 10s）
abn_send_bark() {
  local title="$1" body="$2" group="$3" level="$4"
  local key server sound icon
  key=$(abn_resolve_key) || { abn_log "ERROR: no bark key found"; return 1; }
  server=$(abn_resolve_server)
  sound=$(abn_resolve_sound)
  icon=$(abn_resolve_icon)
  TITLE="$title" BODY="$body" GROUP="$group" LEVEL="$level" SOUND="$sound" ICON="$icon" SERVER="$server" KEY="$key" python3 <<'PY'
import json, os, urllib.request, time
title = os.environ["TITLE"]; body = os.environ["BODY"]; group = os.environ["GROUP"]
level = os.environ["LEVEL"]; sound = os.environ["SOUND"]; icon = os.environ["ICON"]
server = os.environ["SERVER"]; key = os.environ["KEY"]
data = {"title": title, "body": body, "group": group, "level": level}
if sound: data["sound"] = sound
if icon:  data["icon"] = icon
url = server.rstrip("/") + "/" + key
payload = json.dumps(data).encode("utf-8")
headers = {"Content-Type": "application/json; charset=utf-8"}
max_attempts = 2
for attempt in range(1, max_attempts + 1):
    req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            print("OK " + resp.read().decode())
            break
    except Exception as e:
        print("FAIL attempt=%d/%d: %s" % (attempt, max_attempts, e))
        if attempt < max_attempts:
            time.sleep(0.5)
PY
}

# ---------------- 编排 ----------------
abn_handle() {
  local payload="$1"
  abn_log "=== fire ==="

  local state summary active
  active=$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print("true" if d.get("stop_hook_active") is True else "false")
')
  if [[ "$active" == "true" ]]; then state="action"; else state="done"; fi
  summary=$(abn_summary_cc "$payload")

  local pick title message group level body
  pick=$(abn_pick_message "$state")
  title="${pick%%|*}"
  message="${pick#*|}"
  # 标题 + 正文合并成更详细的一句标题
  if [[ -n "$message" && "$message" != "$pick" ]]; then
    title="$title，$message"
  fi

  if [[ "$state" == "action" ]]; then
    group="agent-action"; level="timeSensitive"   # 突破勿扰
  else
    group="agent-done"; level="active"
  fi

  body="$summary"   # 正文只放任务摘要（文案已在标题里）

  if ! abn_check_cooldown; then abn_log "cooldown, skip"; return 0; fi

  local resp
  resp=$(abn_send_bark "$title" "$body" "$group" "$level") || true
  abn_log "sent: title='$title' body='$body' resp='$resp'"
  abn_update_cooldown
}
