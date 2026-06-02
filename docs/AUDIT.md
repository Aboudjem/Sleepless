# Audit & verify Sleepless

Sleepless asks for a narrow slice of root, so it should be easy to check, not taken on
faith. This page is the practical companion to [SECURITY.md](../SECURITY.md): the latter
explains *why* the design is safe, this one shows you *how to confirm it yourself* and how
to verify a download you did not build.

There is no Apple account behind any of this. Every check below is free and runs on your
machine.

## Read it in about ten minutes

The whole app is one file. To satisfy yourself it does what it claims and nothing else:

| Read | What you are checking |
|---|---|
| [`App.swift`](../App.swift) | The only thing it runs as root is `sudo -n /usr/bin/pmset -a disablesleep 0/1` (`setDisableSleep`). No network calls, no file writes outside `UserDefaults`, no shell strings. |
| [`sleepless.sudoers.template`](../sleepless.sudoers.template) / [`grant.sh`](../grant.sh) | The passwordless grant permits exactly those two fully-specified commands, no wildcards, installed `root:wheel 0440`. |
| [`build.sh`](../build.sh) | `swiftc` + a hand-assembled, ad-hoc-signed bundle. No downloaded blobs, no install-time scripts baked into the binary. |
| [`uninstall.sh`](../uninstall.sh) | Removes the app, the login item, and the sudoers drop-in, then proves `sudo -n pmset …` prompts again. |

The single privileged file on your system is `/etc/sudoers.d/sleepless-disablesleep`. Read
it, and `sudo rm` it any time to revoke everything.

## Verify a release you downloaded (did not build)

Release zips are built on a GitHub-hosted runner, checksummed, and signed with a Sigstore
build-provenance attestation. Two checks, both offline-friendly:

```sh
# 1. Integrity: the bytes match what the release published.
shasum -a 256 -c SHA256SUMS

# 2. Provenance: this exact zip was built by Sleepless's GitHub Actions release
#    workflow, from this repo, at the released commit (SLSA Build L2, Sigstore-signed).
gh attestation verify Sleepless-<version>.app.zip -R Aboudjem/Sleepless
```

What each one proves:

- **`shasum -c`** proves the file was not altered after publishing. It says nothing about
  *who* built it, so it is necessary but not sufficient on its own.
- **`gh attestation verify`** proves the file came out of this project's release workflow
  (a specific repository + commit + workflow), cryptographically, with no shared secret to
  leak. This is the strong link from "the source you can read" to "the binary you ran." It
  needs the GitHub CLI (`brew install gh`); the attestation itself lives in this repo and on
  the public Sigstore transparency log.

Neither check is Gatekeeper. macOS still treats the prebuilt app as unnotarized (see
[SECURITY.md](../SECURITY.md#code-signing-notarization-and-gatekeeper)). The point of these
two is supply-chain trust: that the download is the thing this repository built.

## Reproduce the build

The compile is deterministic for a given toolchain, so you can rebuild and compare the
**unsigned executable** byte for byte:

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless && git checkout v<version>

# Rebuild the executable with the release's deployment target.
swiftc -O -parse-as-library -target arm64-apple-macos13.0 \
  -framework AppKit -framework ServiceManagement App.swift -o /tmp/Sleepless-rebuilt

# Unzip the release and compare the Mach-O inside the bundle.
ditto -x -k Sleepless-<version>.app.zip /tmp/rel
shasum -a 256 /tmp/Sleepless-rebuilt /tmp/rel/Sleepless.app/Contents/MacOS/Sleepless
```

Caveats, stated honestly:

- The two hashes match **only with the same Swift/Command Line Tools version** used by the
  release runner (`macos-latest`). A different compiler version will produce a different,
  still-correct binary. The release job prints its toolchain in the **Toolchain** step so you
  can match it.
- The **signed** `.app` is only *likely* reproducible: ad-hoc code signatures embed
  non-deterministic data, so compare the unsigned Mach-O above, not the signed bundle. See
  the [Reproducible Builds definition](https://reproducible-builds.org/docs/definition/).

For most people the attestation is the easier and stronger guarantee; reproducing the build
is the deepest check if you want it.

## Scan it with VirusTotal

You can upload the release zip to [VirusTotal](https://www.virustotal.com) (free,
non-commercial, results public) for a multi-engine scan:

```sh
# With a free VirusTotal API key:
curl -s --request POST --url https://www.virustotal.com/api/v3/files \
  --header "x-apikey: $VT_API_KEY" \
  --form file=@Sleepless-<version>.app.zip
# …then open the returned analysis URL, or just drag the zip onto virustotal.com.
```

Note: ad-hoc-signed, unnotarized binaries draw more *heuristic* flags than notarized ones, so
read any detection in context. A clean result is reassuring, not absolute; pair it with the
attestation above.

<!-- VirusTotal permalink for the v1.1.0 release: PENDING — add the public analysis URL here
     after uploading the release zip. -->

**Public VirusTotal report:** _to be added once the v1.1.0 zip is uploaded._

## Notarization (planned, not yet done)

Sleepless is ad-hoc signed and **not notarized** today, because notarization needs a paid
Apple Developer ID. It is on the roadmap. The exact steps, for transparency and so anyone can
do it from a fork, are:

```sh
# One-time: store an app-specific password for notarytool.
xcrun notarytool store-credentials "notarytool-password" \
  --apple-id "<apple-id>" --team-id <TeamID> --password <app-specific-password>

# Re-sign with a Developer ID cert + hardened runtime + secure timestamp.
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <Name> (<TeamID>)" Sleepless.app

ditto -c -k --keepParent Sleepless.app Sleepless.zip
xcrun notarytool submit Sleepless.zip --keychain-profile "notarytool-password" --wait
xcrun stapler staple Sleepless.app
```

Prerequisite: [Apple Developer Program, $99/yr](https://developer.apple.com/programs/whats-included/),
and a "Developer ID Application" certificate. Notarization removes the
"Apple could not verify this app" first-launch block; it does not change anything about how
the app works. The `/etc/sudoers.d` install step is what makes Sleepless ineligible for the
Mac App **Store**, but it does not block notarized *direct* distribution (notarization is an
automated malware scan, not a behavioral policy review).
