#!/usr/bin/env bash
# agent-bark-notify 入口 —— Claude Code Stop hook 调用，JSON 从 stdin 传入。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

payload="$(cat)"
[[ -z "${payload:-}" ]] && exit 0
abn_handle "$payload"
exit 0
