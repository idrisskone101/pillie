# Onboarding

The first-launch flow from Welcome to Home. Steps are `OnboardingFlow.Step` (`Services/OnboardingFlow.swift`); the live order a fresh install actually walks is `OnboardingFlow.displayOrder` (~221-250), not the switch-case order in `ContentView.swift` (~86-424).

## Sub-features

- `onboarding-welcome` — `ProtectionPlanWelcomeView`, "Get started".
- `onboarding-proof` — `ProtectionPlanEarlyValueProofView`, the drag demo + "Not now" skip.
- `onboarding-pain-points` — `ProtectionPlanDistractionChoicesView` (distraction + desired-outcome, both required).
- `onboarding-miss-frequency` — `ProtectionPlanFailureFrequencyView` (frequency + risk window, both required).
- `onboarding-acquisition-source` — `ProtectionPlanAcquisitionSourceView`, single choice or skip.
- `onboarding-method` — `ProtectionPlanRoutineMethodView`, pill/patch/ring, defaults to pill.
- `onboarding-schedule` — `ProtectionPlanRoutineDetailsView`, cycle position + regimen, has valid defaults.
- `onboarding-reminder-time` — `ProtectionPlanReminderTimeView`; its CTA requests real notification authorization.
- `onboarding-reminder-plan` — `ProtectionPlanDiagnosisView`, an analyze-then-reveal animation before the CTA appears.
- `onboarding-trial-granted` — `TrialGrantedMomentView`. Dead code: unreachable by any real path or debug deep link (see Gotchas).
- `onboarding-app-blocking` — `AppBlockingSetupView`, empty / selected / recovery / locked phases.
- `onboarding-protection-plan-ready` — `ProtectionPlanReadyView`, "Go to Today".
- `onboarding-home-handoff` — lands on `MainTabView` (Today).

## How to get to it (user POV)

- Fresh install. Tap "Get started", then either drag the demo or tap "Not now".
- Answer the two consolidated question screens (pick one distraction + one desired outcome; one miss-frequency + one risk window), then Where did you find Pillie? (or "Not now"), method, schedule, reminder time (allow or deny the real notification prompt), then the reminder-plan reveal.
- Pick apps to pause (or "Not now" to skip blocking) — a real device shows the FamilyControls picker here; the simulator cannot pick real apps (see Gotchas).
- If a valid blocker config saves, "You're all set." → "Go to Today" lands on Home. Skipping blocking goes straight to Home instead.

## Driving it with flows

- `flows/onboarding-walkthrough.flow` — `fresh`, `launch`, then every reachable step to Home with each step's real CTA. `trialGranted` is skipped: it cannot be shown by any path, real or debug (see Gotchas). Reaches the app-blocking "selected" phase via `pillie://debug/plus-app-blocking-setup?selected=N` (FamilyControls tokens cannot be faked any other way on the simulator), then taps that screen's real "Continue".
- `flows/onboarding-app-blocking.flow` — the app-blocking step's empty / selected / recovery phases via `pillie://debug/plus-app-blocking-setup` and `pillie://debug/plus-app-blocking-recovery`, without walking the rest of onboarding first.
- Two other debug deep links land mid-flow without a fresh install: `pillie://debug/onboarding-personalization-intent` (painPoints) and `pillie://debug/onboarding-personalization-timing` (missFrequency) — `PillieApp.swift` ~557-566.
- Unreachable, not covered by either flow, and not a gap in either flow's coverage: `trialGranted` (dead code — see Gotchas), the `.locked` app-blocking phase (needs Plus actually withheld), and the analyzing (pre-reveal) beat of the diagnosis screen (timing-dependent, and the finished plan is the state worth proving).

## Gotchas

- **`welcome`, `productDemo`, and `plusBlockingDemo` in `ContentView.swift`'s switch (~91-129) are dead code.** A fresh install's `onboardingStep` starts at 0, and while it is `< OnboardingFlow.Step.productDemo.rawValue` (2), `ContentView` renders `ProtectionPlanOnboardingShell` instead of that switch (`ContentView.swift:77-84`). The shell owns its own `ProtectionPlanStep` model (`Services/ProtectionPlanOnboarding.swift:78-112`) with only `.welcome` and `.earlyValueProof`, and hands off straight to `.painPoints` (`ContentView.swift:531-536`) — the raw value never reaches 2 or 3. Do not use `WelcomeView.swift` / `ProductDemoMomentView.swift` / `PlusBlockingDemoView.swift`'s identifiers (`productDemoContinueButton`, `plusBlockingDemoContinueButton`) for the real fresh-install path; the real welcome screen is `ProtectionPlanWelcomeView`, and its CTA is the shared `protectionPlanPrimaryCTA`.
- **Most plan-builder screens share two identifiers**, set once in `ProtectionPlanScaffold.swift:198,219`: `protectionPlanPrimaryCTA` (Continue) and `protectionPlanSecondaryCTA` (Skip/Not now, where present). Per-choice rows/chips usually have no id — tap by their exact English label (from the xcstrings key cited in code) unless the screen sets one explicitly, as `ProtectionPlanAcquisitionSourceView.swift:68` does with `acquisitionSource.<rawValue>` (e.g. `acquisitionSource.tiktok`).
- **`trialGranted` cannot be shown at all — not even through its own debug deep link.** `ContentView`'s switch selects on `OnboardingFlow.visibleStep(for: onboardingStep, ...)` (`ContentView.swift:86-90`), and that function unconditionally migrates `.trialGranted` (and `.paywall`, `.freePlanConfirmation`, `.mechanismProof`, and the other retired steps) to `.appBlocking` before returning (`OnboardingFlow.swift:316-326`) — so the switch's `.trialGranted` case (`TrialGrantedMomentView`, `trialGrantedPrimaryCTA`) never runs, no matter what raw value `onboardingStep` holds. `pillie://debug/trial-granted-moment` (`PillieApp.swift:567-573`) sets `onboardingStep` to that raw value anyway, but the very next render migrates it straight past — the deep link's own code comment says as much ("the retired step migrates to app-blocking setup"). It is a same-effect alias for landing on `appBlocking` with the entitlement forced off first, not a way to see the trial-granted screen. Do not put it in a flow expecting `TrialGrantedMomentView` to render.
- **`AppBlockingSetupView` has no accessibility identifier on its primary or skip buttons** — tap by label (`Allow pausing` / `Continue` / `Not now`, from `Localizable.xcstrings`). `isAuthorized` is hardcoded `true` on `#if targetEnvironment(simulator)` in `AppBlockingManager.swift:158-161`, so the picker is never gated on a real permission prompt — but FamilyControls token selection itself cannot happen on the simulator, so the "selected" phase (and the real "Continue" CTA that follows it) is only reachable via `debugSelectionCountOverride`, set through `pillie://debug/plus-app-blocking-setup?selected=N` (`AppBlockingManager.swift:36-40`).
- **The reminder-time CTA ("Continue to notification settings") requests real notification authorization** (`OnboardingReminderCommit.swift`, wired live in `ProtectionPlanReminderTimeView.swift:178-187`) — unlike FamilyControls, this is not simulator-shortcut and shows the real iOS system permission alert on first ask post-`fresh`. The alert's button text ("Allow"/"Don't Allow") is iOS chrome, not Pillie copy — confirm the exact label live before trusting a scripted tap on it.
- The diagnosis screen (`reminderPlan`) holds its CTA back until the plan is "verified" (`ProtectionPlanDiagnosisView.swift:100-119`); wait for `protectionPlanPrimaryCTA` with a longer timeout, not the screen's title text, which is present during the analyzing beat too.
- Coordinates/labels are English (`?lang=en` on every debug deep link, or confirm the simulator's base language before a `fresh` with no deep link).
