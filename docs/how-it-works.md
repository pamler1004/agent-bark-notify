# 工作原理

## 架构

```
Claude Code Stop hook ──→ scripts/notify.sh ─→ scripts/lib.sh ─→ Bark (APNs) → iPhone / Watch
                          (stdin JSON)        (文案/摘要/发送+重试)
```

`notify.sh` 从 stdin 读 hook payload，source `lib.sh` 完成所有逻辑。

## hook payload

Claude Code 的 Stop hook 通过 **stdin** 传 JSON，关键字段：

| 字段 | 说明 |
|------|------|
| `stop_hook_active` | `true` = 用户主动停止 / 需要授权（→ `action` 态）；`false` = 自然完成（→ `done` 态） |
| `last_assistant_message` | Claude 最后那条回复，提取首行做任务摘要（官方推荐） |
| `transcript_path` | 对话 JSONL 路径，`last_assistant_message` 为空时兜底 |

## 摘要提取

- 优先 `last_assistant_message`（官方推荐），`transcript_path` 仅兜底——transcript 是异步写的，Stop 触发时不保证已落盘
- 清洗：去行首 markdown 前缀（`#`/`>`/`-`/`*`/`1.`/` ``` `），剥两端 `**`，截断 100 字（Apple Watch 屏幕小）

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

任一存在即用，都没有则静默退出。

## 依赖

- `bash` 3.2+（macOS 自带即可）
- `python3`（解析 JSON、清洗摘要、发 HTTP；**不依赖 jq**，故零额外安装）

## 安全

- Bark device key 走 Keychain（plugin）或本地文件，**绝不进仓库**
- `.gitignore` 屏蔽 `*.key` / `.bark-key` / `.env`
- 默认文案中性通用；个人风格仅在 `messages.example.conf` 作示例
