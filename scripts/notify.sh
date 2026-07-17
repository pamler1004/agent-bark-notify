#!/usr/bin/env bash
# agent-bark-notify 入口 —— 自动适配两种触发源：
#   - Claude Code Stop hook：JSON 从 stdin 传入
#   - Codex notify：JSON 作为最后一个命令行参数传入（stdin 为 null）
# 由各工具的 hook/notify 配置直接调用，无需用户关心来源。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ $# -ge 1 ]]; then
  # Codex：payload 在最后一个 argv（Codex 把事件 JSON 作为单个参数 append）
  payload=""
  for arg in "$@"; do payload="$arg"; done
  tool="codex"
else
  # Claude Code：payload 在 stdin
  payload="$(cat)"
  tool="claude-code"
fi

[[ -z "${payload:-}" ]] && exit 0
abn_handle "$tool" "$payload"
exit 0
