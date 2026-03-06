# Pillie — Shipping Phases

## Phase 1: Migrate PillDay Storage to SwiftData

**Goal:** Replace the UserDefaults JSON blob for `PillDay` with a proper SwiftData database. Keep UserDefaults for simple settings (reminder time, pack type, blocked apps).

**Why first:** SwiftData's `ModelActor` gives us concurrency-safe writes, which is required for Phase 5 where a background extension writes data at the same time as the main app. Building on UserDefaults now means rewriting later.

### Steps

- [ ] Add `import SwiftData` to the project
- [ ] Convert `PillDay` from a struct to a `@Model` class
- [ ] Convert `PillPack` from a struct to a `@Model` class with a `@Relationship` to `[PillDay]`
- [ ] Create a `ModelContainer` in `PillieApp.swift` and inject it via `.modelContainer()`
- [ ] Refactor `PillStore` to use `ModelContext` for CRUD instead of manual JSON encode/decode
- [ ] Replace `@Query` in views that list/filter PillDays (HistoryView, CalendarGrid)
- [ ] Keep UserDefaults for: `reminderHour`, `reminderMinute`, `contraceptiveMethod`, `blockedAppIDs`
- [ ] Test: kill app, relaunch, verify data persists
- [ ] Test: mark today as taken, check HistoryView updates reactively

### Files Changed
- `Models/PillDay.swift` — struct → @Model class
- `Models/PillPack.swift` — struct → @Model class
- `Models/PillStore.swift` — major refactor (drop JSON persistence for days/pack)
- `PillieApp.swift` — add ModelContainer
- `Views/Calendar/HistoryView.swift` — use @Query
- `Views/Calendar/CalendarGrid.swift` — use @Query or filtered fetch
- `Views/Home/HomeView.swift` — update references

### Rollback Risk
Low. Data model change is internal, no user-facing API or extension dependencies yet.

---

## Phase 2: Local Notifications

**Goal:** Schedule a daily repeating notification at the user's chosen reminder time. Reschedule when they change the time in settings.

**Why second:** Notifications are the trigger for the entire block→challenge→unblock flow. Everything downstream depends on this.

### Steps

- [ ] Add a `NotificationManager` singleton (or actor) that wraps `UNUserNotificationCenter`
- [ ] Request notification permission during onboarding (after TimeSetupView)
- [ ] Schedule a daily repeating `UNCalendarNotificationTrigger` at `(reminderHour, reminderMinute)`
- [ ] Cancel and reschedule when the user changes their reminder time in SettingsView
- [ ] Set notification content: title, body, sound
- [ ] Add a notification category with an action button ("Mark as Taken") so users can log directly from the notification without opening the app
- [ ] Handle the action in `UNUserNotificationCenterDelegate` — call `store.markTodayAsTaken()`
- [ ] Wire delegate in `PillieApp.swift` via `@UIApplicationDelegateAdaptor` or `.onReceive`
- [ ] Test on real device (notifications don't fire reliably in Simulator)

### Files Created
- `Services/NotificationManager.swift`

### Files Changed
- `PillieApp.swift` — set notification delegate, request permission on first launch
- `Views/Onboarding/TimeSetupView.swift` — trigger permission request
- `Views/Settings/SettingsView.swift` — reschedule on time change

### Rollback Risk
Low. Notifications are additive, no existing behavior changes.

---

## Phase 3: Apply for FamilyControls Entitlement

**Goal:** Get Apple's approval to use the Screen Time API in your app.

**Why third:** This is a human-in-the-loop step with Apple that can take days/weeks. Start it early so it doesn't block Phase 5.

### Steps

- [ ] Log in to [developer.apple.com](https://developer.apple.com)
- [ ] Go to Certificates, Identifiers & Profiles → Identifiers → your app ID
- [ ] Enable the "Family Controls" capability
- [ ] Submit the request form explaining your use case:
  - "Pillie is a contraceptive pill reminder app. We use Screen Time to block user-selected apps until they confirm they've taken their daily pill. This creates accountability and improves medication adherence."
- [ ] Wait for Apple approval (typically 1-5 business days, can take longer)
- [ ] Once approved, add the entitlement to your Xcode project:
  - Target → Signing & Capabilities → + Capability → Family Controls
- [ ] Also add: App Groups capability (needed for shared data between app and extensions)
  - Group name: `group.com.yourteam.Pillie`

### Files Changed
- `Pillie.entitlements` — new entitlements file with FamilyControls + App Groups
- Xcode project settings

### Rollback Risk
None. This is configuration only.

---

## Phase 4: Replace Mockup App Picker with FamilyActivityPicker

**Goal:** Replace the hardcoded `BlockableApp` list with Apple's real `FamilyActivityPicker`, which lets users select actual apps on their device.

**Why fourth:** Depends on Phase 3 entitlement being approved.

### Steps

- [ ] Replace `BlockableApp` model with a wrapper around `FamilyActivitySelection`
- [ ] Replace the hardcoded app list in `AppBlockingSetupView` with `FamilyActivityPicker`
- [ ] Store the `FamilyActivitySelection` in a shared App Group container (so extensions can read it)
  - Encode to JSON in `UserDefaults(suiteName: "group.com.yourteam.Pillie")`
  - Or use a shared SwiftData container
- [ ] Request `AuthorizationCenter.shared.requestAuthorization(for: .individual)` during onboarding
- [ ] Update SettingsView to allow changing app selection after onboarding
- [ ] Remove `BlockableApp.swift` (no longer needed)
- [ ] Update `PillStore.blockedAppIDs` — replace `[String]` with serialized `FamilyActivitySelection`

### Files Deleted
- `Models/BlockableApp.swift`

### Files Changed
- `Views/Onboarding/AppBlockingSetupView.swift` — major rewrite
- `Models/PillStore.swift` — change blockedAppIDs type
- `Views/Settings/SettingsView.swift` — add "Manage blocked apps" option

### Rollback Risk
Medium. Changes the onboarding flow and data model for blocked apps.

---

## Phase 5: DeviceActivity Monitor + Shield Extensions

**Goal:** Add the two extension targets that actually block and shield apps. Wire the notification→block→challenge→unblock flow.

**Why fifth:** This is the core differentiator of Pillie. Depends on Phases 2 (notifications), 3 (entitlement), and 4 (real app selection).

### Architecture

```
Pillie.app (main app)
├── PillieMonitor (Device Activity Monitor Extension)
│   └── Activates/deactivates app shields on schedule
├── PillieShield (Shield Configuration Extension)
│   └── Customizes the blocking screen UI
└── Shared App Group (group.com.yourteam.Pillie)
    └── Stores FamilyActivitySelection + pill taken status
```

### Steps

- [ ] In Xcode: File → New → Target → Device Activity Monitor Extension → "PillieMonitor"
- [ ] In Xcode: File → New → Target → Shield Configuration Extension → "PillieShield"
- [ ] Add both extensions to the same App Group
- [ ] Implement `PillieMonitor: DeviceActivityMonitor`
  - `intervalDidStart()` — read saved app tokens, apply `ManagedSettingsStore.shield.applications`
  - `intervalDidEnd()` — optionally auto-unblock if pill was taken
- [ ] Implement `PillieShield: ShieldConfigurationDataSource`
  - Custom title: "Take your pill first!"
  - Custom subtitle explaining what to do
  - Primary button: "Open Pillie" (deep link back to app)
  - Style with Pillie brand colors
- [ ] Create `BlockingManager` service in main app:
  - `scheduleBlocking(at hour: Int, minute: Int)` — sets up `DeviceActivityCenter` schedule
  - `unblockApps()` — clears `ManagedSettingsStore.shield.applications`
  - `isCurrentlyBlocking: Bool` — check shield state
- [ ] Wire into main app flow:
  - When user taps "Mark as Taken" → call `BlockingManager.unblockApps()`
  - On app launch, check if today is already taken → don't block
  - On notification fire → DeviceActivity schedule starts → apps block
- [ ] Store shared state in App Group UserDefaults:
  - `isTodayTaken: Bool` (so monitor extension can check)
  - `FamilyActivitySelection` (so monitor extension knows which apps)
- [ ] Test on real device only (Screen Time doesn't work in Simulator)

### Files Created
- `PillieMonitor/PillieMonitor.swift` (new extension target)
- `PillieMonitor/Info.plist`
- `PillieShield/PillieShield.swift` (new extension target)
- `PillieShield/Info.plist`
- `Services/BlockingManager.swift`
- `Shared/AppGroupConstants.swift` (shared keys/group ID)

### Files Changed
- `PillieApp.swift` — initialize BlockingManager
- `Models/PillStore.swift` — markTodayAsTaken() also calls BlockingManager.unblockApps()
- `Views/Home/HomeView.swift` — "Take Pill" button triggers unblock
- Xcode project — 2 new targets, App Group entitlements on all 3 targets

### Rollback Risk
High. Multiple targets, entitlements, shared state. Test thoroughly on device.

---

## Phase 6: The Challenge Screen

**Goal:** When the user opens Pillie from the shield or notification, present a challenge they must complete before apps unblock. This is the "accountability" moment.

**Why sixth:** The blocking flow from Phase 5 must work first. The challenge is the UX layer on top.

### Possible Challenge Types
- **Simple confirmation** — "Slide to confirm you took your pill" (least friction)
- **Photo verification** — Take a photo of the pill/pack (most accountability)
- **Knowledge check** — "Which pill number are you on today?" (gamified)
- **Timer hold** — Hold a button for 5 seconds (prevents absent-minded taps)

### Steps

- [ ] Design the challenge screen UI
- [ ] Create `ChallengeView.swift` — presented modally when app opens and pill isn't taken
- [ ] On challenge completion: call `store.markTodayAsTaken()` + `BlockingManager.unblockApps()`
- [ ] Add a deep link URL scheme (`pillie://take-pill`) so the Shield's "Open Pillie" button lands directly on the challenge
- [ ] Register URL scheme in Info.plist and handle in PillieApp.swift via `.onOpenURL`
- [ ] Add celebration animation after successful challenge (confetti, haptic, etc.)

### Files Created
- `Views/Challenge/ChallengeView.swift`

### Files Changed
- `PillieApp.swift` — handle deep link, present challenge
- `ContentView.swift` — check if challenge needed on appear
- `Info.plist` — URL scheme registration

### Rollback Risk
Low. Additive UI, doesn't change the blocking infrastructure.

---

## Phase 7: RevenueCat + Paywall

**Goal:** Add a premium tier with RevenueCat for subscription management.

**Why last:** Get the core experience right first. Monetize once you've validated the product.

### Suggested Free vs Pro Split
| Feature | Free | Pro |
|---|---|---|
| Pill tracking + calendar | Yes | Yes |
| Daily reminders | Yes | Yes |
| App blocking (3 apps) | Yes | Yes |
| Unlimited app blocking | No | Yes |
| Custom challenge types | No | Yes |
| Streak statistics | Basic | Detailed |
| Export data | No | Yes |

### Steps

- [ ] Create RevenueCat account at revenuecat.com
- [ ] Create App Store Connect app + In-App Purchase products
  - e.g., `pillie_pro_monthly` ($2.99/mo), `pillie_pro_yearly` ($19.99/yr)
- [ ] In RevenueCat dashboard: link App Store Connect, create Entitlements + Offerings
- [ ] Add RevenueCat SDK via Swift Package Manager
  - Package URL: `https://github.com/RevenueCat/purchases-ios.git`
- [ ] Configure at app launch: `Purchases.configure(withAPIKey: "your_key")`
- [ ] Create `PaywallView.swift` — show pricing, features, subscribe button
- [ ] Create `PurchaseManager` service:
  - `isPro: Bool` — check `CustomerInfo.entitlements["pro"]?.isActive`
  - `purchase(package:)` — trigger purchase flow
  - `restore()` — restore previous purchases
- [ ] Gate premium features behind `PurchaseManager.isPro`
- [ ] Add "Restore Purchases" button in SettingsView (App Store requirement)
- [ ] Add paywall trigger points (when user tries to add 4th blocked app, etc.)
- [ ] Test with StoreKit Configuration file in Xcode (local testing without real purchases)

### Files Created
- `Services/PurchaseManager.swift`
- `Views/Paywall/PaywallView.swift`
- `StoreKit/PillieProducts.storekit` (testing configuration)

### Files Changed
- `PillieApp.swift` — configure RevenueCat
- `Views/Settings/SettingsView.swift` — add subscription management + restore
- `Views/Onboarding/AppBlockingSetupView.swift` — gate unlimited apps
- Various views — check `isPro` for premium features

### Rollback Risk
Low. RevenueCat is additive. Free features continue working if removed.

---

## Quick Reference: Dependencies

```
Phase 1 (SwiftData) ──────┐
                           ├──→ Phase 5 (Extensions)──→ Phase 6 (Challenge)
Phase 2 (Notifications) ──┤
                           │
Phase 3 (Entitlement) ─────┤
                           │
Phase 4 (App Picker) ──────┘

Phase 7 (RevenueCat) — independent, do anytime after Phase 1
```

Phases 1, 2, and 3 can be done in parallel.
Phase 4 depends on Phase 3.
Phase 5 depends on Phases 1-4.
Phase 6 depends on Phase 5.
Phase 7 is independent.
