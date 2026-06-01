# Contributing to Sleepless

Thanks for your interest. Sleepless is a deliberately tiny, single-purpose menu-bar app,
so the bar for changes is "does it keep the thing small, honest, and native?"

## Ways to help

- **Report a bug** — use the bug-report issue form. Include your exact macOS version
  (`sw_vers`), your Mac model (`sysctl -n hw.model`), and what `pmset -g | grep SleepDisabled`
  reports before/after the problem.
- **Request a feature** — use the feature-request form. Features that grow the privilege
  surface (more sudo, a helper daemon, kexts) are unlikely to land; the security model is a
  core feature, not an obstacle.
- **Improve docs / translations** — README fixes and new/updated `README.<lang>.md` files
  are very welcome. Keep section order identical to the English README; never translate code
  blocks, URLs, or image paths.
- **Code** — bug fixes and small, focused improvements.

## Building locally

No Xcode project — just the Command Line Tools:

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./build.sh            # builds ./build/Sleepless.app, ad-hoc signed
open build/Sleepless.app
```

`./install.sh` additionally installs the passwordless grant + login item (it prints exactly
what it writes). `./uninstall.sh` backs it all out and proves the grant is revoked.

## Coding guidelines

- **Keep it native.** Sleepless uses AppKit + SF Symbols. No third-party dependencies, no
  hand-drawn glyphs, no bundled frameworks.
- **Zero warnings.** The build must compile clean:
  ```sh
  swiftc -O -parse-as-library -target arm64-apple-macos26.0 -framework AppKit App.swift -o /tmp/Sleepless
  ```
  CI runs the equivalent compile on every push/PR.
- **Match the surrounding style.** Read `App.swift` first — keep comment density, naming, and
  the "read back the real system state, never assume" discipline.
- **No personal paths or usernames** in scripts, the sudoers template, or install commands.
  The grant is generated from `$(id -un)` at install time.
- **Verify on a real machine.** Sleepless is verified on macOS 26 (Tahoe) / Apple Silicon.
  If you test on other versions/hardware, say so in the PR.

## Pull requests

1. Fork, branch from `main`.
2. Keep the diff focused; one logical change per PR.
3. Make sure the build is clean and the app launches.
4. Fill in the PR template (what changed, how you tested, macOS version).

By contributing you agree your work is licensed under the [MIT License](LICENSE).
Please also read the [Code of Conduct](CODE_OF_CONDUCT.md).
