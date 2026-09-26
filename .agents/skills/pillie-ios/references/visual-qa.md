# Visual QA

Done when: a 1x screenshot shows the changed UI, and `axe describe-ui` contains the expected labels (or a named focused test passed). Follow `verify-pillie` for the potato / `/poteto-mode` path.

1. `make qa` on a Mac, or `make ns-mac-qa` on a Linux cloud agent. Both boot the simulator, build-and-run, wait for a settled UI, and write the 1x PNG plus an axe dump.
2. Drive with a flow: `make flow FLOW=<name>` on a Mac, `make ns-mac-flow FLOW=<name>` on Linux. `verify-pillie` owns flows, the feature map, and where the evidence lands.
3. Navigate with accessibility identifiers or labels. Coordinate taps only after a fresh 1x image (points, not pixels).

`axe --help` is the command catalog. Pass `--udid` every time. Scroll is content-direction: `scroll-down` reveals content below the fold.

Prefer MCP UI automation with identifiers and labels when it is available. Use AXe when MCP is missing a gesture, when the accessibility tree is the source of truth, or when a browser mirror's annotations drift.

Simulators are 2x or 3x; SwiftUI coordinates are points. `make screenshot` defaults to 33.33% (3x). Use `SCALE=50%` for 2x.

## Codex Browser mirror

Skip this in opencode and Cursor. Codex only:

```bash
Pillie/scripts/serve-simulator-browser.sh
```

Open the printed localhost URL in the Codex in-app browser. Keep it running. Build/run the app separately. The mirror is a streamed canvas, not DOM; the accessibility tree is canonical. Map frames with `Pillie/scripts/simulator-browser-ax-map.mjs` (`--help` for `--frame` / `--json`).
