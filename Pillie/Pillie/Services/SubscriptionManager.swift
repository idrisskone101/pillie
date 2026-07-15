//
//  SubscriptionManager.swift
//  Pillie
//

import Foundation
import RevenueCat

enum SubscriptionPurchaseError: Error, Equatable, LocalizedError {
    case userCancelled
    case missingPlusEntitlement

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled."
        case .missingPlusEntitlement:
            return "The purchase finished, but Pillie Plus was not activated. Please try again or restore purchases."
        }
    }
}

/// The paid-conversion telemetry that a successful purchase should emit.
enum SubscriptionConversionEvent: Equatable {
    /// A free trial began — its own funnel step, distinct from a paid charge.
    case trialStarted
    /// A real, immediate paid charge.
    case purchaseCompleted
}

/// What a successful `purchase` actually was, so the paywall can record the right
/// (or no) analytics event. The classification is a pure value type so the
/// trial/paid/sandbox decision is unit-testable without RevenueCat.
struct PurchaseOutcome: Equatable {
    /// The active entitlement is in its trial period (`PeriodType.trial`).
    let isTrial: Bool
    /// The transaction came from the StoreKit/RevenueCat sandbox (dev, TestFlight,
    /// App Review). Never a real payer, so it must not inflate paid metrics.
    let isSandbox: Bool

    /// The conversion event to record, or `nil` to suppress it. Sandbox transactions
    /// emit nothing; otherwise a trial and a paid charge are distinct events.
    var conversionEvent: SubscriptionConversionEvent? {
        guard !isSandbox else { return nil }
        return isTrial ? .trialStarted : .purchaseCompleted
    }
}

/// The attribution writes Pillie sends to RevenueCat, as a seam over
/// `Purchases.shared.attribution` so the wiring is testable without configuring
/// the real SDK (issue #197). The live conformance can only exist after
/// `Purchases.configure(...)`, which is what makes AdServices enablement and
/// subscriber-attribute writes safely ordered.
protocol RevenueCatAttributionSetting: AnyObject {
    func setPostHogUserID(_ id: String)
    func setAppsflyerID(_ id: String)
    func setAttributes(_ attributes: [String: String])
    func enableAdServicesAttributionTokenCollection()
}

/// Live adapter over `Purchases.shared.attribution`. Must only be constructed
/// after `Purchases.configure(...)` — `SubscriptionManager.configure()` is the
/// sole construction site.
private final class PurchasesAttributionSink: RevenueCatAttributionSetting {
    func setPostHogUserID(_ id: String) {
        Purchases.shared.attribution.setPostHogUserID(id)
    }

    func setAppsflyerID(_ id: String) {
        Purchases.shared.attribution.setAppsflyerID(id)
    }

    func setAttributes(_ attributes: [String: String]) {
        Purchases.shared.attribution.setAttributes(attributes)
    }

    func enableAdServicesAttributionTokenCollection() {
        Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
    }
}

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    // MARK: - Public State

    /// Plus Access (CONTEXT.md): the single predicate every Plus feature gates
    /// on — Plus entitlement OR active Reverse Trial. Recomputed through
    /// `refreshPlusAccess`, never written directly.
    private(set) var hasPlusAccess = false

    /// The raw RevenueCat `pillie_plus` entitlement. Only purchase/restore
    /// surfaces and paid-conversion analytics read this; feature gates must use
    /// `hasPlusAccess` so a Reverse Trial feels exactly like Plus (ADR 0007).
    private(set) var hasEntitlement = false

    /// The persisted Reverse Trial grant moment, if any (Keychain-backed).
    private(set) var trialGrantDate: Date?

    /// Whether the RevenueCat entitlement state has actually loaded this launch.
    /// `hasEntitlement` starts `false` before the first customer-info fetch, so
    /// the existing-user update grant (#165) must wait for this before deciding —
    /// otherwise a paying subscriber would be misread as free.
    private(set) var hasResolvedEntitlement = false

    private(set) var isLoading = false

    /// Fired whenever Plus Access actually flips (purchase, churn, trial grant,
    /// trial expiry), never on a no-op refresh. Wired at launch to re-plan Smart
    /// Reminders immediately so the change takes effect without waiting for the
    /// next natural reschedule (ADR 0004); blocking reconciles off the same hook.
    /// `@ObservationIgnored` because it is a side-effect hook, not observable UI state.
    @ObservationIgnored
    var onEntitlementChange: ((Bool) -> Void)?

    @ObservationIgnored
    private var trialGrantStore: TrialGrantStoring = KeychainTrialGrantStore()

    /// The live RevenueCat attribution surface, set by `configure()` once
    /// `Purchases.configure(...)` has run and nil before it — which is what
    /// keeps every attribution write ordered after SDK configuration.
    /// Internal (not private) so tests can inject a recorder.
    @ObservationIgnored
    var attributionSink: RevenueCatAttributionSetting?

    // MARK: - Constants

    static let apiKey = "appl_jAqXDkTjrIxXrqrDsPQInTuIsdp"
    nonisolated static let entitlementID = "pillie_plus"
    static let monthlyProductID = "com.idrisskone.pillie.plus.monthly"
    static let annualProductID = "com.idrisskone.pillie.plus.annual"
    private var isConfigured = false

    private override init() {
        super.init()
        trialGrantDate = trialGrantStore.loadGrantDate()
        hasPlusAccess = plusAccessState.hasPlusAccess(calendar: .current, now: Date())
    }

    private var plusAccessState: PlusAccessState {
        PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: trialGrantDate)
    }

    /// Single funnel for every entitlement mutation; Plus Access is re-derived
    /// after every write so the predicate can never be bypassed.
    ///
    /// A raw-entitlement flip fires `onEntitlementChange` even when Plus Access
    /// itself does not move — a mid-trial purchase keeps `hasPlusAccess` true,
    /// but reminders must still replan so the pending day-10/13 trial expiry
    /// warnings cancel (#168).
    private func setEntitlement(_ newValue: Bool) {
        let rawFlipped = hasEntitlement != newValue
        let accessBefore = hasPlusAccess
        hasEntitlement = newValue
        hasResolvedEntitlement = true
        refreshPlusAccess()
        if rawFlipped, hasPlusAccess == accessBefore {
            onEntitlementChange?(hasPlusAccess)
        }
    }

    /// Re-evaluates the Plus Access predicate and fires `onEntitlementChange`
    /// only when the value actually flips, so refreshes that re-confirm the same
    /// state never trigger a redundant reschedule. Called after every entitlement
    /// or trial mutation, and safe to call at any re-evaluation point (launch,
    /// foreground) to catch a trial that expired while the app was closed.
    func refreshPlusAccess(now: Date = Date()) {
        // Refresh the App Group mirror on every re-evaluation, not just flips:
        // the shield side must learn the new valid-until date the moment access
        // state changes (grant, purchase, entitlement resolution), so blocking
        // can self-disable at expiry even if the app never opens again (#167).
        ScreenTimeSharedState.setPlusAccessValidUntil(
            PlusAccessMirror.validUntil(state: plusAccessState, calendar: .current)
        )
        let newValue = plusAccessState.hasPlusAccess(calendar: .current, now: now)
        guard hasPlusAccess != newValue else { return }
        hasPlusAccess = newValue
        onEntitlementChange?(newValue)
    }

    // MARK: - Reverse Trial

    /// Grants the Reverse Trial (ADR 0007): persists the grant moment in the
    /// Keychain and unlocks Plus Access through the same hook a purchase fires.
    /// A no-op when a grant already exists — reinstalls and repeat calls must
    /// never restart the 14-day clock. Returns whether a new grant was written,
    /// so app-blocking setup can fire `trial_granted` exactly once.
    @discardableResult
    func grantReverseTrial(now: Date = Date()) -> Bool {
        guard trialGrantDate == nil else { return false }
        trialGrantStore.saveGrantDate(now)
        trialGrantDate = now
        refreshPlusAccess(now: now)
        return true
    }

    // MARK: - Configure (call once at app launch)

    func configure() {
        guard !isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true

        // Listen for subscription changes
        Purchases.shared.delegate = self

        let sink = PurchasesAttributionSink()
        attributionSink = sink
        applyAttribution(
            to: sink,
            distinctId: AnalyticsManager.shared.distinctId,
            appsFlyerId: AppsFlyerManager.shared.appsFlyerUID,
            acquisitionSource: UserDefaults.standard.string(forKey: PillStore.acquisitionSourceKey)
        )
        Task { await refreshStatus() }
    }

    /// Ties RevenueCat to the in-app analytics person, tags the subscriber with the
    /// coarse acquisition source, and enables standard Apple Search Ads attribution
    /// (issue #197). Setting the PostHog distinct id (`$posthogUserId`) lets
    /// RevenueCat's PostHog integration land server-side subscription events
    /// (renewals, trial→paid conversions) on the same person as the in-app funnel;
    /// the AppsFlyer id joins the same user in AppsFlyer; the `acquisition_source`
    /// attribute lets paid conversions be segmented by source. AdServices token
    /// collection is the standard (no ATT prompt, no IDFA) attribution flavor and
    /// runs once per launch, right after `Purchases.configure(...)` — the SDK
    /// de-dupes token posts across launches. The acquisition source is the value
    /// PillStore persisted during onboarding, so it is applied whenever RevenueCat
    /// configures regardless of whether RevenueCat existed when the user answered.
    func applyAttribution(
        to attribution: RevenueCatAttributionSetting,
        distinctId: String?,
        appsFlyerId: String,
        acquisitionSource: String?
    ) {
        attribution.enableAdServicesAttributionTokenCollection()
        if let distinctId, !distinctId.isEmpty {
            attribution.setPostHogUserID(distinctId)
        }
        if !appsFlyerId.isEmpty {
            attribution.setAppsflyerID(appsFlyerId)
        }
        if let acquisitionSource, !acquisitionSource.isEmpty {
            attribution.setAttributes(["acquisition_source": acquisitionSource])
        }
    }

    /// Forwards the acquisition source to RevenueCat the moment the user commits
    /// it in onboarding (issue #197). Before `configure()` this is a no-op: the
    /// value is persisted by `PillStore` and picked up by the configure-time
    /// attribution pass, so the attribute is set exactly when it becomes known
    /// and never before the SDK exists.
    func recordAcquisitionSource(_ source: AcquisitionSource) {
        attributionSink?.setAttributes(["acquisition_source": source.rawValue])
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        let entitlement = result.customerInfo.entitlements[Self.entitlementID]
        try applyPurchaseResult(
            userCancelled: result.userCancelled,
            isPlusEntitlementActive: entitlement?.isActive == true
        )

        let outcome = PurchaseOutcome(
            isTrial: entitlement?.periodType == .trial,
            isSandbox: entitlement?.isSandbox ?? false
        )
        reportConversionToAppsFlyer(outcome, transaction: result.transaction, product: package.storeProduct)
        return outcome
    }

    /// Persisted set of StoreKit transaction ids already reported to AppsFlyer, so a
    /// purchase is counted exactly once across launches.
    private static let loggedAppsFlyerTxKey = "appsflyer_logged_transaction_ids"

    /// Report a successful purchase/trial to AppsFlyer from the real RevenueCat
    /// completion so revenue is accurate and de-duped. Three guards keep the SKAN
    /// revenue model clean:
    ///   • Sandbox transactions emit nothing (`conversionEvent == nil`).
    ///   • Only a genuine StoreKit transaction counts — renewals arrive via the
    ///     `PurchasesDelegate` and restores via `restore()`, neither of which calls
    ///     this; a re-tap that yields no new transaction has `transaction == nil` and
    ///     is skipped.
    ///   • Each `transactionIdentifier` is logged at most once (persisted), so a
    ///     replayed/duplicate transaction never inflates revenue.
    /// `af_start_trial` maps to the actual trial-began outcome — not the button-tap
    /// `purchase_started` event, which also fires on cancel/failure.
    private func reportConversionToAppsFlyer(
        _ outcome: PurchaseOutcome,
        transaction: StoreTransaction?,
        product: StoreProduct
    ) {
        guard let conversion = outcome.conversionEvent else { return }
        guard let txID = transaction?.transactionIdentifier, !txID.isEmpty else { return }
        guard markTransactionLoggedIfNew(txID) else { return }

        let currency = product.currencyCode ?? "USD"
        switch conversion {
        case .purchaseCompleted:
            AppsFlyerManager.shared.logPurchase(
                revenue: (product.price as NSDecimalNumber).doubleValue,
                currency: currency,
                productId: product.productIdentifier
            )
        case .trialStarted:
            AppsFlyerManager.shared.logStartTrial(
                currency: currency,
                productId: product.productIdentifier
            )
        }
    }

    /// Records `transactionID` and returns `true` the first time it is seen; returns
    /// `false` if it was already reported. Persisted so restores/replays never re-log.
    private func markTransactionLoggedIfNew(_ transactionID: String) -> Bool {
        var ids = Set(UserDefaults.standard.stringArray(forKey: Self.loggedAppsFlyerTxKey) ?? [])
        guard !ids.contains(transactionID) else { return false }
        ids.insert(transactionID)
        UserDefaults.standard.set(Array(ids), forKey: Self.loggedAppsFlyerTxKey)
        return true
    }

    // MARK: - Restore

    func restore() async throws {
        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        setEntitlement(customerInfo.entitlements[Self.entitlementID]?.isActive == true)
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    /// Warm RevenueCat + the offerings cache ahead of the paywall. Called a couple
    /// of screens before the paywall (the diagnosis reveal) so that, by the time the
    /// paywall appears, `fetchOfferings()` returns from cache instead of doing a cold
    /// network round-trip while the user waits on a spinner. Idempotent and safe to
    /// call repeatedly: `configure()` guards itself and RevenueCat caches offerings.
    func prefetchOfferings() {
        configure()
        Task { _ = try? await fetchOfferings() }
    }

    // MARK: - Refresh

    func refreshStatus() async {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
        setEntitlement(customerInfo.entitlements[Self.entitlementID]?.isActive == true)
    }

    #if DEBUG
    func setPlusForTesting(_ isPlus: Bool) {
        setEntitlement(isPlus)
    }

    /// Test seam: swap the Keychain store for an in-memory double and re-sync
    /// trial state from it.
    func setTrialGrantStoreForTesting(_ store: TrialGrantStoring) {
        trialGrantStore = store
        trialGrantDate = store.loadGrantDate()
        refreshPlusAccess()
    }

    /// Debug/demo control (issue #160): overwrite or clear the persisted grant
    /// so a trial can be granted, aged past expiry, or reset on the simulator.
    func debugOverrideTrialGrantDate(_ date: Date?) {
        if let date {
            trialGrantStore.saveGrantDate(date)
        } else {
            trialGrantStore.clearGrantDate()
        }
        trialGrantDate = date
        refreshPlusAccess()
    }
    #endif

    func applyPurchaseResult(userCancelled: Bool, isPlusEntitlementActive: Bool) throws {
        if userCancelled {
            throw SubscriptionPurchaseError.userCancelled
        }

        guard isPlusEntitlementActive else {
            setEntitlement(false)
            throw SubscriptionPurchaseError.missingPlusEntitlement
        }

        setEntitlement(true)
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        Task { @MainActor in
            self.setEntitlement(active)
        }
    }
}
