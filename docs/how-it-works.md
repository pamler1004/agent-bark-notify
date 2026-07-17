# 工作原理

## 架构：一个 core + 两层薄适配

```
                  ┌─ Claude Code ─────────────┐
                  │  plugin hooks/hooks.json  │
                  │  Stop hook → notify.sh    │ ── stdin JSON ──┐
                  └───────────────────────────┘                  │
                                                                 ▼
                                                     ┌─────────────────────┐
                  ┌─ Codex ───────────────────────┐  │  scripts/notify.sh  │
                  │  ~/.codex/config.toml         │  │  (入口：探测来源)    │
                  │  notify = [... notify.sh]     │ ── argv JSON ────▶ │
                  └───────────────────────────────┘  └────────┬────────────┘
                                                                │ source
                                                                ▼
                                                     ┌─────────────────────┐
                                                     │  scripts/lib.sh     │
                                                     │  归一化 / 文案 /    │
                                                     │  摘要 / Bark + 重试  │
                                                     └────────┬────────────┘
                                                                │ POST
                                                                ▼
                                                     Bark (APNs) → iPhone / Apple Watch
```

`notify.sh` 唯一职责是探测来源并 source `lib.sh`；所有逻辑在 `lib.sh`，工具无关。

## 触发源差异

| 项 | Claude Code | Codex |
|----|-------------|-------|
| 配置位置 | plugin `hooks/hooks.json` | `~/.codex/config.toml` 的 `notify` |
| 数据传入 | **stdin** JSON | **argv 最后一个参数**（JSON）；stdin 为 null |
| 事件 | `Stop`（含 `stop_hook_active`） | `agent-turn-complete`（目前仅此一种） |
| 状态 | `done` / `action` 两态 | 只有 `done` |
| 最后消息字段 | `last_assistant_message`（snake_case） | `last-assistant-message`（kebab-case） |

## 入口探测

```bash
if [ $# -ge 1 ]; then     # Codex：payload 在最后一个 argv
  payload=""; for a in "$@"; do payload="$a"; done
else                       # Claude Code：payload 在 stdin
  payload="$(cat)"
fi
```

取最后一个 argv 用循环遍历（兼容 macOS 自带 bash 3.2，不用负数切片）。

## 摘要提取

- **Claude Code**：优先 `last_assistant_message`（官方推荐），`transcript_path` 仅兜底——transcript 是异步写的，Stop 触发时不保证已落盘。
- **Codex**：`last-assistant-message`（kebab-case，用 python 取，避开 jq 对 `-` 当减法的坑）。
- 清洗：去行首 markdown 前缀（`#`/`>`/`-`/`*`/`1.`/` ``` `），剥两端 `**`，截断 100 字（Apple Watch 屏幕小）。

## 文案

- 默认 `config/messages.default.conf`（中性）
- `~/.config/agent-bark-notify/messages.conf` 覆盖默认
- `[done]` / `[action]` 两段，每行 `标题|正文`，按 state 随机抽（macOS `sort -R`）
- 正文 = 随机短句 + 换行 + 任务摘要

## Bark 发送

`POST {server}/{key}`，JSON body。**含重试**（2 次，单次 timeout 3s，间隔 0.5s，最坏 6.5s < Claude Code hook timeout 10s），应对自建/官方服务器偶发 SSL 握手超时。

推送级别：`done` → `active`；`action` → `timeSensitive`（突破勿扰模式）。

## Bark key 优先级链

```
$BARK_KEY (env)  →  $CLAUDE_PLUGIN_OPTION_BARK_KEY (plugin userConfig)  →
~/.config/agent-bark-notify/bark.key  →  ~/.claude/.bark-key (兼容旧路径)
```

任一存在即用，都没有则静默退出。这让 Claude Code（plugin）和 Codex（文件/env）共用一套逻辑。

## 依赖

- `bash` 3.2+（macOS 自带即可）
- `python3`（解析 JSON、清洗摘要、发 HTTP；**不依赖 jq**，故零额外安装）

## 安全

- Bark device key 走 Keychain（plugin）或本地文件，**绝不进仓库**
- `.gitignore` 屏蔽 `*.key` / `.bark-key` / `.env`
- 默认文案中性通用；个人风格仅在 `messages.example.conf` 作示例
