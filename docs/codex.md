# Codex CLI 安装

## 前置

- `python3`（macOS 自带；其它系统 `brew install python` / `apt install python3`）
- iPhone 装 Bark，复制 device key

## 一键安装

```bash
git clone https://github.com/pamler1004/agent-bark-notify.git
cd agent-bark-notify
bash codex/install.sh
```

它会：
1. 把 `scripts/` + `config/` 拷到 `~/.config/agent-bark-notify/`
2. 在 `~/.codex/config.toml` 写入 `notify = ["bash", ".../notify.sh"]`（**幂等**，重复跑不会重复写）
3. 检测到你已有 `notify` 配置时会提醒你手动合并，不会覆盖

然后配 Bark key（二选一）：

```bash
echo '你的key' > ~/.config/agent-bark-notify/bark.key
# 或在 ~/.zshrc / ~/.bashrc 里：
export BARK_KEY='你的key'
```

## 手动配置（不想跑 install.sh）

在 `~/.codex/config.toml` 加一行：

```toml
notify = ["bash", "/完整路径/agent-bark-notify/scripts/notify.sh"]
```

## 工作原理

Codex turn 完成时触发 `agent-turn-complete` 事件，把事件 JSON 作为**最后一个命令行参数**传给 `notify.sh`（stdin 是 null）。脚本提取 `last-assistant-message` 当摘要、发 Bark。

> Codex 的 `notify` 目前只支持 `agent-turn-complete` 一种事件（没有「需要授权」事件），所以 Codex 只会收到「任务完成」类文案。需要审批提醒走 Codex 自己的 `tui.notifications`。

## 卸载

1. 从 `~/.codex/config.toml` 删掉 `notify = [...]` 那行
2. `rm -rf ~/.config/agent-bark-notify`
