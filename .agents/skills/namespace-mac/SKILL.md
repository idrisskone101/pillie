---
name: namespace-mac
description: On-demand Namespace macOS Devbox for iOS builds and simulator QA from a Linux Cursor Cloud Agent. Use when the agent is not on macOS and must compile Pillie, boot the simulator, screenshot, or run focused tests.
---

# Namespace Mac

Linux Cloud Agents cannot run Xcode. Pillie keeps **one** Namespace Devbox named `pillie-ios` (macOS Golden Gate 27, Apple Silicon) and starts it only for iOS verify.

The Cloud Agent stays on Linux. The Mac is a remote builder, not the agent VM.

## When to use

Load this for any iOS build, `simctl` launch, screenshot, or focused test while `uname` is Linux.

Skip it on a real Mac (Idriss's laptop or an agent already running on `pillie-ios`). Use `pillie-ios` locally there.

## Loop

1. **Auth.** `Pillie/scripts/namespace-mac.sh auth-check`.
   Done when: it prints `ok: Namespace auth`. If it asks for `NSC_TOKEN`, stop and tell the user to add that Cloud Agent secret.
2. **Start.** `make ns-mac-start` (or `make ns-mac-diagnose` the first time).
   Done when: `uname` on the remote host is Darwin.
3. **Sync.** Push the branch, then `make ns-mac-sync` (or `make ns-mac-sync REF=<sha>`).
   Done when: the Mac checkout is on that SHA.
4. **Verify.** Run the same Makefile API on the Mac:
   - `make ns-mac-exec CMD='make build'`
   - `make ns-mac-exec CMD='make build-and-run'`
   - `make ns-mac-exec CMD='make test TESTS=ClassName'`
   - `make ns-mac-exec CMD='make screenshot'`
   Done when: the remote command succeeded and you have the screenshot or test result.
5. **Stop.** `make ns-mac-stop` as soon as verify is done.
   Done when: `nsc list --all` shows no running instance.

Never leave the Mac running after the iOS step. Idle auto-stop is 30 minutes; that is a backstop, not the shutdown plan.

## Rules

- One Devbox only: `pillie-ios`. Do not `devbox create` another Mac. The Personal workspace limit is one Devbox.
- Do not start it for Swift-only edits, copy, or planning. Start it when you need `xcodebuild` or the simulator.
- Do not run `nsc create` for a second Mac instance. `devbox exec` starts the existing Devbox.
- Do not print `NSC_TOKEN` or token files.
- `make build` on Linux is the wrong tool. Use `make ns-mac-exec`.

## Targets

- `make ns-mac-status`
- `make ns-mac-start`
- `make ns-mac-stop`
- `make ns-mac-sync` / `make ns-mac-sync REF=<sha>`
- `make ns-mac-diagnose`
- `make ns-mac-exec CMD='make …'`

Script `--help` is the flag source of truth: `Pillie/scripts/namespace-mac.sh`.
