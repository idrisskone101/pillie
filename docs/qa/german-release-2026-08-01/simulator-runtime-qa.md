# German simulator runtime QA — 2026-08-01

## Target and method

- Branch: `codex/german-release-quality`
- Build: Debug 2.0.5 (6), Xcode 27.0 (`27A5228h`), iOS Simulator SDK 27.0
- Device: pinned iPhone 17 Pro, iOS 26.2, UDID `124DC75F-0771-4C81-841D-F13655138260`
- DerivedData: `/tmp/PillieDerivedData-codex-4394`
- Runtime locale: app launched with `-AppleLanguages (de) -AppleLocale de_DE`; the simulator OS locale was temporarily changed from `it_IT` to `de_DE` for Apple-owned permission and FamilyActivity UI.
- Inspection: AXe hierarchy before and after interactions plus full-resolution `simctl io` screenshots.
- Text sizes: normal (`medium`) and Accessibility Large complete.

## Normal-size results

| Surface | Result | Evidence |
| --- | --- | --- |
| Today pending, shake confirmation, completed | Pass | `runtime-normal/01-today-pending.png` through `03-today-completed.png` |
| History/calendar | Pass | `runtime-normal/04-history.png` |
| Settings top and lower sections | Pass | `runtime-normal/05-settings-top.png`, `06-settings-bottom.png` |
| New pack confirmation | Pass; correct feminine grammar: “Neue Packung beginnen?” | `runtime-normal/07-new-pack-confirmation.png` |
| Onboarding proof and personalization | Pass | `runtime-normal/08-onboarding-early-proof-1.png` through `10-onboarding-personalization-2.png` |
| Method choices (Pille, Pflaster, Ring) | Pass | `runtime-normal/11-onboarding-method.png` |
| Ring schedule and cycle position | Pass; final copy reads “Aus deiner Auswahl berechnet” | `runtime-normal/12-onboarding-ring-schedule.png` |
| Reminder time, notification prompt, personalized plan | Pass | `runtime-normal/13-onboarding-reminder-time.png` through `15-onboarding-reminder-plan.png` |
| App-Pause setup | Pass | `runtime-normal/16-onboarding-app-pause.png` |
| FamilyActivityPicker | App-owned copy passes. Apple picker categories/search are German, but Apple’s title remains English (“Choose Activities”). | `runtime-normal/17-family-activity-picker.png` |
| Trial status (fully configured) | Pass | `runtime-normal/18-trial-status-full.png` |
| Trial-end blocker paywall | Pass; simulator StoreKit fallback supplies USD prices, while German period copy is correct. | `runtime-normal/19-trial-end-paywall-blocker.png` |
| Trial-decline feedback | Pass; final optional note reads “Deine Antwort ist freiwillig. Du kannst die Frage überspringen und Pillie kostenlos weiter nutzen.” | `runtime-normal/20-trial-decline-feedback.png` |

No normal-size screenshot showed clipped text, overlapping controls, or avoidable wrapping. Large display headlines and explanatory paragraphs wrap intentionally within their containers.

## System-owned and unreachable surfaces

- The FamilyActivityPicker is presented directly with SwiftUI’s `.familyActivityPicker(isPresented:selection:)` in `AppBlockingSetupView` and `BlockedAppsEditor`; Pillie does not supply its title or category labels. The English “Choose Activities” title is therefore confirmed Apple/system-owned. Categories and search placeholder followed the German simulator OS locale.
- The notification permission prompt was verified in German after changing the simulator OS locale; app-only launch arguments do not localize SpringBoard permission UI.
- The simulator did not surface Motion or ATT prompts after targeted permission resets. The packaged app does contain the current German `NSMotionUsageDescription` and `NSUserTrackingUsageDescription`; these remain covered by the bundle-resource contract tests and require real-device prompt proof for complete UI evidence.
- `OnboardingFlow.visibleStep` intentionally maps the retained `.mechanismProof` and `.trialGranted` raw steps to `.appBlocking`. No debug route renders either view. Runtime navigation was therefore bounded at the live App-Pause flow; localized content is covered by `ProtectionPlanOnboardingContentTests` and `TrialGrantedMomentContentTests`.
- Simulator FamilyControls does not provide selectable application tokens. Picker presentation and system-owned copy were verified, but a real-device selection/save is required for end-to-end blocking setup.

## Accessibility Large checkpoint

Accessibility Large QA exercised five layout-sensitive checkpoints. Four exposed regressions; each was corrected, rebuilt, recaptured on the exact screen, and visually re-inspected:

- Today: the dose subtitle and completion CTA initially clipped, and the expanded App-Pause card ran behind the sticky CTA. The final layout moves the primary action into scroll order at accessibility sizes and passes in `01-today-pending.png` and `02-today-scrolled.png`.
- History: “Nicht protokolliert” initially split across narrow mid-word lines. The final accessibility layout stacks the legend and passes in `03-history.png`.
- Settings: the primary title initially split “Einstellung/en”. The final title stays on one line, lower content remains scrollable, and the complete surface passes in `04-settings-top.png` through `06-settings-bottom.png`.
- App-Pause onboarding: the headline necessarily wraps at Accessibility Large, while all explanatory, trial, picker/privacy, and action content remains reachable through the scroll view above the pinned actions. It passes in `07-onboarding-app-pause.png` through `09-onboarding-app-pause-bottom.png`.
- Trial-end paywall: feature pills and side-by-side price cards initially truncated. The final accessibility layout uses one-column feature pills and stacked annual/monthly cards; full prices, the savings badge, reassurance items, Continue Free, Restore, and legal copy remain readable and reachable. It passes in `10-trial-end-paywall.png` and `11-trial-end-paywall-bottom.png`.

The final Accessibility Large evidence contains no clipped German text, overlapping controls, mid-word forced wrapping, or truncated feature/price labels.

## Automated verification

- Final bounded simulator build: pass (`xcodebuild` exit 0).
- Focused German localization/layout tests: 41/41 pass (`/tmp/PillieGermanReleaseFocusedFinal-019fbb8a.xcresult`).
- Italian parity tests: 29/29 pass (`/tmp/PillieItalianParityFinal-019fbb8a.xcresult`).
- Full hosted suite: 744/795 pass (`/tmp/PillieFullReleaseSuite-019fbb8a.xcresult`). The remaining 51 are unrelated stale English-copy assertions and the known hosted-test interaction-feedback crash class; no German runtime/layout regression was identified in that set.

## Simulator state restoration

- Original Pillie data was backed up at `/tmp/pillie-german-qa-data-before.7H7qXl` before clean-install onboarding QA.
- After all final builds and tests, the exact saved `Library` and `Documents` were restored into the current app container while the simulator was shut down. Recursive comparisons before and after the final boot returned no differences.
- The QA-only container state remains recoverable at `/tmp/pillie-german-qa-current-before-restore.2Yi9p4`.
- The final post-test state also remains recoverable at `/tmp/pillie-german-qa-post-tests-before-final-restore.eQUl5B`.
- Final simulator read-back: language `it`, locale `it_IT`, content size `medium`, and restored `onboardingStep` value `16`.
- A normal proof launch without German arguments rendered Italian from the restored data. The authoritative backup was then re-applied after the proof and final tests, so the final container is byte-identical to the pre-QA `Library` and `Documents`. The app was not relaunched afterward; the pinned simulator is booted and free.
