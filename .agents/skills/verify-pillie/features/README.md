# Pillie verification map

Read this index before you drive the app. Then open the matching feature file.

## Baseline preconditions

- Linux Cloud Agent: HEAD is committed and pushed. `make ns-mac-qa` has finished. Artifacts are under `/opt/cursor/artifacts/`.
- Mac: `make qa` has finished. Artifacts are under `/tmp/`.
- Doctor has passed. The 1x PNG shows Pillie, not SpringBoard.
- One iPhone 17 Pro. Do not boot a second simulator.
- Drive with `axe` and the identifiers in each feature file. Do not drive Idriss's laptop from a Cloud Agent.

## Driving conventions

- Start from the launched app. `make ns-mac-qa` / `make qa` already built and launched it.
- Prefer accessibility identifiers, then visible labels. Coordinates only from a fresh 1x PNG.
- On Linux, wrap axe in `make ns-mac-exec CMD='…'`.
- After a mutation, recapture with `SKIP_BUILD=1 make ns-mac-qa` or `SKIP_BUILD=1 make qa`.
- Keep the Mac running.

## Proof and skip reporting

- Capture the tap and the resulting screen. A launch PNG alone is not a feature proof.
- UI proof is the 1x PNG plus the axe dump that contains the claimed label.
- Report an unreachable path with the command you ran and the precondition that failed.
- Do not report a skipped entry point as verified through a different path.

## Features

- [Today](./today.md) is the home tab, due action, and blocking status card.
- [History](./history.md) is the calendar tab.
- [Settings](./settings.md) is language, developer menu, and Plus entry points.
- [Soft paywall](./soft-paywall.md) is the onboarding / Settings paywall.
