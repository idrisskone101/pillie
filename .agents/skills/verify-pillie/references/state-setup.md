# Reaching a state without clicking through

Debug builds only. `make qa` / `make ns-mac-qa` build Debug, so all of this works on the simulator.

## Debug deep links

In a flow: `openurl pillie://debug/<path>?lang=en`. The runner accepts the iOS "Open in Pillie?" alert. Add `?lang=<code>` (any `AppLanguage` raw value, e.g. `de`, `it`, `ar`) to set the app language in the same step. Source: `Pillie/Pillie/PillieApp.swift` `handleDebugDeepLink`.

| Path | Lands on |
| --- | --- |
| `/plus-home` | Home, onboarding complete, Plus on. The default starting point. |
| `/plus-app-blocking-setup?terms=hard&expired=0\|1&selected=N` | Onboarding app-blocking step, optional hard-paywall-expired state and a fake app count |
| `/plus-app-blocking-recovery` | The FamilyControls denied/cancelled recovery UI |
| `/screen-time-refused?reason=conflict\|cancelled\|none` | Screen Time authorization fails for this launch the way a real iPhone refuses it: `conflict` (default) is another app holding access, `cancelled` is any other refusal, `none` lets the next request succeed |
| `/onboarding-personalization-intent` | Onboarding pain-points step |
| `/onboarding-personalization-timing` | Onboarding miss-frequency step |
| `/trial-grant` | A fresh reverse trial starting now |
| `/trial-age?days=N` | The current trial aged back N days |
| `/trial-eve-of-break` / `/trial-break-week` | Trial on the eve of, or during, the break week |
| `/trial-activation-hub?state=unconfigured\|partial\|full&terms=hard` | A fresh trial with Plus setup at 1/3 (`unconfigured`: reminders only), 2/3 (`partial`: plus blocking), or 3/3 (`full`: plus custom messages, strip hidden). Clears `plusSetupFinished` so the Today setup strip comes back. |
| `/trial-clear` | No trial grant, one-shot flags and `plusSetupFinished` cleared |
| `/trial-end-paywall?terms=soft&cohort=blocker&feedback=resolved\|unresolved&success=1&subscriber=1` | Home with an expired trial, and the trial-end paywall presents without a relaunch (a relaunch drops the expired clock). Default is the hard wall; `terms=soft` is the closable pre-cutover wall with "Continue with free reminders". Same states as the developer menu's `trialExpired*` rows. |
| `/paywall-lifetime?price=%2489.99\|clear` | The honest paywall shows a Lifetime tile at that price, because the RevenueCat Test Store offering has none. Stored in defaults, so it survives relaunch until `price=clear`. Display only: no package backs it. |
| `/trial-end-extend?trigger=cancel\|restore&notifications=on\|off&clear=1` | The hard trial-end wall, risen straight into the one-time extend offer (ENG-172) as after a cancelled Apple sheet or an empty restore. `notifications` overrides the reminder row until relaunch; `clear=1` re-arms the once-ever offer. A $29.99 one-week fixture stands in when RevenueCat serves no extend SKU. |
| `/restore-outcome?result=error\|none\|restored\|clear` | Restore Purchases returns that outcome without calling RevenueCat: `error` is a network failure (`error_category=network`), `none` finds no active purchase, `restored` also turns Plus on, `clear` goes back to real RevenueCat. Lasts until relaunch. |
| `/honest-paywall?board=duringTrial\|settingsFree\|trialEndedReturningHard\|trialEndedReturningLegacy` | One paywall board |
| `/update-trial-announcement` | Onboarded free user; the next launch shows the trial announcement |
| `/review-prompt` | Home with the review prompt card eligible |
| `/intervention-seed?count=N` | N fake shield intercepts (the shield itself never shows on a simulator) |
| `/routine-day?method=patch\|ring&day=N` | Onboarded Plus user on a fresh 21 + 7 patch or ring routine at cycle day N (1 to 28), earlier tasks logged, no start-day grace. Pair with `/fixed-now` to cross days. |
| `/countdown-card` | Gallery of the 16 patch and ring countdown card states |
| `/fixed-now?at=<epoch\|ISO8601\|off>` | Pins the app clock. Use it to make calendar ids and "due" state deterministic. |
| `/request-notification-permission` | The system notification prompt |
| `/notification-complete` | Runs the reminder's Complete action for today (`NotificationManager.completeReminder`), as if tapped while the app is open |
| `/dump-pending-notifications` | Pending local notifications written to OSLog (pair with `log start` / `log stop`) |
| `/posthog-smoke` / `/error-tracking-smoke` | Analytics and error-tracking smoke events |

## Developer menu scenarios

Home `#developerMenuAvatarButton`, or Settings `#settingsDeveloperMenuRow`, opens the menu. Each row is `#developerScenario.<name>`. Source: `Pillie/Pillie/Services/DebugQA.swift`.

- Pack: `missedRecentDays`, `packComplete`, `marketingCalendar`
- Trial, new user: `trialActive`, `trialEveOfBreak`, `trialMidBreak`, `trialLastDay`, `trialExpiredNewUserBlocker`, `trialExpiredNewUserReminder`, `trialExpiredNewUserSuccess`, `trialExpiredNewUserRollback`, `trialExpiredNewUserReturning`
- Trial, grandfathered: `trialExpiredGrandfatherBlocker`, `trialExpiredGrandfatherReminder`, `trialExpiredGrandfatherReturning`
- Other: `plusSubscriber`, `existingUserTrialAnnouncement`, `reviewPrompt`, `clearTrial`

## Defaults before launch

`defaults KEY TYPE VALUE` then `launch`. Keys: `onboardingStep` (raw `OnboardingFlow.Step` int, `Services/OnboardingFlow.swift`), `pillie.appLanguage` (an `AppLanguage` raw value), `trialInstallHardPaywallCohort` (`pre_cutover` or `post_cutover`), `homeBlockingStatusCardDismissed`, `plusSetupFinished` (bool; `true` hides the Today Plus setup strip).

## Fresh install

`fresh` then `launch` gives first-launch onboarding (Welcome, `#protectionPlanPrimaryCTA` "Get started").

## Not reachable on a simulator

- Real FamilyControls app picking and the shield UI. Authorization reports approved on a simulator (`AppBlockingManager.swift`). Use `/trial-activation-hub`, `selected=N`, and `/intervention-seed` instead.
- DeviceActivity schedules. `PillieDeviceActivityMonitor` never fires on a simulator.
- Real purchases. The scheme uses `Configuration.storekit`. Never tap a purchase CTA in a flow.
- Shake. Tap `#shakeConfirmStage` once per shake, or `#shakeTapToConfirmFallback` to finish at once.
- Remote push. The app only schedules local notifications.
