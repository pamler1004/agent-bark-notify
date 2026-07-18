# agent-bark-notify

> Claude Code 任务完成时，Bark 推送到 iPhone 和 Apple Watch——通知标题是随机文案，下面跟一句话任务摘要。

离开电脑去倒水，Claude 把活干完了你却不知道。这个项目让 Claude Code 一停下，你的手腕就震一下，还能从通知看到它**刚干完了什么**。

## 特性

- 🍎 走 Bark → APNs 系统级推送，App 关了也能收；Apple Watch 戴手上时优先震手腕
- 📝 通知带**任务摘要**（Claude 最后那条回复的首行），扫一眼就知道干了啥
- 🎭 文案可自定义（默认中性，另附 5 套风格示例：舔狗 / 摆烂 / 暧昧 / 暴躁 / 发疯）
- 🔔 Claude Code「需要授权」用 `timeSensitive` 级别，**突破勿扰模式**
- 🛡️ **切换模型不影响推送**——hook 走 plugin 系统、不在 `settings.json`，cc-switch / `/model` / 升级都覆盖不到（不用再装看门狗）
- 🔑 Bark key 走 macOS Keychain，不落明文、不进仓库
- ⚡ 零额外依赖（bash + python3，macOS 自带）

## 工作原理

Claude Code 的 Stop hook 直接调用 `scripts/`：

```
Claude Code Stop hook ──→ scripts/notify.sh ─→ scripts/lib.sh ─→ Bark → iPhone/Watch
                          (stdin JSON)        (文案/摘要/发送+重试)
```

详见 [docs/how-it-works.md](docs/how-it-works.md)。

## 前置

1. iPhone 装 [Bark](https://apps.apple.com/us/app/bark-custom-notifications/id1403753865)
2. 获取 **device key**（⚠️ 这步有坑，别复制错）：
   - **正确路径**：Bark app 首页右上角「☁️ 云」图标 → 服务器列表 → 点开 →「复制 key」
   - 复制到的是 **22 位字母数字短串**（如 `aBcDeFgHiJkLmNoPqRsTuV`），即 URL `api.day.app/` 后面那串
   - **千万别复制「设置」里的 device token**（64 位 hex）——那是苹果 APNs 底层 token，不是推送用的 key，复制它推送必返回 `device token not found`

## 安装

**最快——让 Claude 替你装**：把 Bark key 发给 Claude，说一句：

> 帮我装 GitHub 上的 pamler1004/agent-bark-notify 通知插件，这是我的 Bark key：你的KEY。装完告诉我结果，并说一下它附带的可选 settings-guard 模块我需不需要。

Claude 装完会顺带看一眼你的 `settings.json`（有没有用 cc-switch、有没有自定义 statusLine/permissions 等），告诉你需不需要 settings-guard，不会硬塞。

1. 跑这三条装上 plugin 并启用：
   ```bash
   claude plugin marketplace add pamler1004/agent-bark-notify
   claude plugin install agent-bark-notify@agent-bark-notify
   claude plugin enable agent-bark-notify@agent-bark-notify   # install 不自动 enable，必须显式 enable
   ```
2. 把 key 写进 `~/.config/agent-bark-notify/bark.key`（plugin 每次触发都读它，改 key 即时生效）

> ⚠️ **两个必踩的坑**：
> - `claude plugin install --config bark_key=…` 当前版本（v2.1.212）**不生效**（key 设不进 userConfig），所以用 `bark.key` 文件兜底。也可装完跑 `/plugin configure agent-bark-notify@agent-bark-notify` 手动填 key（进 Keychain）。
> - `install` 只装不 `enable`，hook 不会加载。`enable` 之后还得**重启 Claude Code 会话**（plugin hook 是启动时加载的，本次会话进程不重启不生效）。

**或手动装**（在 Claude Code 会话里）：

```
/plugin marketplace add pamler1004/agent-bark-notify
/plugin install agent-bark-notify@agent-bark-notify
```

然后配 key（二选一）：

```bash
mkdir -p ~/.config/agent-bark-notify && echo '你的KEY' > ~/.config/agent-bark-notify/bark.key
```

或在 Claude Code 里 `/plugin configure agent-bark-notify@agent-bark-notify` 填 key。

> 别忘了 `/plugin` 菜单里把 plugin **enable**，然后重启会话。

→ 详见 [docs/claude-code.md](docs/claude-code.md)

## 自定义文案

通知文案分两种情况，每次随机抽一条：

- **任务完成**（done）：Claude 做完停下时
- **需要操作**（action）：Claude 等你授权或回复时

**默认文案**（中性风）长这样：

```
[done]
任务完成|已完成，等你检阅
搞定|结果已就绪
收工|Claude 完成了一轮
任务结束|Claude 停下了，随时回来
完成|需要的话回来验收

[action]
需要确认|有个操作等你授权
等你回复|需要你的输入
需要出手|卡住了，回来看看
```

想换成自己的风格：

1. 把上面的内容复制粘贴到 `~/.config/agent-bark-notify/messages.conf`（想直接用作者那套「皮」的风格——舔狗/摆烂/暧昧/暴躁/发疯——看 [messages.example.conf](config/messages.example.conf)）
2. 改成你想要的词，保存

```bash
mkdir -p ~/.config/agent-bark-notify
nano ~/.config/agent-bark-notify/messages.conf   # 或 open -e（macOS 文本编辑）
```

**格式规则**：
- `[done]` 下面是「任务完成」的文案，`[action]` 下面是「需要操作」的文案
- 每行 `标题|正文`，竖线 `|` 分隔（推送时两者合并成一句标题显示）
- `#` 开头是注释，空行忽略
- 改完**即时生效**（每次推送都重新读这个文件，不用重启）

## 可选：settings-guard 守卫（保护 settings.json 的其他配置）

⚠️ **先说清楚**：本 plugin 的推送**不需要** settings-guard。plugin hook 不在 settings.json，cc-switch 怎么覆盖都推得了（见上一节）。settings-guard 管的是**另一件事**：

保护你 settings.json 里**手写的其他配置**——自定义 `statusLine`、`permissions`、`env`、其他 hooks——不被 cc-switch 切模型、`/model`、Claude Code 升级、iCloud 同步整体重写覆盖，3 秒内自动写回。

举例：你自定义了 statusLine（`bash ~/.claude/statusline.sh`），cc-switch 每次切模型都用它模板里的 statusLine 重置你的——settings-guard 会把你的 statusLine 恢复回来。

**没有需要保护的 settings.json 手写配置，就不用装这个。**

→ 详见 [optional/settings-guard/README.md](optional/settings-guard/README.md)

## 卸载

跟 Claude 说一句（和安装对称，一步搞定）：

> 帮我卸载 agent-bark-notify 通知插件，本地配置也清掉。

Claude 会卸 plugin、删 `~/.config/agent-bark-notify/`（bark.key 和自定义文案都在里面）。重启 Claude Code 会话，Stop hook 彻底移除。

## FAQ

**Q：Apple Watch 能收到吗？**
能。Bark 走系统级推送，Watch 戴手腕上时优先震手表，iPhone 屏幕都不亮。

**Q：要花钱吗？**
不用。Bark app 免费，官方服务器 `api.day.app` 免费。也可[自建 bark-server](https://github.com/finb/bark-server)。

**Q：依赖什么？**
bash 和 python3（macOS 自带），零额外安装。settings-guard 可选模块需要 `jq`（`brew install jq`）。

**Q：通知长什么样？**
**标题**是随机文案（标题+正文合并成一句，如「任务完成，已完成，等你检阅」），下面跟**任务摘要**（Claude 最后回复的首行，≤100 字，已清洗 markdown 前缀）。

**Q：Bark key 安全吗？**
Claude Code plugin 存 macOS Keychain（不落明文）。device key 本质是个推送 token，谁拿到都能往你设备推，**别公开**。

**Q：装完没收到通知？**
按顺序排查：① `/plugin` 菜单确认 plugin 是 **enabled**（install 不自动 enable）；② **重启 Claude Code 会话**（hook 启动时加载）；③ 确认 `~/.config/agent-bark-notify/bark.key` 在；④ 手动测链路：
```bash
echo '{"stop_hook_active":false,"last_assistant_message":"test"}' | ~/.claude/plugins/cache/agent-bark-notify/agent-bark-notify/*/scripts/notify.sh
```
手机收到 = 脚本通，问题在 hook 没触发（回看 ①②）；没收到 = 看 `/tmp/agent-bark-notify.log`。

**Q：发送失败怎么办？**
脚本对网络/SSL 抖动重试 2 次（单次 3s + 间隔 0.5s，最坏 6.5s 内完成）。

**Q：支持 Codex 吗？**
不支持。ChatGPT 桌面 App 的 Codex 给非官方 hook 上了 trust 闸门（hash 校验），用户自定义 hook 永远被判 untrusted、不执行，且 App 没有审批入口——所以本插件只做 Claude Code。

## License

MIT
