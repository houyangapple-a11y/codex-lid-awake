# macOS / MacBook 合盖不休眠：Codex 任务续航工具

[![版本](https://img.shields.io/badge/版本-v1.0.0-blue)](https://github.com/houyangapple-a11y/macos-codex-lid-awake/releases/tag/v1.0.0)
[![平台](https://img.shields.io/badge/平台-macOS-lightgrey)](#使用条件)
[![许可证](https://img.shields.io/badge/许可证-MIT-green)](LICENSE)

这是一个轻量级 macOS 合盖不休眠工具（closed-lid keep-awake）：**只有当 Codex 桌面版正在执行任务时**，Mac 或 MacBook 合盖后才会继续运行。

适用于“MacBook 合盖不休眠”“Mac 合盖继续运行 Codex”“macOS prevent sleep / keep awake”等场景。它基于 `pmset` 和 `LaunchDaemon` 工作，不需要修改 Codex，也不会常驻阻止系统睡眠。

- Codex 空闲时完全不改变系统原本的合盖睡眠行为。
- Codex 执行任务期间合盖，最多继续工作 30 分钟。
- 如果任务提前完成，大约 2 秒内恢复正常合盖睡眠。
- 不读取 Codex 数据库、任务文件、提示词或任何仓库内容。
- 不向 Codex 进程发送信号，也不修改 Codex 进程；只通过 `pmset -g assertions` 读取系统电源断言。

## 工作原理

Codex 在生成回复或调用工具时，其桌面进程会持有 macOS 的 `NoIdleSleepAssertion`。本工具把这个只读系统信号作为“任务正在执行”的判断依据，并且只切换与之独立的系统级 `disablesleep` 开关。

没有 Codex 活跃断言时，守护进程会确保 `disablesleep=0`，而且不会读取合盖传感器。检测到任务活跃后，它才会启用合盖保护，并为每次连续合盖设置 30 分钟上限。

## 使用条件

- macOS
- Codex 桌面版（进程可能显示为 ChatGPT 或 Codex）
- 安装时需要管理员权限

桌面版使用的断言名称属于实现细节，未来版本更新后可能发生变化。

## 适用场景与关键词

- MacBook 合盖后让 Codex 继续执行任务
- Mac 合盖继续运行 30 分钟，并保持网络连接
- macOS closed lid keep awake / prevent sleep
- 按 Codex 活跃状态自动控制 `pmset disablesleep`
- 任务结束后自动恢复正常合盖睡眠

## 安装

推荐从 [v1.0.0 发布页面](https://github.com/houyangapple-a11y/macos-codex-lid-awake/releases/tag/v1.0.0) 下载源码包，解压后执行：

```bash
chmod +x install.sh codex-lid-awake-30m.sh
sudo ./install.sh
```

检查运行状态：

```bash
sudo launchctl print system/com.codex.lid-awake-30m
pmset -g live | head
```

## 卸载

```bash
sudo launchctl bootout system/com.codex.lid-awake-30m 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.codex.lid-awake-30m.plist
sudo rm -f /usr/local/libexec/codex-lid-awake-30m.sh
sudo pmset -a disablesleep 0
```

## 安全提示

Mac 合盖运行时可能产生热量。请把电脑放在坚硬、通风的表面上；保护生效期间不要把电脑放进背包或遮挡散热区域。

2 秒轮询间隔经过轻量化设计。在开发设备上，守护进程静置时显示的 CPU 和内存占用均接近 0%。

## 开源许可证

MIT
