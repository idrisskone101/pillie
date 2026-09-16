# Namespace verify loop

`make ns-mac-qa` is the one remote proof. Potato / `/poteto-mode` reaches it through `verify-pillie`.

## What it does

1. `check-sync` on this VM. Dirty or unpushed HEAD fails before Activate.
2. Start `pillie-ios` if SSH is down. Skip Ensure/Activate when SSH already works.
3. `git fetch` + `git reset --hard <sha>` on `/Users/runner/workspaces/pillie`.
4. Remote `Pillie/scripts/sim-qa.sh`: boot the iPhone 17 Pro, `make build-and-run` (or `make run` when this SHA is already built), wait until `axe describe-ui` looks settled, write the 1x PNG and axe dump.
5. Copy artifacts to `/opt/cursor/artifacts/`.
6. Leave the Mac running.

## Artifacts

- `/opt/cursor/artifacts/pillie_simulator_1x.png`
- `/opt/cursor/artifacts/pillie_ax.txt`
- `/opt/cursor/artifacts/pillie_qa.json`

`pillie_qa.json` has `sha`, `udid`, `ready`, `axe`, and `duration_s`. `ready=false` still wrote a screenshot. Read the PNG and the axe dump before you call the run done.

## Extra commands

| Goal | Command |
| --- | --- |
| Recapture without compile | `SKIP_BUILD=1 make ns-mac-qa` |
| Screenshot only, app already up | `CAPTURE_ONLY=1 make ns-mac-qa` |
| Force a rebuild of the same SHA | `FORCE_BUILD=1 make ns-mac-qa` |
| Focused XCTest | `make ns-mac-verify CMD='make test TESTS=ClassName'` |
| Axe after qa | `make ns-mac-exec CMD='axe describe-ui --udid "$(make -s udid)"'` |

On a Mac, `make qa` is the same capture path without Namespace.

## Failures the loop now owns

| Old failure | What happens now |
| --- | --- |
| `SimError 405 Shutdown` | `build-and-run` and `sim-qa` boot the simulator first. Boot overlaps compile. |
| `git checkout --detach` on a dirty Mac tree | Remote sync is `git reset --hard <sha>`. |
| Unpushed HEAD, then a failed remote fetch | `check-sync` fails locally first. |
| Launch-screen PNG after a fixed `sleep 8` | `sim-qa` waits for axe labels or a settled tree. |
| `make screenshot` without `magick` | `sips` writes the 1x PNG. |
| Second Activate on an already-up Mac | `start` returns when SSH already works. |
| SSH `Permission denied` after a new instance | Exec refreshes `GetSSHConfig` and retries once. |

`NS_MAC_ALLOW_DIRTY=1` skips the working-tree check. The Mac still syncs HEAD, not your dirty files.
