# agent-bark-notify

> Claude Code / Codex CLI 任务完成时，Bark 推送到 iPhone 和 Apple Watch——通知正文还带一句话任务摘要。

离开电脑去倒水，Claude 把活干完了你却不知道；Codex 跑完一轮卡在等审批，你也不知道。这个项目让 Agent 一停下，你的手腕就震一下，还能从通知正文看到它**刚干完了什么**。

## 特性

- 🍎 走 Bark → APNs 系统级推送，App 关了也能收；Apple Watch 戴手上时优先震手腕
- 📝 通知正文带**任务摘要**（Agent 最后那条回复的首行），扫一眼就知道干了啥
- 🤖 同时支持 **Claude Code** 和 **Codex CLI**
- 🎭 文案可自定义（默认中性，另附 5 套风格示例：舔狗 / 摆烂 / 暧昧 / 暴躁 / 发疯）
- 🔔 Claude Code「需要授权」用 `timeSensitive` 级别，**突破勿扰模式**
- 🛡️ 可选 settings-guard 守卫，防 `settings.json` 被覆盖丢配置
- 🔑 Bark key 走 macOS Keychain，不落明文、不进仓库
- ⚡ 零额外依赖（bash + python3，macOS 自带）

## 工作原理

一个 core（`scripts/`）+ 两层薄适配，文案 / 摘要 / 重试全共用：

```
Claude Code Stop hook ──────┐
                            ├─→ scripts/notify.sh ─→ scripts/lib.sh ─→ Bark → iPhone/Watch
Codex notify ───────────────┘   (探测来源)           (文案/摘要/发送+重试)
```

详见 [docs/how-it-works.md](docs/how-it-works.md)。

## 前置

1. iPhone 装 [Bark](https://apps.apple.com/us/app/bark-custom-notifications/id1403753865)
2. 打开 Bark，复制 **device key**（首页那串，URL 里 `api.day.app/` 后面的部分）

## Claude Code 安装

**最快——让 Claude 替你装**：把 Bark key 发给 Claude，说一句：

> 帮我装 GitHub 上的 pamler1004/agent-bark-notify 通知插件，这是我的 Bark key：你的KEY

Claude 会跑这两条命令，key 自动进 macOS Keychain：

```bash
claude plugin marketplace add pamler1004/agent-bark-notify
claude plugin install agent-bark-notify@agent-bark-notify --config bark_key=你的KEY
```

**或手动装**（在 Claude Code 会话里）：

```
/plugin marketplace add pamler1004/agent-bark-notify
/plugin install agent-bark-notify@agent-bark-notify
```

装完弹框填 Bark device key。完事。

→ 详见 [docs/claude-code.md](docs/claude-code.md)

## Codex CLI 安装

```bash
git clone https://github.com/pamler1004/agent-bark-notify.git
cd agent-bark-notify
bash codex/install.sh
echo '你的bark-key' > ~/.config/agent-bark-notify/bark.key
```

→ 详见 [docs/codex.md](docs/codex.md)

## 自定义文案

默认文案是中性的。想换成自己的风格：

```bash
mkdir -p ~/.config/agent-bark-notify
# 在默认基础上改：
cp config/messages.default.conf ~/.config/agent-bark-notify/messages.conf
# 或参考作者那套"皮"的风格再改：
cp config/messages.example.conf ~/.config/agent-bark-notify/messages.conf
```

编辑 `messages.conf`，格式：

```
[done]
🎉 搞定了！|快来看看成果吧
✨ 任务完成！|等你检阅

[action]
⚠️ 需要确认|有个操作等你授权
```

`[done]` = 任务完成；`[action]` = 仅 Claude Code 需要授权时。每行 `标题|正文`，随机抽一条。改完即时生效（每次触发都重新读取）。

## 可选：settings-guard 守卫

防 `~/.claude/settings.json` 被 Claude Code 升级、`/model`、cc-switch、`statusline-setup` agent、iCloud 同步等覆盖，丢掉你手写的 statusLine / hooks / 权限配置。3 秒内自动写回。

→ 详见 [optional/settings-guard/README.md](optional/settings-guard/README.md)

## 卸载

- **Claude Code**：`/plugin uninstall agent-bark-notify`
- **Codex**：删 `~/.codex/config.toml` 里的 `notify = [...]` 行 + `rm -rf ~/.config/agent-bark-notify`

## FAQ

**Q：Apple Watch 能收到吗？**
能。Bark 走系统级推送，Watch 戴手腕上时优先震手表，iPhone 屏幕都不亮。

**Q：要花钱吗？**
不用。Bark app 免费，官方服务器 `api.day.app` 免费。也可[自建 bark-server](https://github.com/finb/bark-server)。

**Q：依赖什么？**
bash 和 python3（macOS 自带），零额外安装。settings-guard 可选模块需要 `jq`（`brew install jq`）。

**Q：通知正文带什么？**
标题是随机文案（如「🎉 搞定了！」），正文是文案 + 任务摘要（Agent 最后回复的首行，≤100 字，已清洗 markdown 前缀）。

**Q：Bark key 安全吗？**
Claude Code plugin 存 macOS Keychain（不落明文）；Codex 存本地文件或环境变量。device key 本质是个推送 token，谁拿到都能往你设备推，**别公开**。

**Q：发送失败怎么办？**
脚本对网络/SSL 抖动重试 2 次（单次 3s + 间隔 0.5s，最坏 6.5s 内完成）。

## License

MIT
