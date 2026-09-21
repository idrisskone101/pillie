//
//  SettingsView.swift
//  Pillie
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(PillStore.self) var store
    @Environment(AppLanguagePreference.self) private var languagePreference
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showTimeEditor = false
    @State private var showIntervalEditor = false
    @State private var showRetryLimitEditor = false
    @State private var showRefillReminderEditor = false
    @State private var showProtocolEditor = false
    @State private var showCycleDayEditor = false
    @State private var showBlockedAppsEditor = false
    @State private var showBlockingUpsell = false
    @State private var showSmartRemindersUpsell = false
    @State private var showCustomRemindersEditor = false
    @State private var showCustomRemindersUpsell = false
    @State private var showPaywall = false
    @State private var showLanguagePicker = false
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
                            Task { @MainActor in
                                _ = await AppBlockingManager.shared.ensureAuthorized()
                                openSensitiveSetting { showBlockedAppsEditor = true }
                                ProductAnalyticsTelemetry.live.blockedAppsSettingsOpened(
                                    hasSelection: AppBlockingManager.shared.hasAppsSelected
                                )
                            }
                        } label: {
                            settingsRow(PillieLocalization.string(
                                "settings.blocked_apps.title",
                                locale: locale
                            ), value: blockingStatusSummary)
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

                // MARK: - Preferences
                sectionHeader(PillieLocalization.string(
                    "settings.section.preferences",
                    locale: locale
                ))
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))

                VStack(alignment: .leading, spacing: 8) {
                    settingsCard {
                        Button {
                            openSettingSheet { showLanguagePicker = true }
                        } label: {
                            settingsRow(
                                PillieLocalization.string("settings.language.title", locale: locale),
                                value: languageRowValue
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settingsLanguageRow")
                    }

                    Text(PillieLocalization.string("settings.language.helper", locale: locale))
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
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
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
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
        .sheet(isPresented: $showCustomRemindersEditor) {
            CustomReminderMessagesEditor(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            HonestPaywallHost(
                entry: .settingsSubscription,
                surface: .settingsSubscription,
                onDismiss: { showPaywall = false }
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
    private var languageRowValue: String {
        switch languagePreference.selection {
        case .system:
            return PillieLocalization.string("settings.language.system", locale: locale)
        default:
            return languagePreference.selection.nativeName
        }
    }

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

#Preview {
    SettingsView()
        .environment(PillStore.previewStore())
        .environment(AppLanguagePreference())
}
