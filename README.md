<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <b>English</b> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <b>Keep your MacBook awake with the lid closed, on battery, with no external display.</b><br>
  One native menu-bar switch. A battery-floor auto-off so you never cook the battery.
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
  <img alt="Sleepless demo: toggle the switch, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

---

## What it does

Close your MacBook's lid and it sleeps. That is usually what you want, but not when an
overnight build, a long download, an agent run, or a personal hotspot needs to keep going
while the laptop is in your bag.

**Sleepless** is a tiny menu-bar app that flips the one system setting which actually keeps a
Mac awake with the lid shut, `pmset disablesleep`, then guards it with an automatic
**battery-floor auto-off** so a forgotten "on" state can't drain the battery or trap heat.

- 🌙 **One native switch.** Click the moon in the menu bar, flip the toggle. The glyph shows
  state at a glance: hollow `moon` (off), filled `moon.fill` (on), `moon.stars.fill` (armed:
  awake on battery, auto-off live).
- 🔋 **Battery-floor auto-off.** Drag a slider (5–50%, default 15%). While awake and
  discharging, Sleepless turns itself off when you hit that floor.
- 🖥️ **No external display, no power adapter, no dummy dongle.** Just the lid closed, on battery.
- 🪶 **Native and tiny.** AppKit + SF Symbols, no Dock icon, no third-party dependencies, no
  background daemon, no kext. The whole app is one `App.swift`.
- 🔍 **Honest about state.** It reads the live system value back after every toggle, so the
  switch reflects reality, never a hopeful assumption.

## Install

### Homebrew (recommended)

```sh
brew install --cask aboudjem/tap/sleepless
```

That taps `Aboudjem/homebrew-tap` and installs `Sleepless.app`. Then run the one-time grant
(bundled inside the app) so it can toggle sleep without a password prompt. It prints exactly
what it writes before asking:

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

### Download the release

Grab `Sleepless-1.0.0.zip` from [**Releases**](https://github.com/Aboudjem/Sleepless/releases/latest),
unzip, and move `Sleepless.app` to `/Applications`. Because it is ad-hoc signed (not
notarized), macOS Gatekeeper will block the first launch: open **System Settings → Privacy &
Security → Open Anyway**. (On macOS 15+ the old right-click → Open trick no longer works.)

### Build from source (no Gatekeeper prompt)

The trust model is "read the source, build it yourself." Locally built apps are not
quarantined, so they just run.

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./install.sh        # builds, installs to /Applications, adds the grant + login item
```

`./build.sh` alone just produces `build/Sleepless.app` (Command Line Tools only, no Xcode).
`./uninstall.sh` removes everything and proves the grant is gone.

## Why Sleepless exists

Apple's `caffeinate` (and every menu-bar app built on it, like KeepingYouAwake) **cannot**
keep a Mac awake with the lid closed. The IOKit power assertions it uses don't override the
hardware clamshell-sleep trigger, so closing the lid sleeps the Mac regardless. The only
system lever that overrides clamshell sleep is `pmset disablesleep`.

A few tools do reach for `disablesleep`, but each leaves a gap: Amphetamine does it (and a lot
more) but its closed-display path is notoriously finicky on Apple Silicon; Macchiato does the
exact mechanism but ships **no** battery guard; Clapet only triggers when an **external
display** is connected. Sleepless is the purpose-built, open-source tool for the plain case:
**lid closed, on battery, no display, with an auto-off so it's safe to forget.**

## Comparison

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Awake, lid closed, on battery | ✅ | ✅¹ | ❌ (refused) | ✅ | ⚠️ needs ext. display | ❌ |
| No external display needed | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| Battery-floor auto-off | ✅ | end-session on low batt | ✅ (but no lid-closed) | ❌ | ❌ | ❌ |
| Mechanism | `pmset disablesleep` + scoped sudoers | public API ≈ `disablesleep` + IOKit | `caffeinate` | `pmset disablesleep` + helper | `pmset` + sudoers | IOKit assertion |
| Open source | ✅ MIT | ❌ (App Store) | ✅ MIT | ✅ Apache-2.0 | ✅ GPL-3.0 | Apple built-in |
| Stars | new | App Store | ~6.6k | ~18 | ~101 | n/a |

<sub>¹ Amphetamine supports it but, on Apple Silicon, relies on a separately installed "Power
Protect" script and is widely reported to break on power connect/disconnect and KVM/dock
setups. Star counts pulled 2026-06-01 and drift over time. Every competitor claim is sourced
in the research notes; corrections welcome.</sub>

## Use cases

Each pairs with the battery-floor: set a floor you're comfortable with and walk away.

- **Let a long job finish after you leave.** An agent/Claude run, a render, a compile, ML
  training, a big `brew`/`npm` install: turn Sleepless on, close the lid, drop it in your bag,
  it keeps running.
- **Walk around sharing your hotspot.** Personal Hotspot / Internet Sharing from the Mac stays
  up with the lid shut.
- **Unattended transfers.** Large downloads, uploads, or a Time Machine / backup run that needs
  to complete while you step away.
- **Keep a server or SSH session reachable.** A local dev server, an SSH session, or a sync
  daemon stays alive lid-closed.
- **Keep audio going.** Music, a long cast, or an audio render keeps playing in the bag.

## Security model

Sleepless asks for a narrow slice of root, so here is exactly what it is. The full threat
model is in [SECURITY.md](SECURITY.md).

A GUI app has no terminal to type a password into, so `install.sh` writes a tightly scoped
`/etc/sudoers.d` drop-in (owned `root:wheel`, mode `0440`), with your username substituted in:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **It permits exactly two commands and nothing else.** sudoers matches arguments literally and
  this rule has no wildcards, so `sudo pmset -a sleep 0`, `pmset restoredefaults`, or any other
  vector falls through and demands a password. The grant can't be widened.
- **No shell, no helper script.** The app calls `sudo` with an argv array (no `/bin/sh -c`), and
  the rule points straight at Apple's `/usr/bin/pmset`. There is no user-writable script for an
  attacker to rewrite.
- **`disablesleep` is undocumented but real.** It isn't in `man pmset`, but it sets the kernel's
  `SleepDisabled` flag (`pmset -g | grep SleepDisabled`). Because it's undocumented, Apple could
  change it; Sleepless reads the value back after every toggle.
- **A reboot resets it to `0`.** It is a runtime flag, so there's no way to leave your Mac
  permanently unable to sleep. The battery floor is a second safety net.
- **Honest residual risk:** the grant is passwordless by design, so any process running as you
  could flip the flag. The worst case is "your Mac was kept awake, or allowed to sleep," not data
  loss or root code execution.
- **Clean uninstall.** `./uninstall.sh` removes the app, the login item, and the grant, then
  proves revocation by showing that `sudo -n pmset …` prompts for a password again.

## FAQ

**Does it really keep the Mac awake with the lid closed, on battery, with no display?**
Yes, that's the entire point. Verified on macOS 26 (Tahoe) / Apple Silicon.

**The moon doesn't show in my menu bar.** macOS 26 can hide menu-bar items. Check System
Settings (Control Center / Menu Bar settings) and make sure Sleepless is allowed to show its
item; the app is running if `pgrep -x Sleepless` prints a number.

**Why isn't it notarized?** It's a personal, open-source tool with no paid Apple Developer ID,
so it's ad-hoc signed. Build from source to skip Gatekeeper entirely, or use the **Open Anyway**
flow for the prebuilt app. Notarization is not a malware guarantee anyway.

**Will it drain my battery?** Only if you ignore the floor. While awake and discharging,
Sleepless turns off at the battery percentage you set (default 15%), and a reboot always
restores normal sleep.

**Does it work on Intel Macs or older macOS?** It's verified on **macOS 26 Apple Silicon**.
`disablesleep` is undocumented, so behavior on other versions/hardware isn't guaranteed. Try it
and let us know; honest reports are welcome.

**How do I remove it completely?** `./uninstall.sh` (or delete `/Applications/Sleepless.app`,
remove `/etc/sudoers.d/sleepless-disablesleep` with `sudo rm`, and `launchctl bootout` the
login item).

## Contributing

Issues and PRs welcome, especially translations and honest test reports from other
hardware/macOS versions. See [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). Sleepless stays deliberately small: features that grow
the privilege surface are unlikely to land.

## License

[MIT](LICENSE) © 2026 Adam Boudjemaa.

---

<p align="center">
  <sub>If Sleepless saved you a trip to Terminal, a ⭐ helps other people find it.</sub>
</p>
