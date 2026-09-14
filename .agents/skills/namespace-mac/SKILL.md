---
name: namespace-mac
description: On-demand Namespace macOS Devbox for iOS builds and simulator QA from a Linux Cursor Cloud Agent. Use when the agent is not on macOS and must compile Pillie, boot the simulator, screenshot, or run focused tests.
---

# Namespace Mac

Linux Cloud Agents cannot run Xcode. Pillie keeps **one** Namespace Devbox named `pillie-ios` (macOS Golden Gate 27, Apple Silicon) and starts it only for iOS verify.

The Cloud Agent stays on Linux. The Mac is a remote builder, not the agent VM. Compute is **$0.06/min** while the Mac is up. Stopped compute is free.

## When to use

Load this for any iOS build, `simctl` launch, screenshot, or focused test while `uname` is Linux.

Skip it on a real Mac (Idriss's laptop or an agent already running on `pillie-ios`). Use `pillie-ios` locally there.

Do **not** start the Mac for Swift-only edits, copy, planning, or Linux work.

## Loop

1. **Auth.** `Pillie/scripts/namespace-mac.sh auth-check`.
   Done when: it prints `ok: Namespace auth`. If it asks for `NSC_TOKEN`, stop and tell the user to add that Cloud Agent secret.
2. **One job.** Push the branch, then `make ns-mac-verify CMD='make build'` (or `build-and-run` / `screenshot` / `test TESTS=ClassName`).
   Done when: the remote command finished and the Mac is stopped.
3. **A batch.** If you need several remote commands, `make ns-mac-start`, `make ns-mac-sync`, then each `make ns-mac-exec CMD='…'`, then `make ns-mac-stop`.
   Done when: `nsc list --all` shows no running instance.

Prefer step 2. `verify` starts, syncs, runs, and stops in one shot. One-shot `exec` / `sync` / `diagnose` also stop the Mac if they had to start it. `KEEP=1` leaves it up.

Never leave the Mac running after the iOS step. Idle auto-stop is 15 minutes; that is a backstop, not the shutdown plan.

## Rules

- One Devbox only: `pillie-ios`. Do not `devbox create` another Mac. The Personal workspace limit is one Devbox.
- Do not start it for Swift-only edits, copy, or planning. Start it when you need `xcodebuild` or the simulator.
- Do not run `nsc create` for a second Mac instance. `devbox exec` starts the existing Devbox.
- Do not print `NSC_TOKEN` or token files.
- `make build` on Linux is the wrong tool. Use `make ns-mac-verify` or `make ns-mac-exec`.
- Batch remote work. Two separate one-shots each pay a boot. One `start` … `stop` session is cheaper for several commands.
- Size stays `M`. Do not recreate as `L`. Do not use an ephemeral Devbox (cold Xcode each time costs more).

## Targets

- `make ns-mac-status`
- `make ns-mac-verify CMD='make …'` — preferred one-shot
- `make ns-mac-start` / `make ns-mac-stop`
- `make ns-mac-sync` / `make ns-mac-sync REF=<sha>`
- `make ns-mac-diagnose`
- `make ns-mac-exec CMD='make …'`
- `KEEP=1 make ns-mac-exec CMD='…'` — leave the Mac up

Script `--help` is the flag source of truth: `Pillie/scripts/namespace-mac.sh`.
