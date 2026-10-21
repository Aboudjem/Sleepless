# Security Policy

Sleepless asks for a narrow piece of root privilege, so it owes you a precise account
of what that privilege is and why it is safe. This document is that account. Nothing
here is hand-waved; every claim is something you can verify on your own machine.

## Reporting a vulnerability

If you find a security issue, please **do not open a public issue**. Email
**boudjemaa.adam@gmail.com** with details and steps to reproduce. You'll get an
acknowledgement within a few days. Coordinated disclosure is appreciated.

Supported version: the latest release on the `main` branch.

## What Sleepless actually does

Sleepless keeps a Mac awake with the lid closed by toggling an undocumented but
long-standing `pmset` setting:

```
sudo pmset -a disablesleep 1   # keep awake, even lid-closed
sudo pmset -a disablesleep 0   # restore normal sleep
```

`disablesleep` is **not** in Apple's `pmset(1)` man page (check: `man pmset`), but it
sets the kernel's `SleepDisabled` flag, which you can observe yourself:

```
pmset -g | grep SleepDisabled   # 1 = on, 0/absent = off
```

Because it is undocumented, Apple could change or remove it in a future macOS. Sleepless
reads the live value back after every toggle, so the menu-bar state always reflects
reality rather than assuming the command worked.

## The passwordless grant — exactly what it permits

A GUI app has no terminal to type a password into, so Sleepless runs `pmset` through a
tightly scoped `/etc/sudoers.d` drop-in. `install.sh` writes this (with your username
substituted for `__USER__`), owned `root:wheel`, mode `0440`:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

**This grant lets one user run, as root, exactly two fully-specified commands and nothing
else.** sudoers matches command arguments *literally* — and this rule contains **no
wildcards** — so the match is total. From the sudoers manual: *"If a Cmnd has associated
command line arguments, then the arguments in the Cmnd must match exactly those given by
the user on the command line (or match the wildcards if there are any)."*

Consequences you can rely on:

- `sudo pmset -a sleep 0`, `sudo pmset restoredefaults`, `sudo pmset -a hibernatemode 0`,
  or any other argument vector **do not match** the rule and will demand a password. The
  grant cannot be widened by appending flags.
- Sleepless calls `sudo` with an **argv array**, not a shell string
  (`posix_spawn` in `MacSafetyEnvironment.swift`), so there is no `/bin/sh -c`, no command
  substitution, and no word-splitting surface inside the app.
- No user-writable helper is authorized to run as root. The classic sudoers footgun is a *user-writable* script
  that root executes — rewrite it, get root. Sleepless points the rule directly at Apple's
  `/usr/bin/pmset`, and the sudoers file itself is `root:wheel 0440` (you cannot modify it
  without `sudo`). Both mitigations are exactly what the literature prescribes.

## Honest residual risk

The grant is passwordless **by design**: any process already running as your user can flip
the sleep flag silently. We are not pretending the attack surface is zero. But the worst
case is *"your Mac was kept awake, or allowed to sleep."* It is **not** data exfiltration
and **not** root code execution — the two pinned arguments to one Apple binary do not
provide either.

If that trade is not acceptable to you, build from source and **don't** run `install.sh`;
you can toggle `sudo pmset -a disablesleep 1/0` manually instead and skip the grant.

## Reboot resets it (a safety net you can verify)

`disablesleep` is a **runtime** setting. A reboot restores normal sleep — there is no way
for Sleepless to leave your Mac permanently unable to sleep. Verify it yourself: toggle on,
reboot, then `pmset -g | grep SleepDisabled` should read `0`.

Sleepless adds a second belt-and-suspenders: a **battery-floor auto-off** (default 15%)
that flips the flag back to `0` while the Mac is awake and discharging, to reduce the risk of a forgotten ON state. These checks require usable sleep permissions and do not guarantee thermal or battery safety.

## Code signing, notarization, and Gatekeeper

Sleepless is **ad-hoc signed and not notarized** — it has no paid Apple Developer ID. The
trust model is *read the source, build it yourself*. (Notarization is also not a malware
guarantee: signed, notarized macOS stealers have shipped.)

- **Build from source (recommended):** locally compiled apps are **not quarantined**, so
  Gatekeeper does not prompt — it just runs.
- **Download the prebuilt `.app`:** a release zip carries `com.apple.quarantine`, so
  Gatekeeper blocks first launch. Approve it via **System Settings → Privacy & Security →
  Open Anyway**, then confirm. Note: macOS 15 (Sequoia) **removed** the old
  right-click → Open bypass, so the System Settings path is the supported flow on macOS 15+.

## Why Sleepless can't be on the Mac App Store

Some people trust App Store apps more, so it is worth saying plainly: Sleepless can never
ship there, and that is a property of what it does, not an oversight.

App Review **§2.4.5(v)** states apps "may not request escalation to root privileges or use
setuid attributes." The passwordless root `pmset` toggle is exactly that, so it is the
decisive block. Two more rules independently rule it out: **§2.4.5(i)** (apps must be
sandboxed, and the sandbox has no entitlement for root or arbitrary system-file writes) and
**§2.5.2 / §2.4.5(ii)** (apps must be self-contained in their bundle and may not write
outside their container, which the `/etc/sudoers.d` drop-in does). A privileged-helper
workaround does not rescue it either: a helper installed from a sandboxed app must itself be
sandboxed, so it still cannot write `/etc/sudoers.d` or run arbitrary root commands.

The practical consequence: Sleepless is **direct-download / Homebrew only**, by design. The
verification steps below, plus building from source, are how trust is established instead.

## Verifying a download

If you grab a prebuilt release instead of building it, you can confirm it is genuinely this
project's build, with no Apple account and no shared secret:

```sh
shasum -a 256 -c SHA256SUMS                                  # bytes match what was published
gh attestation verify Sleepless-<version>.zip -R Aboudjem/Sleepless   # built by this repo's release workflow
```

The full walkthrough (what each check proves, how to reproduce the build, and a VirusTotal
scan) is in **[docs/AUDIT.md](docs/AUDIT.md)**.

## Completely removing the privilege

`./uninstall.sh` fences new keep-awake requests, restores owned state and verifies normal sleep before removing the watchdog, app, login item and `/etc/sudoers.d/sleepless-disablesleep`. Failed restoration stops removal and retains recovery. It does not execute a sleep-changing command merely to test privilege revocation. Any broader sudo rights granted outside Sleepless remain outside its control.

## Primary sources

- Apple `pmset(1)` man page (no `disablesleep`): https://keith.github.io/xcode-man-pages/pmset.1.html
- sudoers manual (exact-arg match, includedir filename rules): https://www.sudo.ws/docs/man/1.9.0/sudoers.man/
- Passwordless sudo for programs (scope / root-own / revoke): https://jozefcipa.com/blog/how-to-use-sudo-without-a-password-in-your-programs/
- Apple — Safely open apps / Open Anyway flow: https://support.apple.com/en-us/102445
- Apple Developer — Sequoia removes Control-click Gatekeeper bypass: https://developer.apple.com/news/?id=saqachfa
- Living without notarization (ad-hoc + quarantine behavior): https://eclecticlight.co/2024/10/01/living-without-notarization/
- App Store Review Guidelines (§2.4.5 root escalation / sandbox / self-contained): https://developer.apple.com/app-store/review/guidelines/
- GitHub artifact attestations (build provenance, SLSA): https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds


## Ownership and independent recovery

The watchdog safety branch adds a 45-second, boot-scoped ownership lease and an independent per-user LaunchAgent. Missing permissions or watchdog health blocks arming. The helper refuses pre-existing unowned sleep prevention, serializes its own operations, checks OFF read-back and retains the recovery record on failed restoration. Upgrade/removal first fences new arms and verifies normal sleep; a failed clear must leave recovery and the grant intact.

This remains a global macOS Boolean: another tool writing ON during a Sleepless-owned session is indistinguishable from the existing ON value. Do not combine competing sleep-setting tools or concurrent logged-in keep-awake sessions. A user agent also does not provide recovery outside its login session. Revoked permission can prevent recovery entirely until repaired. There is no new privileged daemon or broad sudo permission; the agent uses the same two exact pmset commands. The native GUI authorization uses a fixed installer body, rather than executing user-writable bundled code as root.

See [WATCHDOG-SAFETY.md](docs/WATCHDOG-SAFETY.md) for the full safety boundary, supervised development tests, everyday-Mac acceptance and complete uninstall process. Live development-machine recovery tests passed with explicit approval; actual sleep was not demonstrated while essential Screen Sharing asserted PreventSystemSleep. A user also confirmed unplug and force-quit recovery on macOS 26.6.2; this does not prove actual physical sleep or all permission/hardware combinations. Passing mocked tests alone is not evidence of actual sleep recovery.
