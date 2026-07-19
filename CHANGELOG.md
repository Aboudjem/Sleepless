# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Menu-bar icon no longer disappears after a while on macOS 26. The status item is
  now created with a fixed square slot, a saved `autosaveName`, and explicit
  `isVisible = true`, and it is recreated automatically if the backing button ever
  becomes nil. The state-change pulse animation also avoids mutating the status-button
  layer, which could destabilize the item on newer macOS.

## [1.2.7] - 2026-06-03

### Changed
- Redesigned the menu-bar icon so the three states are unmistakable at a glance. It
  stays a monochrome template icon (adapts to light/dark menu bars and inverts on
  highlight, the macOS convention), but now changes shape instead of just filling in:
  an empty cup resting on its saucer when off, a hot **steaming** cup when keeping the
  Mac awake, and the steaming cup with a small dot when awake on battery (the auto-off
  safety net is live). The previous empty-vs-filled cups looked nearly identical at
  menu-bar size, so the state change was easy to miss.

## [1.2.6] - 2026-06-03

### Fixed
- The switch could still show a password prompt or look like it "wouldn't stay on" in
  edge cases, because the app judged success by re-reading the sleep state with a second
  `pmset` call right after toggling, rather than trusting whether the privileged command
  actually ran. If anything flipped sleep back off between those two steps (a safety net
  firing, or a momentary empty read), the app mistook it for a missing permission and
  re-prompted. Sleepless now decides purely from `sudo`'s own exit status: a successful
  toggle never re-prompts, and the one-time setup is offered only when `sudo` genuinely
  reports the passwordless grant is missing. A safety-net turn-off is never confused with
  a permission problem.

### Changed
- The privileged toggle now captures its real exit status and stderr (previously
  discarded) and runs with its input detached from any terminal, so a GUI launch can
  never stall on a prompt and the app always knows whether the toggle worked.

## [1.2.5] - 2026-06-02

### Fixed
- In Low Power Mode the switch would not stay on and the password prompt kept
  reappearing. Cause: the Low Power Mode safety net turned it back off, and the app
  misread that off-state as a missing permission and re-prompted. The app now checks
  the toggle's immediate result (before any safety net) to decide if setup is needed,
  so a safety-net turn-off never triggers a setup prompt.

### Changed
- A deliberate turn-on now overrides the Low Power Mode auto-off for that session, so
  the switch stays on when you explicitly ask for it. The hard battery floor (default
  15%) still always cuts in to protect against draining the Mac flat.

## [1.2.4] - 2026-06-02

### Fixed
- The switch kept asking for the password even after the permission was correctly
  installed. The app pre-checked the grant with `sudo -l`, but listing sudo privileges
  itself needs authentication even when a NOPASSWD rule is present, so the check always
  read "not installed" and re-prompted. The app no longer pre-checks: it just toggles,
  and only offers the one-time setup if the toggle genuinely doesn't engage.

## [1.2.3] - 2026-06-02

### Fixed
- The one-time setup installed the grant for the wrong user. Under the native auth
  sheet, grant.sh runs as root with `SUDO_USER` unset, so it wrote the rule for `root`
  instead of the real user, which meant the switch never engaged and kept re-asking for
  the password. The app now passes the real user, and grant.sh refuses to write a
  root-owned grant (falling back to the console user). Re-toggling overwrites the bad
  rule automatically.

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

[Unreleased]: https://github.com/Aboudjem/Sleepless/compare/v1.2.5...HEAD
[1.2.5]: https://github.com/Aboudjem/Sleepless/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/Aboudjem/Sleepless/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/Aboudjem/Sleepless/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/Aboudjem/Sleepless/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/Aboudjem/Sleepless/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Aboudjem/Sleepless/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Aboudjem/Sleepless/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Aboudjem/Sleepless/releases/tag/v1.0.0
