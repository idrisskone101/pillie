---
name: namespace-mac
description: On-demand Namespace macOS Devbox for iOS builds and simulator QA from a Linux Cursor Cloud Agent. Use when the agent is not on macOS and must compile Pillie, boot the simulator, screenshot, or run focused tests.
---

# Namespace Mac

Linux Cloud Agents cannot run Xcode. Pillie keeps **one** Namespace Devbox named `pillie-ios` (macOS 27.x, Apple Silicon size M). Start it only for iOS verify.

This Linux VM is the agent. The Mac is a remote builder. Do not treat Idriss's MacBook or a Cursor self-hosted worker as the Devbox.

Compute is **$0.06/min** while the Mac is up. Stopped compute is free. Always Stop when the iOS step is done. `ensure` applies idle `900s` via `DevBoxService.Update` (do not send `15m`; protobuf Duration rejects it). That is a backstop, not the shutdown plan.

## When to use

Load this when `uname` is Linux and the task needs `xcodebuild`, `simctl`, a simulator screenshot, or a focused XCTest.

Skip it on a real Mac (Idriss's laptop or an agent already running on `pillie-ios`). Use `pillie-ios` locally there.

Do not start the Mac for Swift-only edits, copy, planning, or Linux work.

## Loop

1. **Auth.** `Pillie/scripts/namespace-mac.sh auth-check`.
   Done when: it prints `ok: Namespace auth`. If it asks for `NSC_TOKEN`, stop and tell the user to add that Cloud Agent secret (raw `nsrt_…` bearer, not a `tok_…` id).
2. **Push.** Push the branch so the Mac can check it out.
   Done when: `git push -u origin HEAD` succeeded.
3. **One job.** `make ns-mac-verify CMD='make build'` (or `build-and-run` / a focused test). For a screenshot, `make ns-mac-screenshot`.
   Done when: the remote command finished and the Mac is stopped (`make ns-mac-status` shows `instance: stopped`).
4. **A batch.** If you need several remote commands, `make ns-mac-start`, `make ns-mac-sync`, then each `make ns-mac-exec CMD='…'`, then `make ns-mac-stop`.
   Done when: `make ns-mac-status` shows `instance: stopped`.

Prefer step 3. `verify` starts, syncs, runs, and stops in one shot. One-shot `exec` / `sync` / `diagnose` / `screenshot` also stop the Mac if they had to start it. `KEEP=1` leaves it up.

Never leave the Mac running after the iOS step.

## Simulator screenshot

`make build-and-run` does not boot the simulator. Install then fails with `SimError 405 Shutdown` until the device is up. The screenshot helper already boots first:

```bash
make ns-mac-screenshot
```

That command, on the Mac:

1. `UDID=$(make -s udid)` — local iPhone 17 Pro. The laptop pin UDID is not on this box; that warning is expected.
2. `xcrun simctl boot "$UDID" || true` then `xcrun simctl bootstatus "$UDID" -b`
3. `make build-and-run`
4. `make screenshot` if `magick` is installed, otherwise `sips` writes `/tmp/sim_screenshot_1x.png`
5. Copies the 1x PNG to `/opt/cursor/artifacts/pillie_simulator_1x.png`

If you `exec` a custom UI command, boot the simulator yourself before install or screenshot. Xcode on this box is `/Applications/Xcode_27-RC.app` (Xcode 27.0). `xcode-env.sh` already prefers it.

## Rules

- One Devbox only: `pillie-ios` (id `2jr7kuslpli14`, site `iad`). Do not create another. The Personal workspace limit is one Devbox.
- Do not start Idriss's MacBook. Do not pick a Cursor self-hosted worker for iOS verify.
- Do not use the `devbox` CLI (`devbox list` / `create` / `exec` / `shutdown` / `configure-ssh`). This Cloud Agent token cannot log it in.
- Do not `devbox create --image goldengate`. The live box is `os: macos` with selector `macos.version=27.x` only.
- Do not set `macos.purpose=githubrunner`. That image has no Devbox agent and is the GitHub-runner Mac.
- Do not `nsc ssh`. The websocket handshake fails.
- Do not `nsc proxy -s agent`. A real Devbox gateway exposes `ssh` and `vnc` only. There is no named `agent` service.
- Do not `nsc extend`. Permission denied for this token.
- Do not `devbox expire` / `DevBoxService.Expire`. This token cannot expire. Stop leaves the Devbox record in place.
- Do not use `devbox configure-ssh` ProxyCommand (`hsvc.unixsocket?name=agent`). Native SSH with the instance key from `GetSSHConfig` is the exec path.
- Do not print `NSC_TOKEN`, token files, or SSH private keys.
- `make build` on Linux is the wrong tool. Use `make ns-mac-verify` or `make ns-mac-exec`.
- Batch remote work. Two separate one-shots each pay a boot. One `start` … `stop` session is cheaper for several commands.
- Size stays `M`. Do not recreate as `L`. Do not use an ephemeral compute instance (cold Xcode each time costs more).
- `PILLIE_BUILD_JOBS=6` is fine on size M. DerivedData stays `/tmp/PillieDerivedData-pillie`.

## Auth

`NSC_TOKEN` is a raw bearer. `nsc` wants JSON at `NSC_TOKEN_FILE`:

```json
{"bearer_token": "<NSC_TOKEN>"}
```

`hydrate-auth` writes that file. If `NSC_TOKEN` is set, it overwrites the file so a snapshot-baked `token.json` cannot outrank a rotated Cloud Agent secret. Default path is `~/.config/ns/token.json`. Cloud Agents often already have `/tmp/nsc-auth/token.json`. `environment.json` `start` runs hydrate on every pod. `nsc auth check-login` works with that file. `nsc workspace describe` is flaky; ignore it. `nsc list --all` can fail without a TTY; use `nsc list -o json` or `make ns-mac-status`.

This token can `Activate` / `GetSSHConfig` / native SSH. It cannot `nsc ssh`, `devbox exec`, or grant `instance:dial_host` / `ingress:access`. Do not try to mint those from the Cloud Agent token.

## Exec path

The helper talks to Namespace over Connect JSON (`Pillie/scripts/namespace-mac-api.py`), then SSH:

1. `DevBoxService.Fetch` / `Activate` / `Stop` on `https://private-api.global.namespaceapis.com`
2. `ComputeService.GetSSHConfig` on `https://us.compute.namespaceapis.com`
3. `ssh -F ~/.namespace/ssh/pillie-ios.config pillie-ios`

SSH user is the **instance id**, not `runner`. Host is typically `ssh.iad4.namespace.so`. The key is instance-scoped; `start` refreshes it. After Stop, SSH returns `Permission denied (publickey)`.

Guest checkout: `/Users/runner/workspaces/pillie`. Guest user: `runner`. In-guest agent listens on TCP `*:22210` with sockets under `/var/run/devbox/socks/`. You do not need to talk to that agent; native SSH is enough.

If the helper is missing and you must recover by hand, see [connect.md](references/connect.md).

## Targets

- `make ns-mac-status`
- `make ns-mac-verify CMD='make …'` — preferred one-shot
- `make ns-mac-screenshot` — boot, build-and-run, 1x screenshot, copy, stop
- `make ns-mac-start` / `make ns-mac-stop`
- `make ns-mac-sync` / `make ns-mac-sync REF=<sha>`
- `make ns-mac-diagnose`
- `make ns-mac-exec CMD='make …'`
- `KEEP=1 make ns-mac-exec CMD='…'` — leave the Mac up

Script `--help` is the flag source of truth: `Pillie/scripts/namespace-mac.sh`.
