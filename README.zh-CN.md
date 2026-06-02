<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <b>简体中文</b> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> 本翻译由社区或机器生成，可能落后于英文版 README。请以英文版本为准。请参阅 [English README](README.md)。

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Sleepless 让你的 MacBook 在合盖、使用电池、没有外接显示器的情况下保持唤醒。</b><br>
  <sub>一个原生菜单栏开关，并在你设定的电量水平自动关闭，让你永远不会把电耗光。</sub>
</p>

<p align="center">
  <a href="https://github.com/Aboudjem/Sleepless/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Aboudjem/Sleepless/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aboudjem/Sleepless?label=release&logo=apple&logoColor=white"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aboudjem/Sleepless/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/Aboudjem/Sleepless?color=blue"></a>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-26%20·%20Apple%20Silicon-7c5cf0?logo=apple&logoColor=white">
  <a href="https://github.com/Aboudjem/Sleepless/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Aboudjem/Sleepless?style=social"></a>
</p>

<p align="center">
  <img alt="Sleepless demo: flip the switch, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

> [!NOTE]
> 合上盖子通常会让你的 Mac 进入睡眠，而基于 `caffeinate` 的应用（KeepingYouAwake 之类）**无法**改变这一点。Sleepless 切换的是唯一能做到这件事的设置，`pmset disablesleep`，然后用电量下限自动关闭来加以保护，所以你可以放心地忘掉它。

## 你能得到什么

|  |  |
|---|---|
| 🌙 **一个开关** | 点击菜单栏里的月亮，拨动开关。图标一眼就能看出当前状态。 |
| 🔋 **电量下限自动关闭** | 设定一个下限（5–50%，默认 15%）。在电池供电时，它会在你耗光电量之前自动关闭。 |
| 🖥️ **无需显示器、无需转接** | 只要合上盖子、使用电池即可。不需要外接显示器，也不需要假 HDMI 插头。 |
| 🪶 **小巧且原生** | AppKit + SF Symbols。没有 Dock 图标，没有后台守护进程，没有 kext，没有依赖。 |

## 安装

**Homebrew**（推荐）：

```sh
brew install --cask aboudjem/tap/sleepless
# one-time: add the passwordless grant (it prints exactly what it writes first)
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

**从源码构建**（信任路径：自己读、自己构建，不会有 Gatekeeper 提示）：

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless && ./install.sh
```

**或者直接下载应用：** 获取[最新发布版本](https://github.com/Aboudjem/Sleepless/releases/latest)，解压，把 `Sleepless.app` 移动到 `/Applications`。它是临时签名（ad-hoc）的，所以请在首次启动时通过 **系统设置 → 隐私与安全性 → 仍要打开** 来批准（以前右键 → 打开的小技巧已在 macOS 15 中被移除）。

然后点击月亮，拨动开关，合上盖子。`./uninstall.sh` 会移除所有内容，并证明授权已被清除。

## 工作原理

`caffeinate` 以及它所用的电源断言（power assertions）无法覆盖硬件层面的合盖触发，所以合上盖子总是会让 Mac 睡眠。唯一能覆盖它的系统设置是 `pmset disablesleep`。Sleepless 通过一个原生开关来切换它，并读回实时值，所以界面绝不会撒谎，还会在你的电量下限处自动还原。重启同样会重置它。[完整安全模型 →](SECURITY.md)

## Sleepless 与其他方案对比

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 合盖、电池供电时保持唤醒 | ✅ | ✅¹ | ❌ | ✅ | ⚠️ 需外接显示器 | ❌ |
| 无需外接显示器 | ✅ | ✅ | 不适用 | ✅ | ❌ | 不适用 |
| 电量下限自动关闭 | ✅ | 仅低电量 | ✅² | ❌ | ❌ | ❌ |
| 开源 | ✅ MIT | ❌ App Store | ✅ MIT | ✅ Apache | ✅ GPL | Apple |

<sub>¹ Amphetamine 能做到，但在 Apple Silicon 上依赖一个独立的“Power Protect”脚本，且被普遍反映会在电源或扩展坞变化时失效。 &nbsp; ² KeepingYouAwake 有电量截止功能，但按其设计无法在合盖时保持唤醒。星标数（约 6.6k / 约 18 / 约 101）于 2026-06-01 获取；欢迎指正。</sub>

## 用它来……

- 🤖 **走开之后让长任务自己跑完。** 一次 AI 智能体运行、一次构建、一次渲染、ML 训练、一个大的 `brew`/`npm` 安装：打开开关，合上盖子，把它放进包里，回来时任务已经完成。
- 📡 **移动中共享你的热点。** Mac 上的互联网共享 / 个人热点在合盖时也会继续提供服务。
- ⬇️ **让大型传输继续运行。** 大文件下载、上传，或一次 Time Machine 备份会在你离开时完成。
- 🖥️ **保持服务器或 SSH 会话存活。** 本地开发服务器、同步守护进程，或远程会话在合盖时仍然可达。
- 🎧 **让音频持续播放。** 音乐或长时间渲染会在包里继续进行。

> [!TIP]
> 把电量下限设到你信得过的水平（比如 20%），上面这些事你都能做，而不必盯着电量。

## 它安全吗？

安全，而且它的设计就是可审计的。GUI 应用无法输入密码，所以安装程序会添加一条范围严格限定的 `/etc/sudoers.d` 规则（root 所有，`0440`），它**只允许两条命令，别无其他**：

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **它无法被放宽。** `sudoers` 按字面匹配参数，没有通配符，所以任何其他命令都会重新要求密码。
- **没有守护进程、没有辅助脚本**可供攻击者劫持。它直接用一个 argv 数组调用 Apple 的 `/usr/bin/pmset`（不经过 shell）。
- **始终可逆。** 重启会重置该标志，电量下限会将其关闭，`./uninstall.sh` 会移除授权并加以证明。

完整的威胁模型、未被记录但真实存在的 `disablesleep` 证据，以及公证（notarization）取舍都在 **[SECURITY.md](SECURITY.md)** 中。

## 常见问题

<details>
<summary><b>它真的能在合盖、电池供电、没有显示器的情况下工作吗？</b></summary>

是的，这正是重点所在。已在 macOS 26（Tahoe）/ Apple Silicon 上验证。
</details>

<details>
<summary><b>菜单栏里没有显示月亮。</b></summary>

macOS 26 可能会隐藏菜单栏项目。请检查系统设置（控制中心 / 菜单栏），允许 Sleepless 显示它的项目。用 <code>pgrep -x Sleepless</code> 确认它正在运行。
</details>

<details>
<summary><b>为什么它没有公证？</b></summary>

它是一个个人的开源工具，没有付费的 Apple Developer ID，所以采用临时签名（ad-hoc）。从源码构建可以完全跳过 Gatekeeper，或者对预构建的应用使用 <b>仍要打开</b> 流程。
</details>

<details>
<summary><b>它会耗光我的电池吗？</b></summary>

只有当你忽略电量下限时才会。在唤醒并放电期间，它会在你设定的百分比（默认 15%）处自动关闭，而重启总会恢复正常睡眠。
</details>

<details>
<summary><b>它能在 Intel 或更旧的 macOS 上工作吗？</b></summary>

它已在 <b>macOS 26 Apple Silicon</b> 上验证。<code>disablesleep</code> 未被记录，所以其他版本或硬件不保证可用。试一试并反馈，欢迎诚实的报告。
</details>

## 参与贡献

欢迎提交 Issue 和 PR，尤其欢迎翻译以及来自其他硬件的测试报告。请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 和[行为准则](CODE_OF_CONDUCT.md)。Sleepless 会刻意保持小巧。

## 许可证

[MIT](LICENSE) © 2026 Adam Boudjemaa。

<p align="center">
  <sub>如果 Sleepless 帮你省去了一趟终端，点个 ⭐ 能帮助更多人发现它。</sub>
</p>

