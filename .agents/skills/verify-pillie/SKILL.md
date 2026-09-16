---
name: verify-pillie
description: Prove Pillie iOS behavior on the real simulator. Use for /poteto-mode, poteto-mode, potato mode, poteto-agent, visual QA, or any time compile-only is not enough.
---

# Verify Pillie

Potato / `/poteto-mode` Feature step 5 ("Verify on the matching surface") is this skill. `make build` is not done.

The user-facing surface is the iPhone 17 Pro simulator running `com.idrisskone.pillie`. Linux Cloud Agents do not run Xcode. They drive the Namespace Mac `pillie-ios` through `namespace-mac`.

Read the feature file before you drive that screen. The map is in [features/README.md](features/README.md).

## Launch

**Linux Cloud Agent**

```bash
git push -u origin HEAD
make ns-mac-qa
```

Ready when `/opt/cursor/artifacts/pillie_qa.json` exists and the 1x PNG is not a blank launch frame. `ready` in that JSON should be `true`. The Mac stays up.

**Mac (laptop or already on `pillie-ios`)**

```bash
make qa
```

Ready when `/tmp/pillie_qa.json` exists and `/tmp/sim_screenshot_1x.png` shows app chrome. Same `ready` field.

`make ns-mac-screenshot` and `make ns-mac-verify` with no `CMD` call the same path.

Do not start Idriss's MacBook. Do not stop `pillie-ios` unless the user asked.

## Doctor

Run this first when anything looks off.

**Linux, before launch**

```bash
Pillie/scripts/namespace-mac.sh auth-check
make ns-mac-check-sync
make ns-mac-status
```

Auth must print `ok: Namespace auth`. Check-sync must print `ok:` and a SHA. Status must show Devbox `pillie-ios`.

**After launch**

- Linux: `/opt/cursor/artifacts/pillie_qa.json` has this SHA, `axe` true or a written `pillie_ax.txt`, and a 1x PNG larger than a solid splash.
- Mac: `make diagnose` shows Xcode 27 and an iPhone 17 Pro UDID. `/tmp/pillie_qa.json` matches HEAD.

Do not drive a simulator you did not boot in this run, and do not drive Idriss's personal Device Hub pin from a Cloud Agent.

## Drive

After launch the app is already running. Prefer labels and identifiers over coordinates.

```bash
UDID=$(make -s udid)
axe describe-ui --udid "$UDID"
```

On Linux wrap every axe call:

```bash
make ns-mac-exec CMD='axe describe-ui --udid "$(make -s udid)"'
```

Tap by identifier or name. Example: `axe tap --udid "$UDID" --id homeBlockingStatusCardCTA`. Coordinates only after a fresh 1x PNG (points, not pixels). Scroll is content-direction: `scroll-down` reveals content below the fold.

Then recapture:

```bash
SKIP_BUILD=1 make ns-mac-qa    # Linux
SKIP_BUILD=1 make qa           # Mac
```

Use `CAPTURE_ONLY=1` when the app is already on the screen you want.

Named unit tests are extra, not a substitute: `make test TESTS=ClassName` locally, or `make ns-mac-verify CMD='make test TESTS=ClassName'` on Linux.

## Evidence

Proof is the user path plus the resulting state.

Required artifacts:

| Host | 1x PNG | Axe dump | Meta |
| --- | --- | --- | --- |
| Linux | `/opt/cursor/artifacts/pillie_simulator_1x.png` | `/opt/cursor/artifacts/pillie_ax.txt` | `/opt/cursor/artifacts/pillie_qa.json` |
| Mac | `/tmp/sim_screenshot_1x.png` | `/tmp/pillie_ax.txt` | `/tmp/pillie_qa.json` |

The PNG must show Pillie chrome (tab bar, onboarding, or paywall), not SpringBoard and not a white launch frame. The axe dump must contain the label you claimed. A passing compile with no PNG is not proof.

## Cleanup

Leave the simulator and the Namespace Mac up. Do not `make ns-mac-stop` unless the user asked. Do not delete the artifacts above. Do not kill by process name.

## Helpers

- `make ns-mac-qa` — Linux golden path (`Pillie/scripts/namespace-mac.sh qa`)
- `make qa` — Mac golden path (`Pillie/scripts/sim-qa.sh`)
- `make ns-mac-ensure-tools` / `make ensure-qa-tools` — install axe and ImageMagick if missing
- `make ns-mac-check-sync` — fail before Activate if HEAD is dirty or unpushed
- `make ns-mac-exec CMD='…'` — one remote command after the Mac is up
- `Pillie/scripts/sim-qa.sh --skip-build` / `--capture-only` / `--force-build`

`namespace-mac` owns SSH, Activate, and the don'ts. This skill owns what "done" means.
