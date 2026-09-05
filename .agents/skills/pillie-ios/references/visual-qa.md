# Visual QA

Done when: a 1x screenshot shows the changed UI, and `axe describe-ui` contains the expected labels (or a named focused test passed).

1. `make build-and-run` (or `make run` if already built).
2. `UDID=$(make -s udid)` then `axe describe-ui --udid "$UDID"`.
3. `make screenshot` and inspect `/tmp/sim_screenshot_1x.png`.
4. Navigate with accessibility identifiers or labels. Coordinate taps only after the 1x image (points, not pixels).
5. Screenshot again to confirm.
6. Repeat until the bound above is met.

`axe --help` is the command catalog. Pass `--udid` every time. Scroll is content-direction: `scroll-down` reveals content below the fold.

Prefer MCP UI automation with identifiers and labels when it is available. Use AXe when MCP is missing a gesture, when the accessibility tree is the source of truth, or when a browser mirror's annotations drift.

Simulators are 2x or 3x; SwiftUI coordinates are points. `make screenshot` defaults to 33.33% (3x). Use `SCALE=50%` for 2x.

## Codex Browser mirror

Skip this in opencode and Cursor. Codex only:

```bash
Pillie/scripts/serve-simulator-browser.sh
```

Open the printed localhost URL in the Codex in-app browser. Keep it running. Build/run the app separately. The mirror is a streamed canvas, not DOM; the accessibility tree is canonical. Map frames with `Pillie/scripts/simulator-browser-ax-map.mjs` (`--help` for `--frame` / `--json`).
