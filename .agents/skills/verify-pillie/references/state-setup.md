# Reaching a state without clicking through

Debug builds only. `make qa` / `make ns-mac-qa` build Debug, so all of this works on the simulator.

## Debug deep links

In a flow: `openurl pillie://debug/<path>?lang=en`. The runner accepts the iOS "Open in Pillie?" alert. Add `?lang=<code>` (any `AppLanguage` raw value, e.g. `de`, `it`, `ar`) to set the app language in the same step. Source: `Pillie/Pillie/PillieApp.swift` `handleDebugDeepLink`.

| Path | Lands on |
| --- | --- |
| `/plus-home` | Home, onboarding complete, Plus on. The default starting point. |
| `/plus-app-blocking-setup?terms=hard&expired=0\|1&selected=N` | Onboarding app-blocking step, optional hard-paywall-expired state and a fake app count |
| `/plus-app-blocking-recovery` | The FamilyControls denied/cancelled recovery UI |
| `/onboarding-personalization-intent` | Onboarding pain-points step |
| `/onboarding-personalization-timing` | Onboarding miss-frequency step |
| `/trial-grant` | A fresh reverse trial starting now |
| `/trial-age?days=N` | The current trial aged back N days |
| `/trial-eve-of-break` / `/trial-break-week` | Trial on the eve of, or during, the break week |
| `/trial-activation-hub?state=unconfigured\|partial\|full&terms=hard` | The three app-blocking acceptance states the simulator cannot reach for real |
| `/trial-clear` | No trial grant, one-shot flags cleared |
| `/trial-end-paywall?cohort=blocker&terms=hard&feedback=resolved\|unresolved&success=1&subscriber=1` | Home with the trial-end paywall auto-presenting |
| `/honest-paywall?board=duringTrial\|settingsFree\|trialEndedReturningHard\|trialEndedReturningLegacy` | One paywall board |
| `/update-trial-announcement` | Onboarded free user; the next launch shows the trial announcement |
| `/review-prompt` | Home with the review prompt card eligible |
| `/intervention-seed?count=N` | N fake shield intercepts (the shield itself never shows on a simulator) |
| `/fixed-now?at=<epoch\|ISO8601\|off>` | Pins the app clock. Use it to make calendar ids and "due" state deterministic. |
| `/request-notification-permission` | The system notification prompt |
| `/dump-pending-notifications` | Pending local notifications written to OSLog (pair with `log start` / `log stop`) |
| `/posthog-smoke` / `/error-tracking-smoke` | Analytics and error-tracking smoke events |

## Developer menu scenarios

Home `#developerMenuAvatarButton`, or Settings `#settingsDeveloperMenuRow`, opens the menu. Each row is `#developerScenario.<name>`. Source: `Pillie/Pillie/Services/DebugQA.swift`.

- Pack: `missedRecentDays`, `packComplete`, `marketingCalendar`
- Trial, new user: `trialActive`, `trialEveOfBreak`, `trialMidBreak`, `trialLastDay`, `trialExpiredNewUserBlocker`, `trialExpiredNewUserReminder`, `trialExpiredNewUserSuccess`, `trialExpiredNewUserRollback`, `trialExpiredNewUserReturning`
- Trial, grandfathered: `trialExpiredGrandfatherBlocker`, `trialExpiredGrandfatherReminder`, `trialExpiredGrandfatherReturning`
- Other: `plusSubscriber`, `existingUserTrialAnnouncement`, `reviewPrompt`, `clearTrial`

## Defaults before launch

`defaults KEY TYPE VALUE` then `launch`. Keys: `onboardingStep` (raw `OnboardingFlow.Step` int, `Services/OnboardingFlow.swift`), `pillie.appLanguage` (an `AppLanguage` raw value), `trialInstallHardPaywallCohort` (`pre_cutover` or `post_cutover`), `homeBlockingStatusCardDismissed`.

## Fresh install

`fresh` then `launch` gives first-launch onboarding (Welcome, `#protectionPlanPrimaryCTA` "Get started").

## Not reachable on a simulator

- Real FamilyControls app picking and the shield UI. Authorization reports approved on a simulator (`AppBlockingManager.swift`). Use `/trial-activation-hub`, `selected=N`, and `/intervention-seed` instead.
- DeviceActivity schedules. `PillieDeviceActivityMonitor` never fires on a simulator.
- Real purchases. The scheme uses `Configuration.storekit`. Never tap a purchase CTA in a flow.
- Shake. Use `#shakeTapToConfirmFallback`.
- Remote push. The app only schedules local notifications.
