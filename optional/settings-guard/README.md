# settings-guard（可选模块）

**通用 Claude Code `settings.json` 字段守卫。** 监听 `~/.claude/settings.json` 变化，发现你声明要保护的关键字段被丢掉或被改，3 秒内自动写回。

## 为什么要它

会覆盖 `settings.json` 的场景比想象的多：

- **Claude Code 自身**：`/model` 命令、设置 UI、版本升级时的迁移/重置（最普遍）
- **`statusline-setup` agent**（会覆盖 statusLine）
- **模型切换工具**：cc-switch、claude-code-router、CCR 等
- **同步回写**：iCloud / dotfiles 同步
- 手动误编辑

如果你的 statusLine、手写的 hooks、权限配置等被这些场景清掉，这个守卫会把它们补回来。

> 它**不依赖 cc-switch**，cc-switch 只是动机案例之一。守卫只盯 `settings.json` 这一个文件，谁改的都触发。

## 依赖

- macOS（用 launchd）
- `jq`：`brew install jq`

## 安装

```bash
bash optional/settings-guard/install.sh
```

会：拷 `guard.sh` 到 `~/.config/agent-bark-notify/settings-guard/`、生成 launchd plist、加载。

## 配置要保护的字段

编辑 `~/.config/agent-bark-notify/settings-guard/guard.conf`，每行一条规则：

```
jq路径 <TAB> 策略 <TAB> 期望值(JSON)
```

策略：
- `missing` — 字段缺失/为空才补（保守，不动你已有的值）
- `change` — 字段偏离期望就纠正（激进，适合"绝不允许被改"的字段）
- `both` — 缺失或偏离都纠正

示例：

```
.statusLine	change	{"type":"command","command":"bash $HOME/.claude/statusline.sh"}
.hooks.Stop	both	[{"matcher":"","hooks":[{"type":"command","command":"bash $HOME/.claude/scripts/your-hook.sh","timeout":10}]}]
```

`$HOME` 会自动展开。改完跑 `launchctl start com.user.claude-settings-guard` 立即执行一次。

## 验证

```bash
# 故意把 statusLine 清空
jq '.statusLine = {}' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
# 3 秒内会被守卫写回
tail -f /tmp/agent-bark-notify-guard.log
```

## 工作方式

- **事件驱动**（launchd `WatchPaths`），不是定时轮询——`settings.json` 一被写就触发
- `ThrottleInterval=3` 合并突发写
- 原子写回（mktemp + mv），防半写状态
- 幂等：写回会再触发监听，但下次检查变成 no-op，**自稳定不死循环**
- 只动你声明要保护的字段，不碰 model / env 等其它配置

## 卸载

```bash
launchctl unload ~/Library/LaunchAgents/com.user.claude-settings-guard.plist
rm ~/Library/LaunchAgents/com.user.claude-settings-guard.plist
rm -rf ~/.config/agent-bark-notify/settings-guard
```
