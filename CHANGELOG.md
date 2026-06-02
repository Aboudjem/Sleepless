# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.2] - 2026-06-02

### Changed
- Setting up the one-time permission no longer means running anything in Terminal.
  The first time you flip the switch on, Sleepless installs the scoped grant itself
  through a single native macOS authentication sheet (Touch ID or your password).
  After that the toggle works instantly and never asks again. (Changing a protected
  macOS setting requires one authorization; that is a system rule, but it is now one
  in-app tap instead of a command.)

## [1.2.1] - 2026-06-02

### Fixed
- The keep-awake switch no longer snaps back with no explanation when the one-time
  passwordless grant is missing. If turning it on cannot engage `disablesleep`,
  Sleepless now shows a short alert that names the cause and offers to copy the
  `grant.sh` command or open Terminal, so the toggle is never a silent dead end.

### Added
- A brief pulse on the menu-bar cup whenever the state changes, so the empty-cup to
  full-cup transition is easy to notice.

## [1.2.0] - 2026-06-02

### Changed
- New look. Sleepless now wears a vibrant 2026 "Liquid Glass" design in an indigo,
  violet, and fuchsia palette, across the app icon, the menu-bar popover, the landing
  page, and all brand art. The coffee-cup metaphor and the three menu-bar states stay
  exactly the same.
- The popover keeps the native system material and adds a single violet accent that
  marks the kept-awake state at a glance, so color now communicates the privileged
  state rather than only decorating the panel.
- The app icon moves from the espresso plate to an indigo-violet-fuchsia glass plate
  with the same white cup, plus a soft steam wisp at larger sizes.

### Added
- A richer badge row and a security and version trust strip (build-provenance
  attestation, SHA-256 checksums, no telemetry, MIT, CI, platform) on the landing page
  and across all six READMEs.

### Unchanged
- Same single AppKit file, no daemon, no kernel extension, no Dock icon. `disablesleep`
  still resets on reboot, the scoped `/etc/sudoers.d` grant is identical, and every
  verified fact, FAQ answer, and comparison result is unchanged. Only the visual layer
  and the badges moved.

## [1.1.0] - 2026-06-02

### Added
- Auto-off timer. Keep the Mac awake for 1 hour or 2 hours with a live countdown,
  then Sleepless turns itself back off. The timer is in-memory only, so quitting or
  rebooting clears it.
- Launch at login, off by default. The app always starts in the off state and never
  re-enables sleep prevention on its own, so "a reboot resets it" still holds.
- Low Power Mode auto-off. On battery, if Low Power Mode is on, Sleepless turns itself
  off, the same safety shape as the battery floor.

### Changed
- New coffee-cup icon. The menu-bar glyph and the app icon are now a coffee cup
  instead of a moon: an empty cup means normal sleep, a full cup means kept awake, and
  a full cup with a small dot means awake on battery with the auto-off net live. The old
  moon read backwards, since a moon signals sleep but the app prevents it.
- Wider popover that groups the switch, the auto-off timer, the battery floor, and the
  launch-at-login toggle, with the state caption noting both auto-off conditions.

### Unchanged
- Still one AppKit file, no daemon, no kernel extension, no Dock icon. `disablesleep`
  still resets on reboot, and the tightly scoped `/etc/sudoers.d` grant is the same.

## [1.0.0] - 2026-06-01

### Added
- Menu-bar toggle that keeps a Mac awake with the lid closed, on battery, with no
  external display, via the undocumented `pmset disablesleep` setting.
- Passwordless toggling through a tightly scoped `/etc/sudoers.d` grant limited to the
  two exact `pmset -a disablesleep 0|1` commands, generated from `$(id -un)` at install.
- Battery-floor auto-off (adjustable 5–50%, default 15%) that turns Sleepless off while
  awake and discharging, so a forgotten "on" state can't drain the battery.
- Native SF Symbol menu-bar glyph in three states: `moon` (off), `moon.fill` (on),
  `moon.stars.fill` (armed: awake on battery, auto-off live).
- Frosted-glass `NSPopover` with a native `NSSwitch` and a draggable battery-floor slider.
- Live state read-back after every toggle, so the UI reflects reality rather than assuming.
- `build.sh` (Command Line Tools only, ad-hoc signed), `install.sh` (transparent grant +
  login item), and `uninstall.sh` (removes the grant and proves revocation).
- README in 6 languages (English, 简体中文, Español, 日本語, Français, Deutsch).
- MIT license, security model (`SECURITY.md`), and community-health files.

[Unreleased]: https://github.com/Aboudjem/Sleepless/compare/v1.2.2...HEAD
[1.2.2]: https://github.com/Aboudjem/Sleepless/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/Aboudjem/Sleepless/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Aboudjem/Sleepless/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Aboudjem/Sleepless/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Aboudjem/Sleepless/releases/tag/v1.0.0
