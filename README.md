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
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Keep your MacBook awake with the lid closed, on battery, with no external display.</b><br>
  <sub>One menu-bar switch, with an auto-off timer and a battery-floor cutoff so you never drain it flat.</sub>
</p>

<p align="center">
  <a href="https://github.com/Aboudjem/Sleepless/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Aboudjem/Sleepless/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white&style=flat-square&color=8B5CF6"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aboudjem/Sleepless?label=release&logo=apple&logoColor=white&style=flat-square&color=8B5CF6"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aboudjem/Sleepless/total?label=downloads&style=flat-square&color=6366F1"></a>
  <a href="https://github.com/Aboudjem/Sleepless/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Aboudjem/Sleepless?style=flat-square&color=6366F1"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-D946EF?style=flat-square"></a>
  <img alt="Platform: macOS 26, Apple Silicon" src="https://img.shields.io/badge/macOS%2026-Apple%20Silicon-8B5CF6?style=flat-square&logo=apple&logoColor=white">
</p>
<p align="center">
  <img alt="Build provenance: attested (SLSA)" src="https://img.shields.io/badge/build%20provenance-attested-8B5CF6?style=flat-square&logo=githubactions&logoColor=white">
  <img alt="Checksums: SHA-256" src="https://img.shields.io/badge/checksums-SHA--256-6366F1?style=flat-square">
  <img alt="Telemetry: none" src="https://img.shields.io/badge/telemetry-none-D946EF?style=flat-square">
  <a href="https://github.com/Aboudjem/homebrew-tap"><img alt="Install: Homebrew cask" src="https://img.shields.io/badge/homebrew-cask-8B5CF6?style=flat-square&logo=homebrew&logoColor=white"></a>
</p>

<p align="center">
  <img alt="Sleepless demo: flip the switch, set an auto-off timer, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

> [!NOTE]
> Sleepless combines `pmset disablesleep` with a fixed awake profile and an app-owned `caffeinate` assertion. It snapshots the affected settings first, then restores and verifies them on OFF.

## Install

```sh
brew install --cask aboudjem/tap/sleepless
/Applications/Sleepless.app/Contents/Resources/grant.sh   # one-time passwordless grant
```

| Other ways | |
|---|---|
| **Download** | Grab the [latest release](https://github.com/Aboudjem/Sleepless/releases/latest), unzip to `/Applications`, then approve it in **System Settings → Privacy & Security → Open Anyway** (it is ad-hoc signed). |
| **Build from source** | `git clone https://github.com/Aboudjem/Sleepless.git && cd Sleepless && ./install.sh` (no Gatekeeper prompt). |

Then click the cup in the menu bar, flip the switch, and close the lid.

## Features

| | | |
|---|---|---|
| ☕ | **One switch** | Click the menu-bar cup, flip the toggle. |
| ↩️ | **Exact restore** | Saves the current Battery/AC values before ON and verifies them after OFF. |
| 🧰 | **Full awake profile** | Uses `disablesleep` plus fixed sleep, disk, network, and `caffeinate -ims` settings. |
| ⏲️ | **Auto-off timer** | 1h or 2h with a live countdown, then off. |
| 🔋 | **Battery floor** | Auto-off at 5–50% on battery (default 15%). |
| 🪫 | **Low Power Mode** | Steps aside when LPM is on, on battery. |
| 🖥️ | **No dongle** | Lid closed, on battery. No monitor, no HDMI plug. |
| 🚀 | **Launch at login** | Optional, off by default, always starts idle. |
| 🪶 | **Tiny + native** | Menu-bar AppKit app. No Dock icon, daemon, or kext. |

**Menu-bar glyph:** empty cup = off · full cup = awake · full cup + dot = awake on battery (auto-off live).

## Sleepless vs the alternatives

| | **Sleepless** | Amphetamine | KeepingYouAwake | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| Awake, lid closed, no monitor | ✅ ¹ | ⚠️ ² | ❌ ³ | ❌ |
| On battery | ✅ | ✅ | ✅ lid open | ⚠️ ⁴ |
| Auto-off timer | ✅ | ✅ | ✅ | ❌ |
| Auto-off on low battery | ✅ | ✅ | ✅ | ❌ |
| Open source | ✅ MIT | ❌ App Store | ✅ MIT | Apple |
| Cost | Free | Free | Free | Free |

<sub>As of 2026-07. ¹ Uses `pmset disablesleep`, a full awake profile, and app-owned `caffeinate -ims`; behavior remains hardware/macOS-version dependent. ² Documents closed-display mode but is widely reported to fail on Apple Silicon on power-source changes ([AE #28](https://github.com/x74353/Amphetamine-Enhancer/issues/28)); the app is closed source. ³ Can't do lid-closed by design, it wraps `caffeinate` ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). ⁴ `caffeinate -i` runs on battery; `-s` is AC-only.</sub>

## Use it to

- 🤖 Finish overnight jobs lid-closed: agent runs, builds, renders, ML training.
- 📡 Share a hotspot from your bag.
- ⬇️ Leave big downloads, uploads, or backups running.
- 🖥️ Keep a local server or SSH session reachable.

> [!TIP]
> Set a battery floor you trust (say 20%) plus a timer, and you can walk away without babysitting the battery.

## How it works

When switched ON, Sleepless snapshots the affected Battery, AC, and optional UPS values, then applies:

```sh
pmset -a disablesleep 1 sleep 0 disksleep 0 displaysleep 10 \
  powernap 0 tcpkeepalive 1 womp 1
caffeinate -ims
```

The profile deliberately omits `caffeinate -d`, so the display may still turn off normally. When switched OFF, it restores each saved value with the correct `pmset -b`, `-c`, or `-u` source flag. The snapshot is deleted only after verification succeeds.

The installer copies a fixed helper to `/Library/PrivilegedHelperTools`, owned by `root:wheel`, and grants exactly:

```text
<you> ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl on, /Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl off
```

- **Fixed inputs.** The helper accepts no setting names or values from the caller.
- **Exact restoration.** Failed restoration keeps the snapshot so it can be retried.
- **No broad process kill.** Sleepless stops only the `caffeinate` process it owns.

Full threat model: [SECURITY.md](SECURITY.md).

## FAQ

<details>
<summary><b>Why use more than <code>pmset disablesleep 1</code>?</b></summary>

`disablesleep` sets the undocumented kernel flag needed for the lid-close path, but one flag is not an end-to-end guarantee for every long-running process. Sleepless also disables the affected idle timers, preserves the network-oriented settings, and owns a `caffeinate -ims` assertion. It verifies the complete profile after applying it.
</details>

<details>
<summary><b>Why does my Mac sleep on lid close even with Amphetamine or KeepingYouAwake?</b></summary>

Those tools use macOS power assertions, which stop idle sleep but do not cover the lid-close trigger. KeepingYouAwake wraps `caffeinate`, which does not support lid-close by itself ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). Sleepless combines `disablesleep` for that path with its own assertions and fixed profile.
</details>

<details>
<summary><b>Is it safe? Will it overheat or drain the battery?</b></summary>

Light unattended work such as downloads, syncs, and agent jobs is the intended use. Heavy sustained load with the lid fully shut can reduce cooling headroom, so monitor temperature and use judgement. The battery floor, Low Power Mode auto-off, and timer reduce battery risk; they are not a thermal guarantee.
</details>

<details>
<summary><b>Does it need sudo, a kernel extension, or a daemon?</b></summary>

One tightly scoped `sudo` grant for the root-owned helper's exact `on` and `off` commands. No kernel extension or daemon.
</details>

<details>
<summary><b>How do I stop it or remove it?</b></summary>

Flip the switch off, or let the timer or battery floor do it. Sleepless restores and verifies the captured profile. `./uninstall.sh` restores first, then removes the app, helper, login item, and sudoers grant.
</details>

<details>
<summary><b>Why isn't it notarized?</b></summary>

It is a personal open-source tool with no paid Apple Developer ID, so it is ad-hoc signed. Build from source to skip Gatekeeper, or use **Open Anyway** for the prebuilt app. The notarization steps are documented in [docs/AUDIT.md](docs/AUDIT.md).
</details>

## Contributing

Issues and PRs welcome, especially translations and reports from other hardware. See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Sleepless stays deliberately small.

## License

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>If Sleepless saved you a trip to Terminal, a ⭐ helps other people find it.</sub>
</p>
