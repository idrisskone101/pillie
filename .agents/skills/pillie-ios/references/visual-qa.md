# Visual QA

Done when: a 1x screenshot shows the changed UI, and `axe describe-ui` contains the expected labels (or a named focused test passed). Follow `verify-pillie` for the potato / `/poteto-mode` path.

1. `make qa` on a Mac, or `make ns-mac-qa` on a Linux Cloud Agent. Both boot the simulator, build-and-run, wait for a settled UI, and write the 1x PNG plus an axe dump. `build-and-run` now boots first, so install should not fail with `SimError 405 Shutdown`.
2. Read `/tmp/sim_screenshot_1x.png` and `/tmp/pillie_ax.txt` (Linux copies them to `/opt/cursor/artifacts/`).
3. Navigate with accessibility identifiers or labels. Coordinate taps only after the 1x image (points, not pixels).
4. Recapture with `SKIP_BUILD=1 make qa` or `SKIP_BUILD=1 make ns-mac-qa`.
5. Repeat until the bound above is met.

`axe --help` is the command catalog. Pass `--udid` every time. Scroll is content-direction: `scroll-down` reveals content below the fold.

Prefer MCP UI automation with identifiers and labels when it is available. Use AXe when MCP is missing a gesture, when the accessibility tree is the source of truth, or when a browser mirror's annotations drift.

Simulators are 2x or 3x; SwiftUI coordinates are points. `make screenshot` defaults to 33.33% (3x). Use `SCALE=50%` for 2x.

## Codex Browser mirror

Skip this in opencode and Cursor. Codex only:

```bash
Pillie/scripts/serve-simulator-browser.sh
```

Open the printed localhost URL in the Codex in-app browser. Keep it running. Build/run the app separately. The mirror is a streamed canvas, not DOM; the accessibility tree is canonical. Map frames with `Pillie/scripts/simulator-browser-ax-map.mjs` (`--help` for `--frame` / `--json`).
