# Sleep recovery and deployment

This branch retains the native menu-bar app, existing timer, battery floor, Low Power Mode behavior, login switch, downloaded `.app` bundle and Homebrew/source build model. It addresses [upstream issue #8](https://github.com/Aboudjem/Sleepless/issues/8). It adapts the lease/watchdog idea from [mmavko/Sleepless](https://github.com/mmavko/Sleepless/tree/e06a994148d0f35b2096dc3893a9dd171a74dbc0), rather than importing that fork's CLI, activity tracking, thermal recording or UI redesign.

## Behavior and ownership

- **Turn off when unplugged** is a persistent, default-on setting in the existing popover. An IOKit notification observes the transition from AC to battery/UPS and immediately requests restoration of Sleepless-owned state. Reconnecting power never arms keep-awake. Starting on battery remains supported; an unknown power snapshot is not interpreted as a disconnection.
- Before enabling keep-awake, Sleepless requires native power monitoring, explicit passwordless authorization for **both** exact `pmset` commands, a loaded watchdog and a successful watchdog heartbeat within 25 seconds. Cached sudo authentication alone is insufficient. Failed setup leaves keep-awake off.
- A separate, unprivileged `SleeplessSafety` executable performs all flag mutations under a kernel file lock. It records a UUID session owner, boot identity and 45-second monotonic deadline before enabling the flag. The GUI renews every 10 seconds; it cannot resurrect an expired/stopping lease or extend it to an arbitrary long deadline.
- A per-user LaunchAgent runs the independently copied helper every 10 seconds. It clears **only recorded Sleepless-owned state** after lease expiry or a pending stop, and never enables keep-awake. After an ordinary crash, recovery is nominally within roughly a minute of the last renewal; launchd scheduling, OS stalls and permissions mean this is not a guaranteed deadline.
- Normal quit restores owned state directly. If restoration fails, an ordinary quit is cancelled and the app retries. Crash/force-quit recovery does not depend on a termination callback.
- A failed OFF command or failed read-back retains the ownership record and stops renewal. The app and watchdog retry. Permission revocation can prevent *all* automated clearing until the grant is repaired; the app does not claim that sleep was restored.
- A pre-existing external flag is shown and left alone. Another app session cannot adopt, renew or release the current session's lease. External OFF is respected without re-arming.

**Global-setting limitation:** macOS exposes a global Boolean, not an ownership token or compare-and-set API. Sleepless cannot detect another tool writing ON while its own ON is already in effect, nor an OFF/ON sequence between observations. Its lock coordinates Sleepless instances, not arbitrary external programs or other logged-in users. Do not operate competing `disablesleep` tools or fast-user-switching keep-awake sessions concurrently. This limitation prevents an absolute guarantee of third-party ownership preservation; initial external state and observed external OFF are protected. Actual hardware sleep behavior is also undocumented and must be tested per machine.

## Installation, upgrade and removal

The downloaded app uses native authorization sheets for setup. Source installation and complete removal are operator commands.

### Downloaded app / everyday deployment

1. Use the candidate zip built from this branch; the existing public Homebrew release does **not** include these changes until published. Copy `Sleepless.app` to Applications and open it normally.
2. The first deliberate ON retains the native one-time authorization sheet. Only the two exact sleep commands are granted. The GUI installs its per-user watchdog without root privileges and refuses ON until the agent has actually checked in.
3. The agent's executable is copied into `~/Library/Application Support/Sleepless/Safety`, rather than depending on the app remaining at a particular path. macOS background-item permission must remain enabled. The old app being replaced must be quit through Sleepless; if quit fails, stop the upgrade and repair recovery first.
4. The source installer builds into `build/`, fences old arms/renewals, restores and verifies owned state, then upgrades `/Applications/Sleepless.app`, installs the scoped grant and refreshes the watchdog. It migrates the old script login item; the app's existing native Launch at login switch remains optional. Nothing auto-arms after installation or upgrade.
5. A bundle replacement is reconciled on the next deliberate ON. Changed watchdog code is replaced only after successful restoration under the transaction lock. Old health evidence is deleted; the new agent must check in before arming.

### Complete removal

Installation and removal use native macOS authorization sheets for grant changes, without a Terminal password prompt. Source installation only requests Quit if a matching process is actually running, so a missing application does not break clean installation.

The operator runs the bundled `Contents/Resources/uninstall.sh` (also available at repository root). It fences new operations, restores **owned** state, verifies normal sleep, quits the app, verifies again before removing the agent, and only then removes the grant and app. Failure to restore stops removal and leaves recovery intact. External unowned ON blocks removal rather than clearing the other owner's state.

The stable transaction-lock inode, maintenance marker and diagnostic log are deliberately retained under `~/Library/Application Support/Sleepless/Safety`; they contain no active lease or executable after successful removal. The marker prevents an old running copy from re-arming. Successful reinstall clears it. UserDefaults are retained. The operator can remove these inert leftovers after verifying that all Sleepless copies have exited; deleting the lock during an active session would break serialization.

Deleting only the app, including an external Homebrew cask's existing `quit`/bundle deletion, is **not complete removal** of the grant or agent. The independent copy still expires an owned lease after app deletion. The Homebrew tap lives outside this repository: before publishing, its uninstall action should invoke the bundled uninstaller as the logged-in user **before** bundle deletion. Do not run the helper or whole uninstaller as root; only the grant operations need elevation. The helper explicitly rejects root invocation. Packaging remains the original `.app`/zip format; no release or tap update has been published by this implementation.

## Automated verification

`tests/run.sh` builds the tests, exercises the shared safety engine, and runs read-only native checks. It never installs a watchdog/grant or changes the real sleep flag. Headless CI and release workflows use `tests/run.sh --unit-only`; native IOKit notification registration requires the desktop environment and is tested separately on the development Mac.

Five isolated lifecycle-script integration scenarios cover clean install with an absent app, upgrade, failed restoration before install, clean removal, and failed restoration before removal. Their OS boundaries are replaced by temporary fixtures; no privileges or host changes are used.

Coverage includes power removal/return/opt-out; clean exit; missing watcher/permissions; failed reads/writes and partially successful enables; failed clears and retries; lifecycle fences; external ownership and OFF; reboot identity; expiry/horizon validation; canonical file validation; actual concurrent processes; expiry/renewal races; actual SIGKILL during simulated flag enable; lock recovery after process death; and verification of simulated normal sleep at each failure cleanup. The subprocess tests use the same kernel lock, ownership serializer and engine as production, with the OS sleep boundary replaced by temporary files. Native checks read the real flag before/after, register/remove the IOKit source and test command failure/timeout handling. They do not simulate a physical unplug or prove actual sleep.

Build with `build.sh`; warnings are errors and both executable signatures are verified. The build sets `LSMinimumSystemVersion` from `TARGET` so the release-compatible macOS 13 target does not accidentally retain the local macOS 26 minimum.

## Live development-Mac test plan — approval required

Before starting, confirm the observed host is the intended **development** Mac. Obtain explicit approval for installing the scoped sudoers grant, installing the user LaunchAgent, deliberately changing sleep settings, terminating the test app, and temporarily removing/restoring the scoped grant for fault injection. Do not apply these operations to the everyday Mac implicitly.

The operator performs every technical action and records timestamp, command/helper result, actual `SleepDisabled` reading and cleanup result. The user only needs to respond to native authorization sheets and perform physical unplug/replug/lid actions when requested.

1. **Baseline and installation:** Keep the lid open, laptop on a ventilated desk, battery comfortably above the floor, AC available and no competing sleep-setting tools. Record OS/build, model/chip, power accessories/displays, background permissions and existing grant/agent/app. Back up any existing components before replacement. Require `SleepDisabled=0` with no outstanding owned lease. If the flag is externally ON, stop and resolve it with its owner. Install the candidate and verify that initial keep-awake remains OFF.
2. **Permission and watcher preflight:** With normal sleep verified, cancel the setup sheet / test with the grant absent: ON must fail. Test denied background-item permission: ON must fail without a healthy watcher. Restore permissions and verify normal sleep after each case, including failures. Record whether the real `sudo -ll` output matches the parser on this machine.
3. **Power removal:** Enable keep-awake on AC with the default option. Physically unplug every power source (including a charging dock/display). Verify prompt OFF and real normal-sleep state. Reconnect: it must stay OFF. Disable the option and repeat: keep-awake should remain owned; manually turn OFF and verify restoration. Re-enable the default option.
4. **Normal quit:** Enable, quit from the popover and verify the flag is OFF and ownership record absent. Repeat while the popover is closed and with the auto-off timer selected.
5. **Force-quit and crash recovery:** Enable, record the last lease renewal, terminate the GUI without cleanup, and observe the separate watchdog restore the actual flag and remove ownership. Repeat for abrupt process death. Record actual latency; investigate if normal recovery exceeds about a minute. Verify normal sleep before the next case.
6. **Permission failure while owned:** Only on AC, lid open and with an approved immediate recovery path. Temporarily revoke the **scoped Sleepless grant**, trigger OFF, and verify an explicit failure, retained ownership and retained watchdog. Do not close the lid, leave the machine or remove recovery. Restore the grant immediately, observe successful retry and verify actual OFF. If automated recovery fails, use the separately approved direct restoration, verify OFF, stop further tests and investigate. Never edit unrelated sudoers rules.
7. **Upgrade and uninstall:** Enable owned state, run the upgrade, and prove it first restores sleep and does not auto-arm afterward. Test uninstallation during a failed clear: it must abort before removing the watchdog/grant. Repair permission, prove normal sleep, then complete removal and verify the app, executable, LaunchAgent and scoped grant are gone. Verify that the inert maintenance fence remains and an old copy cannot re-arm without a successful reinstall.
8. **Actual sleep:** With the flag verified OFF, close the lid briefly on battery, reopen and confirm actual sleep/wake behavior. With the default unplug option, do not accidentally treat the intentional OFF on unplug as a failure of battery keep-awake. If testing lid-closed keep-awake, deliberately opt out first and supervise on the desk; restore the default and verify OFF afterward.

**After every case, including failures:** verify real `SleepDisabled=0`, no active ownership lease, and the expected agent/grant presence. If OFF cannot be verified, do not proceed to another case or remove recovery. Repair authorization and retry; an explicitly approved reboot is the final fallback. Record any unresolved recovery before leaving the machine. No failed test may be reported as a safe endpoint merely because the process exited.

## Machine differences and everyday acceptance

Observed build/read-only test host on 21 October 2026: **MacBook Air (Mac16,12), Apple M4, 16 GB; macOS 26.5.2 (25F84); Swift 6.2.3; macOS SDK 26.2; arm64.** The user approved development-machine live testing; measured results are recorded below. A second Apple Silicon MacBook was user-tested on macOS 26.6.2; its exact model and policy/accessory configuration were not recorded. Other hardware and permission combinations still require separate acceptance. The default artifact targets macOS 26 on Apple Silicon; the compatibility artifact targets macOS 13 on Apple Silicon. A compatibility build is not proof of runtime behavior on macOS 13. Intel requires its own target/build and testing; no Intel runtime validation is claimed.

After development tests pass, the short acceptance test on the everyday Mac is:

1. Approve that machine's installation separately; record its differences and verify initial normal sleep.
2. Arm on AC, unplug with the default option, confirm OFF, then reconnect and confirm it stays OFF.
3. Arm and quit normally; verify actual OFF. Arm again, force-quit and verify independent recovery within the measured development tolerance, recording any difference.
4. Verify missing permission prevents arming, restore setup, then verify normal sleep and actual lid-close sleep on battery. Keep failed-clear fault injection on the development machine unless separately authorized here.
5. Leave the app OFF with the default unplug setting enabled. Only accept it for everyday use when all results and cleanup checks pass on **this** machine. Keep the candidate and rollback/uninstall procedure available.


## Development-machine live results (21 October 2026)

With explicit approval, installed and tested on the MacBook Air M4 described above:

| Case | Observed result |
| --- | --- |
| Missing grant / missing watchdog | Arming refused; normal sleep flag preserved |
| Default power disconnection | Physical AC-to-battery change cleared the flag and lease within the 0.5-second observation interval |
| Power return | Remained OFF; no automatic re-arming |
| User-driven normal Quit | App exited; flag OFF and lease absent |
| Actual force-quit (SIGKILL) | Independent recovery observed 49.3 seconds after termination |
| Actual abrupt crash (SIGABRT) | Flag OFF after 43.7 seconds; lease removed by 44.2 seconds |
| Scoped grant revoked during owned ON | OFF failed explicitly; failed removal retained app, agent and ownership; automatic recovery about 10 seconds after grant restoration |
| Owned-state source upgrade | Restored sleep before replacement; did not re-arm |
| Full uninstall from owned ON | Flag OFF; app, grant, agent plist, copied executable and loaded job removed; inert maintenance marker retained |
| Clean reinstall | Initial absent-app AppleScript resolution bug found, fixed, and retested successfully; flag OFF and healthy installed watchdog |
| Power-removal opt-out | ON retained for 12 seconds on battery, then explicitly cleared and cleanup verified |
| Physical lid close/reopen | User unsure; no sleep log entry, with Screen Sharing explicitly preventing system sleep. Sleepless flag remained OFF; actual sleep unverified |

Normal sleep flag and lease cleanup were verified after each case, including the failed clean-install attempt. No existing Sleepless components needed backup because none were present at baseline. The candidate was reinstalled for continued testing.

The development Mac required Screen Sharing, which asserted `PreventSystemSleep`; existing idle settings and assertions were left unchanged. Flag recovery was verified, but actual physical sleep was not demonstrated in that configuration.

## Second-machine user acceptance (21 October 2026)

On an everyday Apple Silicon MacBook running macOS 26.6.2, the user confirmed successful launch, music continuing with the lid closed on AC, automatic OFF on power disconnection, and OFF with no error after an AC-connected Force Quit / 75-second wait / reopen check. These are user observations, not direct lease or latency measurements. Powered clamshell operation alone does not establish that Sleepless was necessary for that behavior. Normal-quit cleanup, reconnection, failed-permission handling and actual physical sleep were not separately confirmed on this second machine.

## Attribution and licence

The lease/watchdog design was adapted from [mmavko/Sleepless at e06a994](https://github.com/mmavko/Sleepless/tree/e06a994148d0f35b2096dc3893a9dd171a74dbc0). That fork and the original repository carry the same MIT licence and Adam Boudjemaa copyright notice. The original [LICENSE](../LICENSE) is retained unchanged and included in built app resources. No additional dependencies or differently licensed code were imported. The fork's unrelated CLI, activity and thermal features are outside this contribution.
