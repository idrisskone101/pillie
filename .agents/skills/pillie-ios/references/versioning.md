# Versioning

Before merging shippable code, confirm the App Store marketing version is still an open train. A closed train rejects new builds (ITMS-90186 / ITMS-90062).

`scripts/ensure-marketing-version.mjs` asks App Store Connect (via `asc`) whether `MARKETING_VERSION` in `Pillie/Pillie.xcodeproj/project.pbxproj` is shippable. If the train is closed it bumps every `MARKETING_VERSION` entry to the next free patch; otherwise it leaves the version alone.

- `node scripts/ensure-marketing-version.mjs --check` — report only (exit 10 if a bump is needed)
- `node scripts/ensure-marketing-version.mjs --profile "Pillie ASO"` — apply
- CI authenticates from `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY_B64` (+ `ASC_APP_ID`)

Leave `CURRENT_PROJECT_VERSION` alone. Xcode Cloud sets it from `$CI_BUILD_NUMBER` via `ci_scripts/ci_pre_xcodebuild.sh`.

Only set the marketing version by hand for a deliberate minor/major bump (for example `2.0.x` → `2.1.0`). Update **every** `MARKETING_VERSION = ...;` line so the app and the three extensions (DeviceActivityMonitor, ShieldAction, ShieldConfiguration) stay in lockstep.
