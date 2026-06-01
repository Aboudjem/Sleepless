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
  (`Process.arguments` in `App.swift`), so there is no `/bin/sh -c`, no command
  substitution, and no word-splitting surface inside the app.
- There is **no helper script**. The classic sudoers footgun is a *user-writable* script
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
that flips the flag back to `0` while the Mac is awake and discharging, so a forgotten
"on" state can't drain the battery to empty.

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

## Completely removing the privilege

`./uninstall.sh` restores normal sleep, removes the app and login item, deletes the
sudoers drop-in, and then **proves** revocation by showing that `sudo -n pmset …` prompts
for a password again. The single file to audit or delete by hand is
`/etc/sudoers.d/sleepless-disablesleep`.

## Primary sources

- Apple `pmset(1)` man page (no `disablesleep`): https://keith.github.io/xcode-man-pages/pmset.1.html
- sudoers manual (exact-arg match, includedir filename rules): https://www.sudo.ws/docs/man/1.9.0/sudoers.man/
- Passwordless sudo for programs (scope / root-own / revoke): https://jozefcipa.com/blog/how-to-use-sudo-without-a-password-in-your-programs/
- Apple — Safely open apps / Open Anyway flow: https://support.apple.com/en-us/102445
- Apple Developer — Sequoia removes Control-click Gatekeeper bypass: https://developer.apple.com/news/?id=saqachfa
- Living without notarization (ad-hoc + quarantine behavior): https://eclecticlight.co/2024/10/01/living-without-notarization/
