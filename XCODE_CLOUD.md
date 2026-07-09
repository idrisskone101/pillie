# Xcode Cloud CI → TestFlight

On every PR to `main`, Xcode Cloud builds Pillie, runs the test suite, archives it, and
ships it to **TestFlight internal testing** so you can tap-test on your phone before merging.

## How it's wired

- **Workspace, not project.** Xcode Cloud builds the root-level `Pillie.xcworkspace`, which
  references the nested `Pillie/Pillie.xcodeproj`. Xcode Cloud will NOT resolve a bare
  `.xcodeproj` in a subfolder of this monorepo — it looks for the project at the repo root and
  fails with *"Project Pillie.xcodeproj does not exist at the root of the repository."* The
  workspace at the root is what fixes that.
- **The product is bound to the workspace.** A product's project-vs-workspace choice is fixed
  when the product is created. To change it you must *Delete Xcode Cloud Data* and recreate the
  workflow with the **workspace** open (not the `.xcodeproj`).
- **`ci_scripts/` lives at the repo root** (next to the workspace), not next to the project.
- **`Package.resolved` is committed** at `Pillie.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
  Xcode Cloud disables automatic Swift Package resolution and requires this lockfile.
  **Regenerate it whenever you add/update a dependency** (resolve packages in Xcode, then copy
  the project's `Package.resolved` into the workspace path and commit).

## Versioning — two different numbers

- **Build number** (`CURRENT_PROJECT_VERSION`): **automated**. `ci_scripts/ci_pre_xcodebuild.sh`
  stamps every target with Xcode Cloud's `$CI_BUILD_NUMBER`, which auto-increments. The Xcode
  Cloud build-number counter was seeded above the previous App Store max so uploads always
  increase. **Never set this by hand.** All uploads must go through Xcode Cloud so the counter
  stays monotonic.
- **Marketing version** (`MARKETING_VERSION`, e.g. `2.0.3`): **automated via App Store Connect.**
  A live App Store version's "train" closes — Apple rejects new builds under it (ITMS-90186 /
  ITMS-90062). Day-to-day PR builds all stack under the current marketing version fine, so it only
  needs to bump once the current version actually ships. `scripts/ensure-marketing-version.mjs`
  makes that call automatically: it queries App Store Connect (via the `asc` CLI, asccli.sh) and
  bumps every `MARKETING_VERSION` to the next free patch only when the current one is on a closed
  train. The Claude workflow runs it before each run; locally run
  `node scripts/ensure-marketing-version.mjs --profile "Pillie ASO"`. Requires the ASC_KEY_ID /
  ASC_ISSUER_ID / ASC_PRIVATE_KEY_B64 repo secrets in CI. Keep all targets on the same value.

## If a build fails

Read the real error — Xcode Cloud's summaries ("Preparing build for App Store Connect failed")
are vague. Use the build's **Overview** tab, or the **Errors Only** filter on the failing action
(scroll to the bottom `error:` line), or the ITMS email Apple sends.

Check the highest uploaded build with:

```
asc --profile "Pillie ASO" builds list --app 6759352439
```
