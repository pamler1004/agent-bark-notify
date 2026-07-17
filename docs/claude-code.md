# Claude Code 安装

## 前置

1. iPhone 装 [Bark](https://apps.apple.com/us/app/bark-custom-notifications/id1403753865)
2. 打开 Bark，复制你的 **device key**（首页那串，URL 里 `api.day.app/` 后面的部分）

## 安装（plugin marketplace，推荐）

在 Claude Code 会话里依次执行：

```
/plugin marketplace add pamler1004/agent-bark-notify
/plugin install agent-bark-notify@agent-bark-notify
```

安装时会让你填 Bark device key（存进 macOS Keychain，不落明文）。填完即生效。

> 也可以让 Agent 替你装：直接说「帮我装 pamler1004/agent-bark-notify 这个通知 plugin」，Agent 会跑对应的 `claude plugin` CLI 子命令。

## 工作原理

plugin 的 `Stop` hook 调用 `scripts/notify.sh`，Claude Code 把 hook JSON 通过 **stdin** 传入。脚本读 `last_assistant_message` 提取摘要、按 `stop_hook_active` 区分「完成 / 需要操作」、发 Bark。

plugin 不碰你的 `~/.claude/settings.json`，与你已有的 Stop hook 叠加生效，互不冲突。

## 配置项（userConfig）

| 项 | 说明 | 默认 |
|----|------|------|
| `bark_key` | 必填，Bark device key（敏感，进 Keychain） | — |
| `bark_server` | 自建 Bark 服务地址 | `https://api.day.app` |
| `sound` | iOS 提示音名（如 `calypso`） | 空（用 app 默认） |

改配置：`/plugin` 菜单里编辑该 plugin 的 userConfig。

## 自定义文案

复制默认文案并编辑：

```bash
mkdir -p ~/.config/agent-bark-notify
cp ~/.claude/plugins/.../config/messages.default.conf ~/.config/agent-bark-notify/messages.conf
# 编辑 messages.conf，改 [done] / [action] 下的 "标题|正文"
```

详见根目录 README 的「自定义文案」。

## 卸载

```
/plugin uninstall agent-bark-notify
```
