# Claude Code 安装

## 前置

1. iPhone 装 [Bark](https://apps.apple.com/us/app/bark-custom-notifications/id1403753865)
2. 打开 Bark，复制你的 **device key**（首页那串，URL 里 `api.day.app/` 后面的部分）

## 安装

### 方式一：让 Claude 替你装（最省事）

把 Bark key 发给 Claude，说一句：

> 帮我装 GitHub 上的 pamler1004/agent-bark-notify 通知插件，这是我的 Bark key：你的KEY

Claude 会：

1. 装上 plugin：
   ```bash
   claude plugin marketplace add pamler1004/agent-bark-notify
   claude plugin install agent-bark-notify@agent-bark-notify
   ```
2. 把 key 写进 `~/.config/agent-bark-notify/bark.key`（plugin 每次触发都读它，改 key 即时生效）

> ⚠️ `claude plugin install --config bark_key=…` 这个 flag **当前版本（v2.1.212）不生效**（key 设不进 userConfig），所以用 `bark.key` 文件兜底。也可装完在 Claude Code 里跑 `/plugin configure agent-bark-notify@agent-bark-notify` 手动填 key（进 Keychain）。
>
> ⚠️ **换 key 注意**：`/plugin configure` 配的 key 存 Keychain，**跨卸载/重装不清**。换 key 直接改 `bark.key` 文件即可（文件优先级高于 userConfig）；若你以前配过 userConfig、想彻底干净，`/plugin configure` 把 bark_key 清空。两者不一致时脚本会在 `/tmp/agent-bark-notify.log` 打 WARNING，不再静默用旧 key。

### 方式二：手动斜杠命令

在 Claude Code 会话里：

```
/plugin marketplace add pamler1004/agent-bark-notify
/plugin install agent-bark-notify@agent-bark-notify
```

装完弹框填 key。

## 工作原理

plugin 的 `Stop` hook 调用 `scripts/notify.sh`，Claude Code 把 hook JSON 通过 **stdin** 传入。脚本读 `last_assistant_message` 提取摘要、按 `stop_hook_active` 区分「完成 / 需要操作」、发 Bark。

plugin 不碰你的 `~/.claude/settings.json`，与你已有的 Stop hook 叠加生效，互不冲突。

## 配置项（userConfig）

| 项 | 说明 | 默认 |
|----|------|------|
| `bark_key` | 必填，Bark device key（敏感，进 Keychain） | — |
| `bark_server` | 自建 Bark 服务地址 | `https://api.day.app` |
| `sound` | iOS 提示音名（如 `calypso`） | 空（用 app 默认） |
| `icon` | 通知图标图片 URL（HTTPS） | 空（用 app 默认） |

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
