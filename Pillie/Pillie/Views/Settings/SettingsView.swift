//
//  SettingsView.swift
//  Pillie
//

import SwiftUI
import StoreKit
import FamilyControls

struct SettingsView: View {
    @Environment(PillStore.self) var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showTimeEditor = false
    @State private var showIntervalEditor = false
    @State private var showRetryLimitEditor = false
    @State private var showLastCallEditor = false
    @State private var showRefillReminderEditor = false
    @State private var showProtocolEditor = false
    @State private var showCycleDayEditor = false
    @State private var showBlockedAppsEditor = false
    @State private var showBlockingSnoozeEditor = false
    @State private var showBlockingUpsell = false
    @State private var showSmartRemindersUpsell = false
    @State private var showCustomRemindersEditor = false
    @State private var showCustomRemindersUpsell = false
    @State private var showPaywall = false
    @State private var showManageSubscription = false
    @State private var showOpenLineMailFallback = false
    #if DEBUG
    @State private var showDeveloperMenu = false
    #endif

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PrimaryTitleAnchor(
                    title: PillieLocalization.string(
                        "settings.navigation.title",
                        locale: locale
                    ),
                    titleFont: .pillieExtraBold(36),
                    showsAccessorySlot: true,
                    accessory: nil
                )
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // MARK: - My Pillie
                sectionHeader(PillieLocalization.string(
                    "settings.section.my_pillie",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                settingsCard {
                    Button {
                        openSettingSheet { showProtocolEditor = true }
                        ProductAnalyticsTelemetry.live.protocolSettingsOpened()
                    } label: {
                        settingsRow(
                            PillieLocalization.string("settings.method.title", locale: locale),
                            value: protocolSummary
                        )
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        openSettingSheet { showTimeEditor = true }
                        ProductAnalyticsTelemetry.live.reminderTimeSettingsOpened()
                    } label: {
                        settingsRow(
                            PillieLocalization.string(
                                "settings.reminder_time.title",
                                locale: locale
                            ),
                            value: SettingsPresentation.time(
                                hour: store.reminderHour,
                                minute: store.reminderMinute,
                                locale: locale
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    divider
                    if SubscriptionManager.shared.hasPlusAccess {
                        Button {
                            openSettingSheet { showCustomRemindersEditor = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.custom_messages.title",
                                locale: locale
                            ), value: reminderMessagesSummary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            openSettingSheet { showCustomRemindersUpsell = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.custom_messages.title",
                                locale: locale
                            ), value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showCustomRemindersUpsell) {
                            PlusUpsellSheet.customReminders()
                                .presentationDetents([.height(PlusUpsellSheet.compactPresentationHeight)])
                                .presentationDragIndicator(.hidden)
                                .presentationBackground(PillieTheme.bg)
                        }
                    }
                    if store.pack.method != .ring {
                        divider
                        Button {
                            openSettingSheet { showRefillReminderEditor = true }
                            ProductAnalyticsTelemetry.live.supplyReminderSettingsOpened()
                        } label: {
                            settingsRow(supplyReminderTitle, value: supplyReminderValue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // MARK: - Smart Notifications
                sectionHeader(PillieLocalization.string(
                    "settings.section.reminders",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.12))

                settingsCard {
                    if SubscriptionManager.shared.hasPlusAccess {
                        Button {
                            openSettingSheet { showIntervalEditor = true }
                            ProductAnalyticsTelemetry.live.autoReminderIntervalSettingsOpened()
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.followup.interval_title",
                                locale: locale
                            ), value: SettingsPresentation.interval(
                                minutes: store.autoReminderIntervalMinutes,
                                locale: locale
                            ))
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            openSettingSheet { showRetryLimitEditor = true }
                            ProductAnalyticsTelemetry.live.autoReminderRetryLimitSettingsOpened()
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.followup.retry_limit_title",
                                locale: locale
                            ), value: store.autoReminderRetryLimit.formatted(.number.locale(locale)))
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            openSettingSheet { showLastCallEditor = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.final_reminder.title",
                                locale: locale
                            ), value: store.lastCallReminderEnabled
                                ? SettingsPresentation.time(
                                    hour: store.lastCallReminderHour,
                                    minute: store.lastCallReminderMinute,
                                    locale: locale
                                )
                                : PillieLocalization.string("global.status.off", locale: locale))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            openSettingSheet { showSmartRemindersUpsell = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.followup.interval_title",
                                locale: locale
                            ), value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            openSettingSheet { showSmartRemindersUpsell = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.followup.retry_limit_title",
                                locale: locale
                            ), value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            openSettingSheet { showSmartRemindersUpsell = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.final_reminder.title",
                                locale: locale
                            ), value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showSmartRemindersUpsell) {
                            PlusUpsellSheet.smartReminders()
                                .presentationDetents([.height(PlusUpsellSheet.compactPresentationHeight)])
                                .presentationDragIndicator(.hidden)
                                .presentationBackground(PillieTheme.bg)
                        }
                    }
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.12))

                // MARK: - Cycle
                sectionHeader(PillieLocalization.string(
                    "settings.section.cycle",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                settingsCard {
                    Button {
                        openSettingSheet { showCycleDayEditor = true }
                        ProductAnalyticsTelemetry.live.cycleDaySettingsOpened()
                    } label: {
                        settingsRow(PillieLocalization.string(
                            "settings.cycle_day.title",
                            locale: locale
                        ), value: SettingsPresentation.cycleDay(
                            day: store.currentDayIndex + 1,
                            total: store.pack.cycleLength,
                            locale: locale
                        ))
                    }
                    .buttonStyle(.plain)
                    divider
                    cycleTransitionNoticeToggleRow
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.15))

                // MARK: - Blocking
                sectionHeader(PillieLocalization.string(
                    "settings.section.blocking",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                settingsCard {
                    if SubscriptionManager.shared.hasPlusAccess {
                        Button {
                            openSensitiveSetting { showBlockedAppsEditor = true }
                            ProductAnalyticsTelemetry.live.blockedAppsSettingsOpened(
                                hasSelection: AppBlockingManager.shared.hasAppsSelected
                            )
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.blocked_apps.title",
                                locale: locale
                            ), value: blockingStatusSummary)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            openSettingSheet { showBlockingSnoozeEditor = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.blocking.snooze_title",
                                locale: locale
                            ), value: SettingsPresentation.blockingSnoozeInterval(
                                minutes: store.blockingSnoozeIntervalMinutes,
                                locale: locale
                            ))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            openSensitiveSetting { showBlockingUpsell = true }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.blocked_apps.title",
                                locale: locale
                            ), value: "Pillie+", valueColor: PillieTheme.coral, showLock: true)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showBlockingUpsell) {
                            PlusUpsellSheet.appBlocking(
                                action: store.dueAction(on: store.today),
                                method: store.pack.method
                            )
                                .presentationDetents([.height(PlusUpsellSheet.compactPresentationHeight)])
                                .presentationDragIndicator(.hidden)
                                .presentationBackground(PillieTheme.bg)
                        }
                    }
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.2))

                // MARK: - Account
                sectionHeader(PillieLocalization.string(
                    "settings.section.account",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.2))

                settingsCard {
                    Button {
                        openSensitiveSetting {
                            if SubscriptionManager.shared.hasEntitlement {
                                showManageSubscription = true
                            } else {
                                showPaywall = true
                            }
                        }
                        ProductAnalyticsTelemetry.live.subscriptionSettingsOpened()
                    } label: {
                        settingsRow(
                            PillieLocalization.string("settings.subscription.title", locale: locale),
                            value: subscriptionRowValue,
                            valueColor: subscriptionRowValueColor
                        )
                    }
                    .buttonStyle(.plain)
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                // MARK: - Support (Open Line, #152 / #153)
                // Always-available, identical for free and Plus. The warm label is
                // UI-only copy; the mailto subject and telemetry name are stable
                // contracts owned by `OpenLine` and the telemetry service.
                sectionHeader(PillieLocalization.string(
                    "settings.section.support",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                settingsCard {
                    Button {
                        openMailOrFallback(OpenLine.mailURL(for: .suggestion, locale: locale))
                        ProductAnalyticsTelemetry.live.openLineSuggestionTapped()
                    } label: {
                        settingsRow(PillieLocalization.string(
                            "settings.support.suggestion",
                            locale: locale
                        ), value: "")
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        // Diagnostics are gathered live here and injected as plain
                        // values; `OpenLine` composes a deterministic body that
                        // carries device/app info only, never routine data.
                        openMailOrFallback(OpenLine.mailURL(
                            for: .issueReport(.current()),
                            locale: locale
                        ))
                        ProductAnalyticsTelemetry.live.openLineIssueReportTapped()
                    } label: {
                        settingsRow(PillieLocalization.string(
                            "settings.support.issue_report",
                            locale: locale
                        ), value: "")
                    }
                    .buttonStyle(.plain)
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                #if DEBUG
                sectionHeader("DEVELOPER")
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                settingsCard {
                    Button {
                        showDeveloperMenu = true
                    } label: {
                        settingsRow("Jump to a QA state", value: "Simulator only")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settingsDeveloperMenuRow")
                }
                .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                .sheet(isPresented: $showDeveloperMenu) {
                    DeveloperMenuView()
                }
                #endif

                // Handwriting accent
                Text(PillieLocalization.string("today.greeting", locale: locale))
                    .font(.pillieHandwriting())
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .rotationEffect(.degrees(-2))
                    .padding(.top, 8)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
            .padding(.top, PillieTheme.scrollTopPadding)
            .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .sheet(isPresented: $showTimeEditor) {
            ReminderTimeEditor(store: store)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showIntervalEditor) {
            AutoReminderIntervalEditor(store: store)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showRetryLimitEditor) {
            AutoReminderRetryLimitEditor(store: store)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showLastCallEditor) {
            LastCallReminderEditor(store: store)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showRefillReminderEditor) {
            RefillReminderThresholdEditor(store: store)
                .presentationDetents([.height(410)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showProtocolEditor) {
            ProtocolEditor(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCycleDayEditor) {
            CycleDayEditor(store: store)
                .presentationDetents([
                    dynamicTypeSize.isAccessibilitySize ? .large : .height(400)
                ])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showBlockedAppsEditor) {
            BlockedAppsEditor()
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showBlockingSnoozeEditor) {
            BlockingSnoozeIntervalEditor(store: store)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .sheet(isPresented: $showCustomRemindersEditor) {
            CustomReminderMessagesEditor(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                paywallSurface: .settingsSubscription,
                onBack: { showPaywall = false },
                onContinue: { showPaywall = false },
                onSkip: { showPaywall = false }
            )
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert(PillieLocalization.string(
            "support.mail_failed.title",
            locale: locale
        ), isPresented: $showOpenLineMailFallback) {
            Button(OpenLine.MailFallback.addressToCopy) {
                UIPasteboard.general.string = OpenLine.MailFallback.addressToCopy
            }
            Button(PillieLocalization.string(
                "global.action.close",
                locale: locale
            ), role: .cancel) {}
        } message: {
            Text(PillieLocalization.formatted(
                "support.mail_failed.body",
                locale: locale,
                arguments: OpenLine.MailFallback.addressToCopy
            ))
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pillieCaptionMedium())
            .foregroundStyle(PillieTheme.textMuted)
            .tracking(2)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(PillieTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    private func openSettingSheet(_ update: () -> Void) {
        let response = settingsFeedback.openRow(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            update()
        }
    }

    private func openSensitiveSetting(_ update: () -> Void) {
        let response = settingsFeedback.sensitiveOrDestructiveChange(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            update()
        }
    }

    /// The Open Line's no-silent-no-op guarantee (#155): open the composer when
    /// the device can route the mailto, otherwise present the copy-address
    /// fallback alert — including when URL composition itself returned `nil`.
    private func openMailOrFallback(_ mailURL: URL?) {
        guard let mailURL else {
            showOpenLineMailFallback = true
            return
        }
        openURL(mailURL) { accepted in
            if !accepted {
                showOpenLineMailFallback = true
            }
        }
    }

    @ViewBuilder
    private func settingsRow(_ label: String, value: String, valueColor: Color = PillieTheme.textMuted, showChevron: Bool = true, showLock: Bool = false) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.pillieSubtitleBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !value.isEmpty {
                        Text(value)
                            .font(.pillie(15, weight: .regular))
                            .foregroundStyle(valueColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        } else {
            HStack(spacing: 8) {
                Text(label)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                if showLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                }

                if !value.isEmpty {
                    Text(value)
                        .font(.pillie(15, weight: .regular))
                        .foregroundStyle(valueColor)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PillieTheme.sage.opacity(0.3))
            .frame(height: 0.5)
            .padding(.leading, 20)
    }

    /// Free Cycle Transition Notice toggle (#123). Default ON. Not a Pillie+ perk, so it
    /// has no lock and is shown to every user.
    private var cycleTransitionNoticeToggleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PillieLocalization.string("settings.break_notice.title", locale: locale))
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(PillieLocalization.string("settings.break_notice.body", locale: locale))
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { store.cycleTransitionNoticeEnabled },
                set: { ScheduleCriticalSettingChange.saveCycleTransitionNoticeEnabled(store: store, enabled: $0) }
            ))
                .labelsHidden()
                .tint(PillieTheme.coral)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    /// The Subscription row's value. `hasEntitlement` is deliberately false
    /// during a Reverse Trial (only `hasPlusAccess` includes it), so trial
    /// users need their own label instead of a misleading "Free Plan".
    private var subscriptionRowValue: String {
        let manager = SubscriptionManager.shared
        if manager.hasEntitlement { return "Pillie Plus" }
        if manager.hasPlusAccess {
            return PillieLocalization.string(
                "trial.status.active_short",
                table: "Commerce",
                locale: locale
            )
        }
        return PillieLocalization.string("global.status.free", locale: locale)
    }

    private var subscriptionRowValueColor: Color {
        SubscriptionManager.shared.hasPlusAccess ? PillieTheme.coral : PillieTheme.textPrimary
    }

    private var blockingStatusSummary: String {
        PillieLocalization.string(
            AppBlockingManager.shared.isEffectivelyOn ? "global.status.on" : "global.status.off",
            locale: locale
        )
    }

    private var reminderMessagesSummary: String {
        let hasCustom = [
            store.customDueReminderTitle,
            store.customDueReminderBody,
            store.customRetryReminderTitle,
            store.customRetryReminderBody
        ].contains { CustomReminderCopy.isCustomized($0) }
        return SettingsPresentation.reminderMessagesSummary(
            hasCustom: hasCustom,
            locale: locale
        )
    }

    private var protocolSummary: String {
        switch store.pack.method {
        case .pill:
            return "\(store.pack.method.localizedTitle(locale: locale)) (\(store.pack.pillRegimen.localizedRoutineDisplayName(locale: locale)))"
        case .patch:
            return store.pack.method.localizedTitle(locale: locale)
        case .ring:
            return store.pack.method.localizedTitle(locale: locale)
        }
    }

    private var supplyReminderTitle: String {
        SettingsPresentation.supplyReminderTitle(
            method: store.pack.method,
            locale: locale
        )
    }

    private var supplyReminderValue: String {
        switch store.pack.method {
        case .patch:
            return store.patchRestockReminderThresholdPatches.formatted(.number.locale(locale))
        case .pill, .ring:
            return store.refillReminderThresholdDays.formatted(.number.locale(locale))
        }
    }
}

// MARK: - Protocol Editor

private struct ProtocolEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var selectedMethod: ContraceptiveMethod = .pill
    @State private var selectedRegimen: PillPack.PillRegimenPreset = .twentyOneSeven
    @State private var customActiveDaysText: String = "21"
    @State private var customBreakDaysText: String = "7"
    @State private var selectedCycleDay: Int = 1
    @State private var showResetConfirmation = false

    private let settingsFeedback = SettingsInteractionFeedback()

    private var customActiveDays: Int {
        let raw = Int(customActiveDaysText) ?? 21
        return min(max(raw, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
    }

    private var customBreakDays: Int {
        let raw = Int(customBreakDaysText) ?? 7
        return min(max(raw, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
    }

    private var cycleLength: Int {
        switch selectedMethod {
        case .pill:
            if selectedRegimen == .custom {
                return customActiveDays + customBreakDays
            }
            return selectedRegimen.cycleLength
        case .patch, .ring:
            return 28
        }
    }

    private var resetConfirmation: ScheduleCriticalSettingChange.Confirmation {
        ScheduleCriticalSettingChange.confirmation(
            cycleDay: selectedCycleDay,
            locale: locale
        )
    }

    var body: some View {
        let protocolPresentation = ProtocolEditorPresentation.localized(
            method: selectedMethod,
            locale: locale
        )

        VStack(spacing: 0) {
            SettingsSheetHeader(title: PillieLocalization.string(
                "settings.schedule.title",
                locale: locale
            ))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(PillieLocalization.string("settings.method.title", locale: locale))
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    Picker(PillieLocalization.string(
                        "settings.method.title",
                        locale: locale
                    ), selection: $selectedMethod) {
                        ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                            Text(method.localizedTitle(locale: locale)).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedMethod == .pill {
                        Text(PillieLocalization.string("settings.regimen.title", locale: locale))
                            .font(.pillieCaptionMedium())
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(2)

                        VStack(spacing: 10) {
                            ForEach(PillPack.PillRegimenPreset.allCases, id: \.rawValue) { regimen in
                                Button {
                                    selectedRegimen = regimen
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(regimen.localizedRoutineDisplayName(locale: locale))
                                                .font(.pillieBodyBold())
                                                .foregroundStyle(PillieTheme.textPrimary)
                                            Text(regimen.localizedScheduleSubtitle(locale: locale))
                                                .font(.pillieBody())
                                                .foregroundStyle(PillieTheme.textMuted)
                                        }
                                        Spacer()
                                        Image(systemName: selectedRegimen == regimen ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedRegimen == regimen ? PillieTheme.coral : PillieTheme.textMuted)
                                    }
                                    .padding(14)
                                    .background(PillieTheme.cardWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                                            .stroke(PillieTheme.sageHalf, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if selectedRegimen == .custom {
                            HStack(spacing: 12) {
                                customInputCard(
                                    title: protocolPresentation.customDayLabels[0],
                                    text: $customActiveDaysText
                                )
                                customInputCard(
                                    title: protocolPresentation.customDayLabels[1],
                                    text: $customBreakDaysText
                                )
                            }
                        }
                    } else {
                        Text(PillieLocalization.string("settings.schedule.title", locale: locale))
                            .font(.pillieCaptionMedium())
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(2)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(protocolPresentation.scheduleTitle)
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.8)

                            ForEach(protocolPresentation.scheduleLines, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•")
                                        .accessibilityHidden(true)
                                    Text(line)
                                        .font(.pillieBody())
                                        .foregroundStyle(PillieTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PillieTheme.cardWhite)
                            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
                            )
                    }

                    Text(PillieLocalization.string("settings.cycle_day.title", locale: locale))
                        .font(.pillieCaptionMedium())
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsPresentation.cycleDay(
                            day: selectedCycleDay,
                            total: cycleLength,
                            locale: locale
                        ))
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)

                        Stepper(value: $selectedCycleDay, in: 1...max(1, cycleLength)) {
                            Text(PillieLocalization.string(
                                "settings.cycle_day.adjust",
                                locale: locale
                            ))
                                .font(.pillieBody())
                                .foregroundStyle(PillieTheme.textMuted)
                        }

                        Text(PillieLocalization.string(
                            "settings.cycle_day.history_note",
                            locale: locale
                        ))
                            .font(.pillieCaption())
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .padding(16)
                    .background(PillieTheme.cardWhite)
                    .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                            .stroke(PillieTheme.sageHalf, lineWidth: 1)
                    )
                }
                .padding(20)
            }

            VStack(spacing: 12) {
                Button {
                    showResetConfirmation = true
                } label: {
                    Text(PillieLocalization.string("global.action.save", locale: locale))
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    ProductAnalyticsTelemetry.live.protocolChangeCancelled()
                    dismiss()
                } label: {
                    Text(PillieLocalization.string("global.action.cancel", locale: locale))
                }
                .buttonStyle(.pillieSecondary)
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 20)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .alert(resetConfirmation.title, isPresented: $showResetConfirmation) {
            Button(resetConfirmation.cancelTitle, role: .cancel) { }
            Button(resetConfirmation.confirmTitle, role: .destructive) {
                settingsFeedback.sensitiveOrDestructiveChange(accessibilityReduceMotion: accessibilityReduceMotion)
                store.resetAndStartFresh(
                    method: selectedMethod,
                    regimen: selectedMethod == .pill ? selectedRegimen : .twentyOneSeven,
                    customActiveDays: selectedMethod == .pill && selectedRegimen == .custom ? customActiveDays : nil,
                    customBreakDays: selectedMethod == .pill && selectedRegimen == .custom ? customBreakDays : nil,
                    cycleDay: min(max(1, selectedCycleDay), cycleLength)
                )
                ProductAnalyticsTelemetry.live.protocolChangeSaved()
                dismiss()
            }
        } message: {
            Text(resetConfirmation.body)
        }
        .onAppear(perform: seedFromStore)
        .onChange(of: selectedMethod) { _, _ in clampCycleDay() }
        .onChange(of: selectedRegimen) { _, _ in clampCycleDay() }
        .onChange(of: customActiveDaysText) { _, _ in clampCycleDay() }
        .onChange(of: customBreakDaysText) { _, _ in clampCycleDay() }
    }

    private func customInputCard(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(PillieTheme.cardWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PillieTheme.sageHalf, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func seedFromStore() {
        selectedMethod = store.pack.method
        selectedRegimen = store.pack.pillRegimen
        customActiveDaysText = "\(store.pack.customActiveDays ?? 21)"
        customBreakDaysText = "\(store.pack.customBreakDays ?? 7)"
        selectedCycleDay = store.currentDayIndex + 1
        clampCycleDay()
    }

    private func clampCycleDay() {
        selectedCycleDay = min(max(1, selectedCycleDay), max(1, cycleLength))
    }
}

// MARK: - Reminder Time Editor

private struct ReminderTimeEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedTime = Date()

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.reminder_time.title", locale: locale),
            bottomPadding: 0
        ) {
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, locale)
            .frame(height: 170)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                saveReminderTime()
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear { seedFromStore() }
    }

    private func seedFromStore() {
        selectedTime = Calendar.current.date(
            from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: store.reminderHour,
                minute: store.reminderMinute
            )
        ) ?? Date()
    }

    private func saveReminderTime() {
        let selection = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        ScheduleCriticalSettingChange.saveSettingsReminderTime(
            store: store,
            hour: selection.hour ?? store.reminderHour,
            minute: selection.minute ?? store.reminderMinute
        )
    }
}

// MARK: - Last Call Reminder Editor

private struct LastCallReminderEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var isEnabled: Bool = false
    @State private var selectedTime = Date()

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.final_reminder.title", locale: locale),
            bottomPadding: 0
        ) {
            VStack(spacing: 20) {
                Text(PillieLocalization.string("settings.final_reminder.body", locale: locale))
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Toggle(
                    PillieLocalization.string("settings.final_reminder.title", locale: locale),
                    isOn: $isEnabled
                )
                    .toggleStyle(SwitchToggleStyle(tint: PillieTheme.coral))
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .padding(.horizontal, 28)

                DatePicker(
                    "",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, locale)
                .frame(height: 150)
                .opacity(isEnabled ? 1 : 0.4)
                .disabled(!isEnabled)
            }

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                saveLastCallReminder()
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear { seedFromStore() }
    }

    private func seedFromStore() {
        isEnabled = store.lastCallReminderEnabled
        selectedTime = Calendar.current.date(
            from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: store.lastCallReminderHour,
                minute: store.lastCallReminderMinute
            )
        ) ?? Date()
    }

    private func saveLastCallReminder() {
        let selection = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        ScheduleCriticalSettingChange.saveSettingsLastCallReminder(
            store: store,
            enabled: isEnabled,
            hour: selection.hour ?? store.lastCallReminderHour,
            minute: selection.minute ?? store.lastCallReminderMinute
        )
    }
}

// MARK: - Auto Reminder Interval Editor

struct AutoReminderIntervalEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedInterval: Int = 10

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.followup.interval_title", locale: locale),
            bottomPadding: 0
        ) {
            VStack(spacing: 16) {
                ForEach(PillStore.autoReminderIntervalOptions, id: \.self) { option in
                    Button {
                        selectedInterval = option
                    } label: {
                        HStack {
                            Text(SettingsPresentation.interval(minutes: option, locale: locale))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedInterval == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedInterval == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsAutoReminderInterval(
                    store: store,
                    intervalMinutes: selectedInterval
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedInterval = store.autoReminderIntervalMinutes
        }
    }
}

// MARK: - Blocking Snooze Interval Editor

private struct BlockingSnoozeIntervalEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedInterval: Int = BlockingSnoozePolicy.defaultIntervalMinutes

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.blocking.snooze_title", locale: locale),
            bottomPadding: 0
        ) {
            Text(PillieLocalization.string("settings.blocking.snooze_hint", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                ForEach(PillStore.blockingSnoozeIntervalOptions, id: \.self) { option in
                    Button {
                        selectedInterval = option
                    } label: {
                        HStack {
                            Text(SettingsPresentation.blockingSnoozeInterval(minutes: option, locale: locale))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedInterval == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedInterval == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsBlockingSnoozeInterval(
                    store: store,
                    intervalMinutes: selectedInterval
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedInterval = store.blockingSnoozeIntervalMinutes
        }
    }
}

// MARK: - Auto Reminder Retry Limit Editor

private struct AutoReminderRetryLimitEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedLimit: Int = 3

    private let settingsFeedback = SettingsInteractionFeedback()

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.followup.retry_limit_title", locale: locale),
            bottomPadding: 0
        ) {
            VStack(spacing: 16) {
                ForEach(PillStore.autoReminderRetryLimitOptions, id: \.self) { option in
                    Button {
                        selectedLimit = option
                    } label: {
                        HStack {
                            Text(optionLabel(for: option))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedLimit == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLimit == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsAutoReminderRetryLimit(
                    store: store,
                    retryLimit: selectedLimit
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedLimit = store.autoReminderRetryLimit
        }
    }

    private func optionLabel(for option: Int) -> String {
        switch option {
        case 0:
            return PillieLocalization.string("global.status.off", locale: locale)
        default:
            return option.formatted(.number.locale(locale))
        }
    }
}

// MARK: - Refill Reminder Threshold Editor

private struct RefillReminderThresholdEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedThreshold: Int = 5

    private let settingsFeedback = SettingsInteractionFeedback()

    private var isPatchMethod: Bool {
        store.pack.method == .patch
    }

    private var editorTitle: String {
        SettingsPresentation.supplyReminderTitle(
            method: store.pack.method,
            locale: locale
        )
    }

    private var thresholdOptions: [Int] {
        isPatchMethod ? PillStore.patchRestockReminderThresholdOptions : PillStore.refillReminderThresholdOptions
    }

    var body: some View {
        SettingsSheetContainer(title: editorTitle, bottomPadding: 0) {
            VStack(spacing: 16) {
                ForEach(thresholdOptions, id: \.self) { option in
                    Button {
                        selectedThreshold = option
                    } label: {
                        HStack {
                            Text(thresholdLabel(for: option))
                                .font(.pillieBodyBold())
                                .foregroundStyle(PillieTheme.textPrimary)
                            Spacer()
                            Image(systemName: selectedThreshold == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedThreshold == option ? PillieTheme.coral : PillieTheme.textMuted)
                        }
                        .padding(14)
                        .background(PillieTheme.cardWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsSupplyReminderThreshold(
                    store: store,
                    threshold: selectedThreshold
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedThreshold = isPatchMethod
                ? store.patchRestockReminderThresholdPatches
                : store.refillReminderThresholdDays
        }
    }

    private func thresholdLabel(for option: Int) -> String {
        option.formatted(.number.locale(locale))
    }
}

// MARK: - Cycle Day Editor

private struct CycleDayEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var selectedCycleDay: Int = 1

    private let settingsFeedback = SettingsInteractionFeedback()

    private var cycleLength: Int {
        max(1, store.pack.cycleLength)
    }

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.cycle_day.title", locale: locale),
            bottomPadding: 0
        ) {
            Text(SettingsPresentation.cycleDay(
                day: selectedCycleDay,
                total: cycleLength,
                locale: locale
            ))
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.textPrimary)

            Stepper(
                value: $selectedCycleDay,
                in: 1...cycleLength
            ) {
                Text(PillieLocalization.string("settings.cycle_day.adjust", locale: locale))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.horizontal, 20)

            Text(PillieLocalization.string("settings.cycle_day.history_note", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                store.updateCycleDay(selectedCycleDay)
                ProductAnalyticsTelemetry.live.cycleDaySaved()
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)
        }
        .onAppear {
            selectedCycleDay = store.currentDayIndex + 1
        }
    }
}

#Preview {
    SettingsView()
        .environment(PillStore.previewStore())
}
