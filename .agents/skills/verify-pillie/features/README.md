# Pillie verification map

One file per user-facing area. Each names the flows that drive it and the state they start from. Read the file before you drive that area; run its flows with `make ns-mac-flow FLOW=<name>` (Linux) or `make flow FLOW=<name>` (Mac).

## Before any flow

- The build you want to prove is installed: `make ns-mac-qa` / `make qa` finished with `"ready": true` and your SHA.
- Flows start from their own state (`launch` + a debug deep link, or `fresh`). They do not depend on each other and can run in any order, or all at once with `FLOW=all`.
- `make verify-flows` passes.

## Proof and skip reporting

- A shot proves a state only right after a `wait` for that state. A launch shot alone proves nothing about a feature.
- Report an unreachable path with the flow, the failing step, and the missing prerequisite. Each feature file lists what a simulator cannot reach.
- Do not report a feature verified through a different entry point than the one you changed.

## Features

- [Onboarding](./onboarding.md) is first launch through Home: every onboarding step and the app-blocking setup.
- [Today](./today.md) is the home tab: status and pack cards, marking the pill taken, trial states, the review prompt.
- [History](./history.md) is the calendar tab: month paging and correcting a past day.
- [Settings](./settings.md) is every settings editor and the in-app language switch.
- [Paywalls](./paywalls.md) is the four honest-paywall boards, Plus upsells, and the commerce verification states.
- [Developer menu](./developer-menu.md) is the debug-only QA scenario sheet.

## Harness flows

- `smoke.flow` exercises every runner step. Run it after changing `Pillie/scripts/sim-flow.sh`.
- `perf.flow` measures relaunch time and the app's frame probes. See the Perf section of the skill.
