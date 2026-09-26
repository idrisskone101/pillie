---
name: namespace-mac
description: On-demand Namespace macOS Devbox for iOS builds and simulator QA from a Linux Cursor Cloud Agent. Use when the agent is not on macOS and must compile Pillie, boot the simulator, screenshot, or run focused tests.
---

# Namespace Mac

Linux Cloud Agents cannot run Xcode. Pillie keeps **one** Namespace Devbox named `pillie-ios` (macOS 27.x, Apple Silicon size M). Start it only for iOS verify.

This Linux VM is the agent. The Mac is a remote builder. Do not treat Idriss's MacBook or a Cursor self-hosted worker as the Devbox.

Compute is **$0.06/min** while the Mac is up. Stopped compute is free. **Do not stop the Mac unless the user asked.** `make ns-mac-stop` is user-gated. The Makefile defaults `KEEP=1`. `ensure` applies idle `900s` via `DevBoxService.Update` (do not send `15m`). Idle is a backstop if the box sits unused, not permission to Stop.

Potato / `/poteto-mode` proof loads `verify-pillie`. On Linux that skill is this loop.

## When to use

Load this when `uname` is Linux and the task needs `xcodebuild`, `simctl`, a simulator screenshot, or a focused XCTest.

Skip it on a real Mac (Idriss's laptop or an agent already running on `pillie-ios`). Use `pillie-ios` / `verify-pillie` locally there.

Do not start the Mac for Swift-only edits, copy, planning, or Linux work.

## Loop

1. **Auth.** `Pillie/scripts/namespace-mac.sh auth-check`.
   Done when: it prints `ok: Namespace auth`. If it asks for `NSC_TOKEN`, stop and tell the user to add that Cloud Agent secret (raw `nsrt_…` bearer, not a `tok_…` id).
2. **Push.** Commit and `git push -u origin HEAD`. `qa` refuses a dirty or unpushed HEAD.
   Done when: `git push` succeeded.
3. **Proof.** `make ns-mac-qa`.
   Done when: `/opt/cursor/artifacts/pillie_simulator_1x.png` and `/opt/cursor/artifacts/pillie_qa.json` exist. The Mac stays up.
4. **More UI.** After qa, `make ns-mac-exec CMD='axe …'` or `SKIP_BUILD=1 make ns-mac-qa` to recapture. Custom compile or test: `make ns-mac-verify CMD='make test TESTS=ClassName'`.

`make ns-mac-screenshot` and `make ns-mac-verify` with no `CMD` are the same as `make ns-mac-qa`.

**Stop only on request.** Run `make ns-mac-stop` when the user says to stop, shut down, or tear down the Mac.

Details and failure table: [verify-loop.md](references/verify-loop.md). Connect fallback: [connect.md](references/connect.md).

**No SSH (Claude Code cloud sandbox).** Outbound port 22 is blocked there, even on Full network access. `namespace-mac.sh` probes port 22 and falls back to HTTPS by itself, so `make ns-mac-qa` and the other targets work unchanged. Set `NS_MAC_TRANSPORT=ssh|https` to force one. A one-off command:

```bash
python3 Pillie/scripts/namespace-mac-api.py exec -- /bin/bash -lc 'sw_vers; xcodebuild -version'
```

`exec` calls `CommandService.RunCommandSync` and exits with the remote exit code. `exec --stream` runs the job detached and tails its log, because one RPC kills its process group when it returns. `download REMOTE LOCAL` pulls a file. Commands start with an empty `PATH`, so the helper sets one.

## Rules

- One Devbox only: `pillie-ios` (id `2jr7kuslpli14`, site `iad`). Do not create another.
- Do not start Idriss's MacBook. Do not pick a Cursor self-hosted worker for iOS verify.
- Do not use the `devbox` CLI, `nsc ssh`, `nsc proxy`, `nsc extend`, Expire, or `devbox configure-ssh`.
- Do not print `NSC_TOKEN`, token files, or SSH private keys.
- `make build` on Linux is the wrong tool. Use `make ns-mac-qa`.
- Do not `make ns-mac-stop` unless the user asked. `KEEP=0` auto-stops a one-shot this session started.
- Size stays `M`. `PILLIE_BUILD_JOBS=6` is fine. DerivedData stays `/tmp/PillieDerivedData-pillie`.

## Auth

`NSC_TOKEN` is a raw bearer. `hydrate-auth` writes `{"bearer_token":"<NSC_TOKEN>"}` to `NSC_TOKEN_FILE`. If `NSC_TOKEN` is set, it overwrites a snapshot-baked `token.json`. `environment.json` `start` hydrates on every pod.

This token can `Activate` / `GetSSHConfig` / native SSH. It cannot `nsc ssh` or `devbox exec`.

## Targets

- `make ns-mac-qa` — check-sync, start, sync, ensure axe/magick, boot, build-and-run, wait for UI, 1x PNG, axe dump
- `make ns-mac-verify` — same as qa when `CMD` is empty
- `make ns-mac-screenshot` — same as qa
- `make ns-mac-check-sync` — dirty / unpushed HEAD fails here, before Activate
- `make ns-mac-ensure-tools` — install axe and ImageMagick on the Mac if they are missing
- `make ns-mac-status` / `make ns-mac-start` / `make ns-mac-stop`
- `make ns-mac-sync` / `make ns-mac-diagnose` / `make ns-mac-exec CMD='…'`
- `SKIP_BUILD=1 make ns-mac-qa` — relaunch + recapture
- `KEEP=0 make ns-mac-qa` — stop after this command if this session started it

Script `--help` is the flag source of truth: `Pillie/scripts/namespace-mac.sh`.
