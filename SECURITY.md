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

Sleepless first snapshots the affected Battery, AC, and optional UPS values,
then applies this fixed profile:

```sh
pmset -a disablesleep 1 sleep 0 disksleep 0 displaysleep 10 \
  powernap 0 tcpkeepalive 1 womp 1
```

The app also owns a `caffeinate -ims` process. It binds that process to the
Sleepless PID, so its assertions disappear if the app exits.

On OFF, the helper restores only those whitelisted keys, using `pmset -b`,
`pmset -c`, and `pmset -u` so distinct power-source values are preserved. The
snapshot is deleted only after every restored value and `SleepDisabled` verify.

## The passwordless grant — exactly what it permits

A GUI app has no terminal to type a password into. `install.sh` therefore copies
`powerctl.sh` to the fixed path below as `root:wheel 0755`, then installs a
`root:wheel 0440` sudoers drop-in:

```text
<you> ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl on, /Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl off
```

**This grant lets one user run, as root, exactly two fully-specified commands and nothing
else.** sudoers matches command arguments *literally* — and this rule contains **no
wildcards** — so the match is total. From the sudoers manual: *"If a Cmnd has associated
command line arguments, then the arguments in the Cmnd must match exactly those given by
the user on the command line (or match the wildcards if there are any)."*

Consequences you can rely on:

- Direct `sudo pmset ...`, helper arguments other than exact `on` or `off`, and
  appended arguments **do not match** the rule.
- Sleepless calls `sudo` with an **argv array**, not a shell string
  (`Process.arguments` in `App.swift`), so there is no `/bin/sh -c`, no command
  substitution, and no word-splitting surface inside the app.
- The installed helper is **not user-writable**. It has fixed paths, a fixed
  `PATH`, a fixed whitelist of keys, integer-only snapshot values, and no
  caller-provided setting names, values, or file paths.
- The snapshot lives at `/var/db/com.aboudjem.Sleepless/power-state`. Its directory
  is root-owned; the file is readable so the unprivileged app can report managed
  state, but it cannot be modified by the user.

## Honest residual risk

The grant is passwordless **by design**: any process already running as your
user can request the fixed awake profile or restore the stored snapshot. The
helper is a larger attack surface than the upstream project's two direct
`pmset` commands, which is why it is root-owned and accepts only fixed actions.
It never executes snapshot text or caller-controlled commands.

If that trade is not acceptable, do not run `install.sh`.

## Crash and reboot recovery

The snapshot persists until a verified OFF. Normal app termination restores it,
and the app-owned `caffeinate` exits automatically with Sleepless. If the app
crashes, relaunching it recovers the managed state. After a reboot,
`SleepDisabled` resets; Sleepless treats an existing snapshot plus a cleared
flag as stale and restores the saved profile instead of re-arming.

Sleepless adds a second belt-and-suspenders: a **battery-floor auto-off** (default 15%)
that invokes the same verified restore while the Mac is awake and discharging.

If Sleepless does not launch after an abnormal shutdown, run:

```sh
sudo /Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl off
```

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
gh attestation verify Sleepless-<version>.zip -R Aboudjem/Sleepless
```

The full walkthrough (what each check proves, how to reproduce the build, and a VirusTotal
scan) is in **[docs/AUDIT.md](docs/AUDIT.md)**.

## Completely removing the privilege

`./uninstall.sh` first requires a successful snapshot restore, then removes the
app, login item, root-owned helper, state directory, and sudoers drop-in. The
privileged files to audit are:

- `/Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl`
- `/etc/sudoers.d/sleepless-powerctl`
- `/var/db/com.aboudjem.Sleepless/power-state` while ON

## Primary sources

- Apple `pmset(1)` man page (no `disablesleep`): https://keith.github.io/xcode-man-pages/pmset.1.html
- sudoers manual (exact-arg match, includedir filename rules): https://www.sudo.ws/docs/man/1.9.0/sudoers.man/
- Passwordless sudo for programs (scope / root-own / revoke): https://jozefcipa.com/blog/how-to-use-sudo-without-a-password-in-your-programs/
- Apple — Safely open apps / Open Anyway flow: https://support.apple.com/en-us/102445
- Apple Developer — Sequoia removes Control-click Gatekeeper bypass: https://developer.apple.com/news/?id=saqachfa
- Living without notarization (ad-hoc + quarantine behavior): https://eclecticlight.co/2024/10/01/living-without-notarization/
- App Store Review Guidelines (§2.4.5 root escalation / sandbox / self-contained): https://developer.apple.com/app-store/review/guidelines/
- GitHub artifact attestations (build provenance, SLSA): https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds
