# Namespace verify loop

`make ns-mac-qa` is the one remote proof. Potato / `/poteto-mode` reaches it through `verify-pillie`.

## What it does

1. `check-sync` on this VM. Dirty or unpushed HEAD fails before Activate.
2. Start `pillie-ios` if SSH is down. Skip Ensure/Activate when SSH already works.
3. `git fetch` + `git reset --hard <sha>` on `/Users/runner/workspaces/pillie`.
4. Remote `Pillie/scripts/ensure-qa-tools.sh`: install `axe` and ImageMagick if they are missing.
5. Remote `Pillie/scripts/sim-qa.sh`: boot the iPhone 17 Pro, `make build-and-run` (or `make run` when this SHA is already built), wait until `axe describe-ui` looks settled, write the 1x PNG and axe dump.
6. Copy artifacts to the artifact dir: `$PILLIE_NS_ARTIFACT_DIR`, else `/opt/cursor/artifacts` when `/opt/cursor` exists, else the repo's `.qa-artifacts/`.
7. Leave the Mac running.

## Artifacts

- `pillie_simulator_1x.png`
- `pillie_ax.txt` (raw axe JSON; `Pillie/scripts/ax-outline.py` flattens it)
- `pillie_qa.json`
- `flows/<name>/` after `make ns-mac-flow`

`pillie_qa.json` has `sha`, `udid`, `ready`, `axe`, and `duration_s`. `ready=false` still wrote a screenshot. Read the PNG and the axe dump before you call the run done.

## Extra commands

| Goal | Command |
| --- | --- |
| Recapture without compile | `SKIP_BUILD=1 make ns-mac-qa` |
| Screenshot only, app already up | `CAPTURE_ONLY=1 make ns-mac-qa` |
| Install axe / magick only | `make ns-mac-ensure-tools` |
| Force a rebuild of the same SHA | `FORCE_BUILD=1 make ns-mac-qa` |
| Focused XCTest | `make ns-mac-verify CMD='make test TESTS=ClassName'` |
| Drive after qa | `make ns-mac-flow FLOW=<name>` (see `verify-pillie`) |
| One axe call | `make ns-mac-exec CMD='axe describe-ui --udid "$(make -s udid)"'` |

On a Mac, `make qa` is the same capture path without Namespace.

## Failures the loop now owns

| Old failure | What happens now |
| --- | --- |
| `SimError 405 Shutdown` | `build-and-run` and `sim-qa` boot the simulator first. Boot overlaps compile. |
| `git checkout --detach` on a dirty Mac tree | Remote sync is `git reset --hard <sha>`. |
| Unpushed HEAD, then a failed remote fetch | `check-sync` fails locally first. |
| Launch-screen PNG after a fixed `sleep 8` | `sim-qa` waits for axe labels or a settled tree. |
| `make screenshot` without `magick` | `ensure-qa-tools` installs ImageMagick; `sips` is the fallback. |
| `axe` / `magick` missing after Stop/Start | They live on the persistent volume. `ensure-qa-tools` reinstalls if the volume was wiped. |
| Second Activate on an already-up Mac | `start` returns when SSH already works. |
| SSH `Permission denied` after a new instance | Exec refreshes `GetSSHConfig` and retries once. |
| `$(…)` inside `CMD=` eaten by make | `CMD` reaches the Mac through the environment, unexpanded. |
| 2.5 MB of xcodebuild output per qa | The build log stays in `/tmp/pillie_build.log` on the Mac; errors and the tail come back on failure. `PILLIE_QA_VERBOSE=1` streams it. |
| One exec (about 7 s) per tap | `make ns-mac-flow` runs a whole flow in one job; a tap costs about 0.9 s. |

`NS_MAC_ALLOW_DIRTY=1` skips the working-tree check. The Mac still syncs HEAD, not your dirty files.

## Axe and ImageMagick

`pillie-ios` is one Devbox with a 100 GiB persistent volume. [Lifecycle](https://namespace.so/docs/devbox/lifecycle) says Stop keeps that volume and resume is seconds. Delete destroys it. Ephemeral Devboxes wipe storage on stop. `pillie-ios` is not ephemeral.

macOS Devboxes [cannot use a custom image](https://namespace.so/docs/devbox/images). You pick a Namespace-managed macOS + Xcode version. You cannot bake `axe` or ImageMagick into the base image.

A [blueprint init script](https://namespace.so/docs/devbox/blueprint) runs once on first create, and blueprint / spec-file [sessions](https://namespace.so/docs/devbox/sessions) run every start. Both are dashboard (or `devbox create --from`) only. This Cloud Agent token cannot use the `devbox` CLI, and we do not create a second box.

So the repo owns the tools:

1. Install once on `/opt/homebrew`. Stop/Start keeps them.
2. `Pillie/scripts/ensure-qa-tools.sh` runs on every `make qa` / `make ns-mac-qa`. If this is a new box or the volume was deleted, it `brew install`s `cameroncooke/axe` and `imagemagick`.
3. Optional dashboard init if you recreate `pillie-ios` from a blueprint:

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
brew tap cameroncooke/axe
brew help trust >/dev/null 2>&1 && brew trust cameroncooke/axe
brew install axe imagemagick
```
