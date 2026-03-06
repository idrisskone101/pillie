//
//  PillStore.swift
//  Pillie
//

import Foundation
import SwiftUI
import SwiftData
import os.signpost

@Observable
class PillStore {
    private(set) var packs: [PillPack]
    var protocolChangeVersion: Int = 0

    var pack: PillPack {
        if let current = activePack {
            return current
        }
        return packs.last!
    }

    var reminderHour: Int {
        didSet { UserDefaults.standard.set(reminderHour, forKey: Self.reminderHourKey) }
    }
    var reminderMinute: Int {
        didSet { UserDefaults.standard.set(reminderMinute, forKey: Self.reminderMinuteKey) }
    }
    var autoReminderIntervalMinutes: Int {
        didSet {
            let normalized = Self.normalizedAutoReminderInterval(autoReminderIntervalMinutes)
            if normalized != autoReminderIntervalMinutes {
                autoReminderIntervalMinutes = normalized
                return
            }
            UserDefaults.standard.set(normalized, forKey: Self.autoReminderIntervalKey)
        }
    }
    var refillReminderThresholdDays: Int {
        didSet {
            let normalized = Self.normalizedRefillReminderThreshold(refillReminderThresholdDays)
            if normalized != refillReminderThresholdDays {
                refillReminderThresholdDays = normalized
                return
            }
            UserDefaults.standard.set(normalized, forKey: Self.refillReminderThresholdDaysKey)
        }
    }
    var patchRestockReminderThresholdPatches: Int {
        didSet {
            let normalized = Self.normalizedPatchRestockReminderThreshold(patchRestockReminderThresholdPatches)
            if normalized != patchRestockReminderThresholdPatches {
                patchRestockReminderThresholdPatches = normalized
                return
            }
            UserDefaults.standard.set(normalized, forKey: Self.patchRestockReminderThresholdPatchesKey)
        }
    }
    var contraceptiveMethod: ContraceptiveMethod {
        didSet { UserDefaults.standard.set(contraceptiveMethod.rawValue, forKey: Self.contraceptiveMethodKey) }
    }
    var appActivatedDate: Date? {
        didSet {
            if let date = appActivatedDate {
                UserDefaults.standard.set(date, forKey: Self.appActivatedDateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.appActivatedDateKey)
            }
            invalidateAllSnapshotCaches()
        }
    }
    var streakResetDate: Date? {
        didSet {
            if let date = streakResetDate {
                UserDefaults.standard.set(date, forKey: Self.streakResetDateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.streakResetDateKey)
            }
        }
    }
    var painPoints: Set<PainPoint> {
        didSet {
            let rawValues = painPoints.map { $0.rawValue }
            UserDefaults.standard.set(rawValues, forKey: Self.painPointsKey)
        }
    }

    private let modelContext: ModelContext
    // Retains the container in previews so backing data isn't destroyed
    private var _containerRef: ModelContainer?

    // MARK: - Read-model indexes + caches

    private struct PackTimelineEntry {
        let pack: PillPack
        let startEpochDay: Int
        let packNumber: Int
    }

    private var dayRecordIndexByPackID: [UUID: [Int: PillDay]] = [:]
    private var snapshotCacheByPackID: [UUID: [Int: PillScheduleSnapshot]] = [:]
    private var packTimeline: [PackTimelineEntry] = []

    // MARK: - UserDefaults keys (settings only)

    private static let reminderHourKey = "pillie_reminder_hour"
    private static let reminderMinuteKey = "pillie_reminder_minute"
    private static let autoReminderIntervalKey = "pillie_auto_reminder_interval_minutes"
    private static let refillReminderThresholdDaysKey = "pillie_refill_reminder_threshold_days"
    private static let patchRestockReminderThresholdPatchesKey = "pillie_patch_restock_threshold_patches"
    private static let contraceptiveMethodKey = "pillie_contraceptive_method"
    private static let appActivatedDateKey = "pillie_app_activated_date"
    private static let streakResetDateKey = "pillie_streak_reset_date"
    private static let painPointsKey = "pillie_pain_points"
    private static let minimumSupportedEpoch: TimeInterval = -2_208_988_800 // 1900-01-01
    private static let maximumSupportedEpoch: TimeInterval = 7_258_118_400 // 2200-01-01
    private static let snapshotCacheLimitPerPack = 512
    private static let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.idrisskone.pillie", category: "PillStorePerf")

    static let autoReminderIntervalOptions: [Int] = [5, 10, 15, 30]
    static let refillReminderThresholdOptions: [Int] = [3, 5, 7]
    static let patchRestockReminderThresholdOptions: [Int] = [1, 2]
    private static let alarmDayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    // MARK: - Computed

    var today: Date {
        startOfDaySafe(Date())
    }

    var activePack: PillPack? {
        if let current = packs.first(where: { $0.isCurrent }) {
            return current
        }
        return packs.last
    }

    var currentDayIndex: Int {
        pack.cycleDayIndex(on: today)
    }

    var daysOnCurrentPack: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: pack.startDate), to: today).day ?? 0
    }

    var isRefillDue: Bool {
        daysOnCurrentPack > pack.cycleLength
    }

    var daysOverdue: Int {
        max(0, daysOnCurrentPack - pack.cycleLength)
    }

    var refillCTALabel: String {
        pack.method == .pill ? "Start New Pack" : "Start New Cycle"
    }

    var refillBannerTitle: String {
        pack.method == .pill ? "Pack Complete!" : "Cycle Complete!"
    }

    var refillBannerSubtitle: String {
        let n = pack.packNumber
        let overdue = daysOverdue
        if pack.method == .pill {
            if overdue > 1 {
                return "Your pack ended \(overdue) days ago. Start a new pack to continue tracking."
            } else if overdue == 1 {
                return "Your pack ended 1 day ago. Start a new pack to continue tracking."
            }
            return "You've finished Pack \(n). Start a new pack to keep tracking."
        } else {
            let methodName = pack.method == .patch ? "patch" : "ring"
            if overdue > 1 {
                return "Your \(methodName) cycle ended \(overdue) days ago. Start a new cycle to continue tracking."
            } else if overdue == 1 {
                return "Your \(methodName) cycle ended 1 day ago. Start a new cycle to continue tracking."
            }
            return "You've completed Cycle \(n). Start a new cycle to keep tracking."
        }
    }

    var currentStreak: Int {
        guard let targetPack = activePack else { return 0 }

        let currentDay = today
        let dueDates = dueDatesBackwards(from: currentDay, pack: targetPack, maxDueActions: max(120, targetPack.cycleLength * 8))
        let cal = Calendar.current
        let resetCutoff = streakResetDate.map { cal.startOfDay(for: $0) }
        var streak = 0

        for dueDate in dueDates {
            // Stop counting if this due date is before the streak reset cutoff
            if let cutoff = resetCutoff, cal.startOfDay(for: dueDate) < cutoff {
                break
            }

            guard let snapshot = scheduleSnapshot(for: dueDate, in: targetPack) else { continue }

            if streak == 0,
               cal.isDate(dueDate, inSameDayAs: currentDay),
               snapshot.status == .upcoming {
                continue
            }

            if snapshot.status == .taken {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    var nextReminderTime: String {
        let h = reminderHour
        let m = reminderMinute
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayHour, m, period)
    }

    var autoReminderIntervalDisplay: String {
        "\(autoReminderIntervalMinutes) min"
    }

    var refillReminderThresholdDisplay: String {
        "\(refillReminderThresholdDays) days before end"
    }

    var patchRestockReminderThresholdDisplay: String {
        let patches = patchRestockReminderThresholdPatches
        return patches == 1 ? "1 patch left" : "\(patches) patches left"
    }

    var isTodayTaken: Bool {
        statusForDate(today) == .taken
    }

    /// Whether today requires no blocking — either taken, passive active, or a break day.
    var isTodayHandled: Bool {
        isTodayTaken || isTodayPassiveOrBreak
    }

    var isTodayPassiveOrBreak: Bool {
        guard let snapshot = scheduleSnapshot(for: today) else { return false }
        return snapshot.isPassiveActive || snapshot.isBreak
    }

    var todayDueAction: DoseScheduleAction? {
        guard let action = dueAction(on: today) else { return nil }
        return action.type.requiresUserAction ? action : nil
    }

    var nextDueAction: DoseScheduleAction? {
        guard let activePack else { return nil }
        return DoseScheduleEngine.nextDueActions(from: today, limit: 1, pack: activePack).first
    }

    func nextUntakenDueAction(from date: Date = Date()) -> DoseScheduleAction? {
        guard let targetPack = pack(for: date) else { return nil }
        let start = startOfDaySafe(date)
        let scanLimit = max(48, targetPack.cycleLength * 6)

        let dueActions = DoseScheduleEngine.nextDueActions(
            from: start,
            limit: scanLimit,
            pack: targetPack
        )

        for due in dueActions {
            if let snapshot = scheduleSnapshot(for: due.date, in: targetPack), snapshot.status != .taken {
                return due
            }
        }

        return nil
    }

    var alarmAction: DoseScheduleAction? {
        nextUntakenDueAction(from: today)
    }

    var alarmBadge: String {
        alarmAction?.badgeLabel ?? "NONE"
    }

    private var alarmDayLabel: String? {
        guard let alarmAction else { return nil }
        let calendar = Calendar.current

        if calendar.isDate(alarmAction.date, inSameDayAs: today) {
            return nil
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(alarmAction.date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }

        return Self.alarmDayLabelFormatter.string(from: alarmAction.date)
    }

    var alarmDisplayTime: String {
        nextReminderTime
    }

    var alarmSubtitle: String {
        guard let alarmAction else { return "No action due" }
        guard isTodayTaken else { return alarmAction.actionTitle }

        let nextAction = alarmAction.badgeLabel.lowercased()
        if let dayLabel = alarmDayLabel {
            let normalizedDayLabel = dayLabel == "Tomorrow" ? "tomorrow" : dayLabel
            return "Taken today. Next \(nextAction) \(normalizedDayLabel) at \(nextReminderTime)."
        }
        return "Taken today. Next \(nextAction) at \(nextReminderTime)."
    }

    var todayCTA: String {
        todayDueAction?.ctaLabel ?? "No Action Due Today"
    }

    var todayStatusBadge: String {
        todayDueAction?.badgeLabel ?? "NONE"
    }

    // MARK: - Schedule Read Model

    /// Returns the single-source schedule snapshot used by Home/Calendar/Settings
    /// for date-based status and due-action rendering.
    func scheduleSnapshot(for date: Date) -> PillScheduleSnapshot? {
        let signpostID = OSSignpostID(log: Self.perfLog)
        os_signpost(.begin, log: Self.perfLog, name: "scheduleSnapshot", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.perfLog, name: "scheduleSnapshot", signpostID: signpostID) }

        let day = startOfDaySafe(date)
        guard let targetPack = pack(for: day) else { return nil }
        return scheduleSnapshot(for: day, in: targetPack)
    }

    /// Resolves a cycle-day index (0-based) into a schedule snapshot for a specific pack.
    /// Used by cycle-strip UIs so they share the same status logic as calendar cells.
    func scheduleSnapshot(forCycleIndex index: Int, in pack: PillPack) -> PillScheduleSnapshot? {
        let cycleLength = max(1, pack.cycleLength)
        let normalizedIndex = ((index % cycleLength) + cycleLength) % cycleLength

        let baseDate: Date
        let dayOffset: Int
        if pack.method == .ring, let ringDate = pack.ringInsertionDate {
            baseDate = startOfDaySafe(ringDate)
            dayOffset = normalizedIndex
        } else {
            let normalizedAnchor = PillPack.normalizedCycleDayAnchorIndex(pack.cycleDayAnchorIndex, cycleLength: cycleLength)
            dayOffset = normalizedIndex - normalizedAnchor
            baseDate = startOfDaySafe(pack.startDate)
        }

        guard let resolvedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate) else {
            return nil
        }
        return scheduleSnapshot(for: resolvedDate, in: pack)
    }

    /// Batch API for month grid consumers. Keys are month day numbers (1-based).
    func monthSnapshots(for month: Date) -> [Int: PillScheduleSnapshot] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return [:]
        }

        var snapshots: [Int: PillScheduleSnapshot] = [:]
        snapshots.reserveCapacity(dayRange.count)

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                  let snapshot = scheduleSnapshot(for: date) else {
                continue
            }
            snapshots[day] = snapshot
        }

        return snapshots
    }

    /// Batch API for cycle-strip consumers. Keys are requested cycle indices.
    func cycleSnapshots(for indices: [Int], in pack: PillPack) -> [Int: PillScheduleSnapshot] {
        var snapshots: [Int: PillScheduleSnapshot] = [:]
        snapshots.reserveCapacity(indices.count)

        for index in indices {
            if let snapshot = scheduleSnapshot(forCycleIndex: index, in: pack) {
                snapshots[index] = snapshot
            }
        }

        return snapshots
    }

    /// Batch status lookup keyed by epoch-day used by notification scheduling.
    func statusesByEpochDay(for dates: [Date]) -> [Int: PillDay.Status] {
        var statuses: [Int: PillDay.Status] = [:]
        statuses.reserveCapacity(dates.count)

        for date in dates {
            let day = startOfDaySafe(date)
            let key = epochDay(for: day)
            if statuses[key] != nil { continue }
            if let status = scheduleSnapshot(for: day)?.status {
                statuses[key] = status
            }
        }

        return statuses
    }

    // MARK: - Actions

    func markTodayAsTaken() {
        markActionAsTaken(on: today)
        syncTodayTakenToAppGroup()
        AppBlockingManager.shared.removeBlocking()
        scheduleNotificationResync()
    }

    func unmarkTodayAsTaken() {
        unmarkActionAsTaken(on: today)
        syncTodayTakenToAppGroup()
        // Re-apply blocking if past reminder time and now untaken
        let now = Date()
        let calendar = Calendar.current
        let reminderToday = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: now)
        if let reminderToday, now >= reminderToday, !isTodayHandled {
            let method = pack.method
            let reason: String
            switch method {
            case .pill: reason = "Time to take your pill!"
            case .patch: reason = "Time for your patch change!"
            case .ring: reason = "Time for your ring action!"
            }
            AppBlockingManager.shared.applyBlocking(reason: reason)
        }
        scheduleNotificationResync()
    }

    func syncTodayTakenToAppGroup() {
        ScreenTimeSharedState.isTodayTaken = isTodayHandled
    }

    func markActionAsTaken(on date: Date) {
        let day = startOfDaySafe(date)
        let dayEpoch = epochDay(for: day)
        guard let snapshot = scheduleSnapshot(for: day),
              let due = snapshot.dueAction else { return }
        let targetPack = snapshot.pack
        let isToday = Calendar.current.isDateInToday(day)

        if let existingDay = dayRecord(forPackID: targetPack.id, epochDay: dayEpoch)
            ?? targetPack.days.first(where: { Calendar.current.isDate(Self.validatedDate($0.date, fallback: day), inSameDayAs: day) }) {
            existingDay.date = day
            existingDay.status = .taken
            existingDay.actionType = due.type
            index(dayRecord: existingDay, forPackID: targetPack.id, epochDay: dayEpoch)
        } else {
            let newDay = PillDay(
                date: day,
                status: .taken,
                actionType: due.type,
                pack: targetPack
            )
            modelContext.insert(newDay)
            index(dayRecord: newDay, forPackID: targetPack.id, epochDay: dayEpoch)
        }

        // Pin the ring insertion anchor on first check-in so future
        // cycle-day edits in Settings don't shift the removal date.
        if targetPack.method == .ring && targetPack.ringInsertionDate == nil {
            targetPack.ringInsertionDate = targetPack.startDate
        }

        invalidateSnapshotCache(forPackID: targetPack.id, epochDay: dayEpoch)
        scheduleStoreCommit()

        // Auto-start new cycle when ring is reinserted (day 28).
        // The reinsertion IS the insertion for the new cycle.
        if due.type == .ringReinsert {
            startNewPack()
            // Mark new cycle's day 1 (ringInsert) as taken
            let newDay = startOfDaySafe(date)
            let newDayEpoch = epochDay(for: newDay)
            if let newSnapshot = scheduleSnapshot(for: newDay),
               newSnapshot.dueAction?.type == .ringInsert {
                let newPack = newSnapshot.pack
                let record = PillDay(
                    date: newDay,
                    status: .taken,
                    actionType: .ringInsert,
                    pack: newPack
                )
                modelContext.insert(record)
                index(dayRecord: record, forPackID: newPack.id, epochDay: newDayEpoch)
                invalidateSnapshotCache(forPackID: newPack.id, epochDay: newDayEpoch)
                scheduleStoreCommit()
            }
        }

        // Sync app group state when marking today
        if isToday {
            syncTodayTakenToAppGroup()
            AppBlockingManager.shared.removeBlocking()
        }
    }

    func unmarkActionAsTaken(on date: Date) {
        let day = startOfDaySafe(date)
        let dayEpoch = epochDay(for: day)
        guard let snapshot = scheduleSnapshot(for: day) else { return }
        let targetPack = snapshot.pack

        guard let existingDay = dayRecord(forPackID: targetPack.id, epochDay: dayEpoch), existingDay.status == .taken else {
            return
        }

        // Revert auto-started ring cycle if user undoes the ringInsert on a same-day new pack
        if existingDay.actionType == .ringInsert,
           targetPack.packNumber > 1,
           Calendar.current.isDate(targetPack.startDate, inSameDayAs: day) {
            let previousPackNumber = targetPack.packNumber - 1
            if let previousPack = packs.first(where: { $0.packNumber == previousPackNumber }) {
                // Delete the auto-created pack
                modelContext.delete(targetPack)
                // Restore previous pack and unmark its ringReinsert
                previousPack.isCurrent = true
                if let prevRecord = dayRecord(forPackID: previousPack.id, epochDay: dayEpoch),
                   prevRecord.actionType == .ringReinsert {
                    modelContext.delete(prevRecord)
                    removeDayRecordIndex(forPackID: previousPack.id, epochDay: dayEpoch)
                    invalidateSnapshotCache(forPackID: previousPack.id, epochDay: dayEpoch)
                }
                persist()
                packs = Self.fetchPacks(context: modelContext)
                rebuildReadIndexes()
                protocolChangeVersion &+= 1
                return
            }
        }

        modelContext.delete(existingDay)
        removeDayRecordIndex(forPackID: targetPack.id, epochDay: dayEpoch)
        invalidateSnapshotCache(forPackID: targetPack.id, epochDay: dayEpoch)
        scheduleStoreCommit()
    }

    func dueAction(on date: Date) -> DoseScheduleAction? {
        scheduleSnapshot(for: date)?.dueAction
    }

    func statusForDate(_ date: Date) -> PillDay.Status? {
        scheduleSnapshot(for: date)?.status
    }

    func actionTypeForDate(_ date: Date) -> PillDay.ActionType? {
        scheduleSnapshot(for: date)?.actionType
    }

    func monthAdherence(for month: Date) -> (completed: Int, due: Int, percentage: Int) {
        let signpostID = OSSignpostID(log: Self.perfLog)
        os_signpost(.begin, log: Self.perfLog, name: "monthAdherence", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.perfLog, name: "monthAdherence", signpostID: signpostID) }

        let calendar = Calendar.current
        let cutoff = today
        let monthStartComponents = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: monthStartComponents),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return (0, 0, 0)
        }

        let snapshots = monthSnapshots(for: month)
        var completed = 0
        var due = 0

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                  date <= cutoff,
                  let snapshot = snapshots[day] else {
                continue
            }

            if snapshot.status == .noData { continue }
            if snapshot.isDue {
                due += 1
                if snapshot.status == .taken {
                    completed += 1
                }
            }
        }

        let percentage = due > 0 ? min(100, (completed * 100) / due) : 0
        return (completed, due, percentage)
    }

    @discardableResult
    func startNewProtocol(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset,
        customActiveDays: Int?,
        customBreakDays: Int?,
        cycleDay: Int,
        preserveHistory: Bool,
        cycleDayWasExplicitlyConfirmedForMethodSwitch: Bool = true
    ) -> Bool {
        let normalizedCycleLength = cycleLengthFor(
            method: method,
            regimen: regimen,
            customActiveDays: customActiveDays,
            customBreakDays: customBreakDays
        )
        let safeCycleDay = max(1, min(cycleDay, normalizedCycleLength))
        let previousMethod = activePack?.method ?? pack.method
        let methodChanged = previousMethod != method
        if preserveHistory && methodChanged && !cycleDayWasExplicitlyConfirmedForMethodSwitch {
            return false
        }
        let useTodayAsStartDate = preserveHistory && methodChanged
        let startDate: Date = {
            if useTodayAsStartDate {
                return today
            }
            return Calendar.current.date(byAdding: .day, value: -(safeCycleDay - 1), to: today) ?? today
        }()
        let cycleDayAnchorIndex = useTodayAsStartDate ? (safeCycleDay - 1) : 0

        if preserveHistory {
            for existing in packs where existing.isCurrent {
                existing.isCurrent = false
            }
            let nextPackNumber = (packs.map(\.packNumber).max() ?? 0) + 1
            let nextPack = PillPack(
                packType: legacyPackType(for: regimen),
                method: method,
                pillRegimen: method == .pill ? regimen : .twentyOneSeven,
                customActiveDays: method == .pill ? customActiveDays : nil,
                customBreakDays: method == .pill ? customBreakDays : nil,
                startDate: startDate,
                cycleDayAnchorIndex: cycleDayAnchorIndex,
                packNumber: nextPackNumber,
                isCurrent: true
            )
            modelContext.insert(nextPack)
        } else if let activePack {
            activePack.method = method
            activePack.pillRegimen = method == .pill ? regimen : .twentyOneSeven
            if method == .pill && regimen == .custom {
                let normalized = PillPack.normalizedCustomValues(active: customActiveDays, breakDays: customBreakDays)
                activePack.customActiveDays = normalized.active
                activePack.customBreakDays = normalized.breakDays
            } else {
                activePack.customActiveDays = nil
                activePack.customBreakDays = nil
            }
            activePack.startDate = startDate
            activePack.cycleDayAnchorIndex = PillPack.normalizedCycleDayAnchorIndex(
                cycleDayAnchorIndex,
                cycleLength: activePack.cycleLength
            )
            activePack.packType = legacyPackType(for: regimen)
            activePack.isCurrent = true
            for existing in packs where existing.id != activePack.id {
                existing.isCurrent = false
            }

            // Backfill prior days as taken for onboarding mid-cycle
            if safeCycleDay > 1 {
                let existingDays = Array(activePack.days)
                for day in existingDays {
                    modelContext.delete(day)
                }
                backfillPriorDays(from: startDate, count: safeCycleDay - 1, pack: activePack, calendar: Calendar.current)
            }
            appActivatedDate = today
        } else {
            let nextPackNumber = (packs.map(\.packNumber).max() ?? 0) + 1
            let nextPack = PillPack(
                packType: legacyPackType(for: regimen),
                method: method,
                pillRegimen: method == .pill ? regimen : .twentyOneSeven,
                customActiveDays: method == .pill ? customActiveDays : nil,
                customBreakDays: method == .pill ? customBreakDays : nil,
                startDate: startDate,
                cycleDayAnchorIndex: cycleDayAnchorIndex,
                packNumber: nextPackNumber,
                isCurrent: true
            )
            modelContext.insert(nextPack)

            // Backfill prior days as taken for onboarding mid-cycle
            if safeCycleDay > 1 {
                backfillPriorDays(from: startDate, count: safeCycleDay - 1, pack: nextPack, calendar: Calendar.current)
            }
            appActivatedDate = today
        }

        contraceptiveMethod = method
        persist()
        refreshPacks()
        if methodChanged {
            protocolChangeVersion &+= 1
        }
        NotificationManager.shared.requestReschedule(from: self, reason: "protocol-change")
        return true
    }

    // MARK: - Full Reset (Contraception Type Change)

    /// Deletes all existing data and starts fresh, as if the user just onboarded.
    /// Marks prior active days in the current cycle as taken.
    func resetAndStartFresh(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset,
        customActiveDays: Int?,
        customBreakDays: Int?,
        cycleDay: Int
    ) {
        let calendar = Calendar.current
        let normalizedCycleLength = cycleLengthFor(
            method: method,
            regimen: regimen,
            customActiveDays: customActiveDays,
            customBreakDays: customBreakDays
        )
        let safeCycleDay = max(1, min(cycleDay, normalizedCycleLength))

        // 1. Delete all existing records
        try? modelContext.delete(model: PillDay.self)
        try? modelContext.delete(model: PillPack.self)

        // 2. Compute startDate so today aligns with safeCycleDay
        let startDate = calendar.date(byAdding: .day, value: -(safeCycleDay - 1), to: today) ?? today

        // 3. Create a fresh pack
        let freshPack = PillPack(
            packType: legacyPackType(for: regimen),
            method: method,
            pillRegimen: method == .pill ? regimen : .twentyOneSeven,
            customActiveDays: method == .pill && regimen == .custom ? customActiveDays : nil,
            customBreakDays: method == .pill && regimen == .custom ? customBreakDays : nil,
            startDate: startDate,
            cycleDayAnchorIndex: 0,
            packNumber: 1,
            isCurrent: true
        )
        modelContext.insert(freshPack)

        // 4. Backfill current cycle days before today (days 1 through safeCycleDay-1)
        //    All prior days → .taken. No days marked .missed.
        //    Break vs active is preserved in the actionType field.
        backfillPriorDays(from: startDate, count: safeCycleDay - 1, pack: freshPack, calendar: calendar)

        // 5. Set appActivatedDate to today so dates before our backfill
        //    range show as .noData (not .missed). Explicit PillDay records
        //    we created above always take precedence in the snapshot engine.
        appActivatedDate = today

        // 6. Persist and rebuild
        contraceptiveMethod = method
        persist()
        packs = Self.fetchPacks(context: modelContext)
        rebuildReadIndexes()
        protocolChangeVersion &+= 1
        NotificationManager.shared.requestReschedule(from: self, reason: "full-reset")
    }

    // MARK: - Backfill Helpers

    /// Creates PillDay records for prior cycle days, marking them all as `.taken`.
    /// Handles pill, patch, and ring methods with correct action types.
    private func backfillPriorDays(from startDate: Date, count: Int, pack: PillPack, calendar: Calendar = .current) {
        guard count > 0 else { return }
        for offset in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let actionType: PillDay.ActionType
            if pack.method == .ring, pack.ringInsertionDate != nil {
                let ringDayInCycle = offset + 1
                switch ringDayInCycle {
                case 1:       actionType = .ringInsert
                case 2...20:  actionType = .ringActive
                case 21:      actionType = .ringRemove
                case 22...27: actionType = .ringBreak
                case 28:      actionType = .ringReinsert
                default:      actionType = .ringActive
                }
            } else {
                actionType = DoseScheduleEngine.dueAction(on: date, pack: pack, calendar: calendar)?.type
                    ?? fallbackActionType(for: pack, on: date, calendar: calendar)
            }
            let record = PillDay(date: date, status: .taken, actionType: actionType, pack: pack)
            modelContext.insert(record)
        }
    }

    private func fallbackActionType(for pack: PillPack, on date: Date, calendar: Calendar = .current) -> PillDay.ActionType {
        let dayIndex = pack.cycleDayIndex(on: date, calendar: calendar)
        let isBreak = pack.isBreakDay(dayIndex: dayIndex)
        switch pack.method {
        case .pill:   return isBreak ? .pillBreak : .pillActive
        case .patch:  return isBreak ? .patchBreak : .patchActive
        case .ring:   return isBreak ? .ringBreak : .ringActive
        }
    }

    // MARK: - Update Cycle Day (Backfill Taken)

    /// Adjusts the active pack so today corresponds to `newCycleDay` and backfills
    /// all prior days as taken. No days are marked as missed.
    func updateCycleDay(_ newCycleDay: Int) {
        guard let activePack else { return }
        let calendar = Calendar.current
        let cycleLength = max(1, activePack.cycleLength)
        let safeCycleDay = max(1, min(newCycleDay, cycleLength))

        // 1. Adjust the pack so today = safeCycleDay.
        //    All methods (pill, patch, ring) recompute startDate so the
        //    schedule engine anchors correctly and backfilled action types
        //    match the user's chosen cycle day.
        let newStartDate = calendar.date(byAdding: .day, value: -(safeCycleDay - 1), to: today) ?? today
        activePack.startDate = newStartDate
        activePack.cycleDayAnchorIndex = 0
        let backfillStart = newStartDate

        // Ring: update pinned insertion date to match the new cycle day anchor.
        if activePack.method == .ring, activePack.ringInsertionDate != nil {
            activePack.ringInsertionDate = newStartDate
        }

        // 2. Delete all existing PillDay records for this pack
        let existingDays = Array(activePack.days)
        for day in existingDays {
            modelContext.delete(day)
        }

        // 3. Backfill days 1 through (safeCycleDay - 1) as .taken.
        //    No days marked .missed — we assume the user completed everything before the app.
        //    Break vs active is preserved in the actionType field.
        backfillPriorDays(from: backfillStart, count: safeCycleDay - 1, pack: activePack, calendar: calendar)

        // 4. Set appActivatedDate to today so dates before our backfill
        //    range show as .noData (not .missed). Explicit PillDay records
        //    we created above always take precedence in the snapshot engine.
        appActivatedDate = today

        // 5. Reset streak so backfilled .taken records don't inflate it.
        streakResetDate = today

        // 6. Persist and rebuild
        persist()
        refreshPacks()
        protocolChangeVersion &+= 1
        NotificationManager.shared.requestReschedule(from: self, reason: "cycle-day-update")
    }

    func startNewPack() {
        guard let currentPack = activePack else { return }

        // 1. Mark all existing packs as not current
        for existing in packs where existing.isCurrent {
            existing.isCurrent = false
        }

        // 2. Create new pack with same settings, day 1, today
        let nextPackNumber = (packs.map(\.packNumber).max() ?? 0) + 1
        let newPack = PillPack(
            packType: currentPack.packType,
            method: currentPack.method,
            pillRegimen: currentPack.method == .pill ? currentPack.pillRegimen : .twentyOneSeven,
            customActiveDays: currentPack.method == .pill ? currentPack.customActiveDays : nil,
            customBreakDays: currentPack.method == .pill ? currentPack.customBreakDays : nil,
            startDate: today,
            cycleDayAnchorIndex: 0,
            packNumber: nextPackNumber,
            isCurrent: true
        )
        modelContext.insert(newPack)

        // 3. Persist, rebuild caches, trigger UI refresh + notification reschedule
        persist()
        packs = Self.fetchPacks(context: modelContext)
        rebuildReadIndexes()
        protocolChangeVersion &+= 1
        NotificationManager.shared.requestReschedule(from: self, reason: "refill-new-pack")
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let defaults = UserDefaults.standard

        let loadedPacks = Self.fetchPacks(context: modelContext)
        var resolvedPacks: [PillPack] = loadedPacks
        if resolvedPacks.isEmpty {
            let defaultPack = PillPack(
                packType: .twentyOneSeven,
                method: .pill,
                pillRegimen: .twentyOneSeven,
                startDate: Calendar.current.startOfDay(for: Date()),
                packNumber: 1,
                isCurrent: true
            )
            modelContext.insert(defaultPack)
            try? modelContext.save()
            resolvedPacks = [defaultPack]
        }

        Self.sanitizePersistedDatesIfNeeded(context: modelContext, packs: resolvedPacks)
        resolvedPacks = Self.fetchPacks(context: modelContext)

        if !resolvedPacks.contains(where: { $0.isCurrent }),
           let last = resolvedPacks.sorted(by: { $0.packNumber < $1.packNumber }).last {
            last.isCurrent = true
            try? modelContext.save()
        }

        self.packs = resolvedPacks

        // Load settings from UserDefaults
        self.reminderHour = defaults.object(forKey: Self.reminderHourKey) as? Int ?? 8
        self.reminderMinute = defaults.object(forKey: Self.reminderMinuteKey) as? Int ?? 0
        self.autoReminderIntervalMinutes = Self.normalizedAutoReminderInterval(
            defaults.object(forKey: Self.autoReminderIntervalKey) as? Int ?? 10
        )
        self.refillReminderThresholdDays = Self.normalizedRefillReminderThreshold(
            defaults.object(forKey: Self.refillReminderThresholdDaysKey) as? Int ?? 5
        )
        self.patchRestockReminderThresholdPatches = Self.normalizedPatchRestockReminderThreshold(
            defaults.object(forKey: Self.patchRestockReminderThresholdPatchesKey) as? Int ?? 1
        )

        let defaultMethod = resolvedPacks
            .sorted(by: { $0.packNumber < $1.packNumber })
            .last(where: { $0.isCurrent })?.method ?? .pill
        if let raw = defaults.string(forKey: Self.contraceptiveMethodKey),
           let method = ContraceptiveMethod(rawValue: raw) {
            self.contraceptiveMethod = method
        } else {
            self.contraceptiveMethod = defaultMethod
        }

        if let storedActivation = defaults.object(forKey: Self.appActivatedDateKey) as? Date,
           Self.isValidPersistedDate(storedActivation) {
            self.appActivatedDate = storedActivation
        } else {
            self.appActivatedDate = nil
            defaults.removeObject(forKey: Self.appActivatedDateKey)
        }

        if let storedStreakReset = defaults.object(forKey: Self.streakResetDateKey) as? Date,
           Self.isValidPersistedDate(storedStreakReset) {
            self.streakResetDate = storedStreakReset
        } else {
            self.streakResetDate = nil
            defaults.removeObject(forKey: Self.streakResetDateKey)
        }

        if let rawPainPoints = defaults.stringArray(forKey: Self.painPointsKey) {
            self.painPoints = Set(rawPainPoints.compactMap { PainPoint(rawValue: $0) })
        } else {
            self.painPoints = []
        }

        rebuildReadIndexes()
    }

    // MARK: - Preview

    static let previewContainer: ModelContainer = {
        let schema = Schema([PillPack.self, PillDay.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    static func previewStore() -> PillStore {
        let container = previewContainer
        let context = container.mainContext

        // Clear any stale data from previous preview runs
        try? context.delete(model: PillDay.self)
        try? context.delete(model: PillPack.self)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = cal.date(byAdding: .day, value: -15, to: today) ?? today

        let pack = PillPack(
            packType: .twentyOneSeven,
            method: .pill,
            pillRegimen: .twentyOneSeven,
            startDate: startDate,
            packNumber: 2,
            isCurrent: true
        )
        context.insert(pack)

        for i in 0..<15 {
            guard let date = cal.date(byAdding: .day, value: i, to: startDate) else { continue }
            let status: PillDay.Status = (i == 5 || i == 10) ? .missed : .taken
            let action: PillDay.ActionType = i < 21 ? .pillActive : .pillBreak
            context.insert(PillDay(date: date, status: status, actionType: action, pack: pack))
        }
        for i in 16..<28 {
            guard let date = cal.date(byAdding: .day, value: i, to: startDate) else { continue }
            let status: PillDay.Status = i >= 21 ? .breakDay : .upcoming
            let action: PillDay.ActionType = i >= 21 ? .pillBreak : .pillActive
            context.insert(PillDay(date: date, status: status, actionType: action, pack: pack))
        }

        try? context.save()
        let store = PillStore(modelContext: context)
        store._containerRef = container
        return store
    }

    // MARK: - Internal Helpers

    private static func fetchPacks(context: ModelContext) -> [PillPack] {
        let descriptor = FetchDescriptor<PillPack>(sortBy: [SortDescriptor(\.packNumber, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func isValidPersistedDate(_ date: Date) -> Bool {
        let epoch = date.timeIntervalSince1970
        return epoch.isFinite && epoch >= minimumSupportedEpoch && epoch <= maximumSupportedEpoch
    }

    private static func validatedDate(_ date: Date, fallback: Date) -> Date {
        isValidPersistedDate(date) ? date : fallback
    }

    private func startOfDaySafe(_ date: Date, fallback: Date = Date()) -> Date {
        let validated = Self.validatedDate(date, fallback: fallback)
        return Calendar.current.startOfDay(for: validated)
    }

    private static func sanitizePersistedDatesIfNeeded(context: ModelContext, packs: [PillPack]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var didMutate = false

        for pack in packs {
            let sanitizedStart = calendar.startOfDay(for: validatedDate(pack.startDate, fallback: today))
            if pack.startDate != sanitizedStart {
                pack.startDate = sanitizedStart
                didMutate = true
            }
            let normalizedAnchor = PillPack.normalizedCycleDayAnchorIndex(pack.cycleDayAnchorIndex, cycleLength: pack.cycleLength)
            if pack.cycleDayAnchorIndex != normalizedAnchor {
                pack.cycleDayAnchorIndex = normalizedAnchor
                didMutate = true
            }
        }

        let dayDescriptor = FetchDescriptor<PillDay>()
        let allDays = (try? context.fetch(dayDescriptor)) ?? []
        for day in allDays {
            let fallback = day.pack.map { calendar.startOfDay(for: validatedDate($0.startDate, fallback: today)) } ?? today
            let sanitizedDay = calendar.startOfDay(for: validatedDate(day.date, fallback: fallback))
            if day.date != sanitizedDay {
                day.date = sanitizedDay
                didMutate = true
            }
        }

        if didMutate {
            try? context.save()
        }
    }

    private func refreshPacks() {
        packs = Self.fetchPacks(context: modelContext)
        rebuildReadIndexes()
    }

    private func rebuildReadIndexes() {
        rebuildPackTimeline()
        rebuildDayRecordIndex()
        snapshotCacheByPackID.removeAll(keepingCapacity: true)
    }

    private func rebuildPackTimeline() {
        let entries = packs.map {
            PackTimelineEntry(
                pack: $0,
                startEpochDay: epochDay(for: startOfDaySafe($0.startDate)),
                packNumber: $0.packNumber
            )
        }

        packTimeline = entries.sorted {
            if $0.startEpochDay == $1.startEpochDay {
                return $0.packNumber < $1.packNumber
            }
            return $0.startEpochDay < $1.startEpochDay
        }
    }

    private func rebuildDayRecordIndex() {
        var index: [UUID: [Int: PillDay]] = [:]

        for pack in packs {
            var dayMap: [Int: PillDay] = [:]
            for day in pack.days {
                let safeDay = startOfDaySafe(day.date, fallback: pack.startDate)
                let key = epochDay(for: safeDay)
                dayMap[key] = day
            }
            index[pack.id] = dayMap
        }

        dayRecordIndexByPackID = index
    }

    private func dayRecord(forPackID packID: UUID, epochDay: Int) -> PillDay? {
        dayRecordIndexByPackID[packID]?[epochDay]
    }

    private func index(dayRecord: PillDay, forPackID packID: UUID, epochDay: Int) {
        var packIndex = dayRecordIndexByPackID[packID] ?? [:]
        packIndex[epochDay] = dayRecord
        dayRecordIndexByPackID[packID] = packIndex
    }

    private func removeDayRecordIndex(forPackID packID: UUID, epochDay: Int) {
        guard var packIndex = dayRecordIndexByPackID[packID] else { return }
        packIndex.removeValue(forKey: epochDay)
        dayRecordIndexByPackID[packID] = packIndex
    }

    private func invalidateAllSnapshotCaches() {
        snapshotCacheByPackID.removeAll(keepingCapacity: true)
    }

    private func invalidateSnapshotCache(forPackID packID: UUID, epochDay: Int) {
        guard var packCache = snapshotCacheByPackID[packID] else { return }
        packCache.removeValue(forKey: epochDay)
        snapshotCacheByPackID[packID] = packCache
    }

    private func cache(snapshot: PillScheduleSnapshot, forPackID packID: UUID, epochDay: Int) {
        var packCache = snapshotCacheByPackID[packID] ?? [:]
        if packCache.count >= Self.snapshotCacheLimitPerPack {
            packCache.removeAll(keepingCapacity: true)
        }
        packCache[epochDay] = snapshot
        snapshotCacheByPackID[packID] = packCache
    }

    private func pack(for date: Date) -> PillPack? {
        guard !packTimeline.isEmpty else { return nil }
        let dayEpoch = epochDay(for: startOfDaySafe(date))
        guard let earliest = packTimeline.first, dayEpoch >= earliest.startEpochDay else {
            return nil
        }

        var low = 0
        var high = packTimeline.count - 1
        var bestMatch = 0

        while low <= high {
            let mid = (low + high) / 2
            let candidate = packTimeline[mid]

            if candidate.startEpochDay <= dayEpoch {
                bestMatch = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return packTimeline[bestMatch].pack
    }

    private func scheduleSnapshot(for date: Date, in pack: PillPack) -> PillScheduleSnapshot? {
        let day = startOfDaySafe(date)
        let dayEpoch = epochDay(for: day)

        if let cached = snapshotCacheByPackID[pack.id]?[dayEpoch] {
            return cached
        }

        let due = DoseScheduleEngine.dueAction(on: day, pack: pack)
        let dayRecord = dayRecord(forPackID: pack.id, epochDay: dayEpoch)
        let actionType = dayRecord?.actionType ?? due?.type

        let isBeforeActivation: Bool = {
            guard let activation = appActivatedDate else { return false }
            return day < startOfDaySafe(activation, fallback: day)
        }()

        let resolvedStatus: PillDay.Status?
        if let record = dayRecord {
            // Upcoming is non-terminal; recompute fallback state for past dates.
            if record.status != .upcoming {
                resolvedStatus = record.status
            } else if let due {
                if due.type.isBreakType {
                    resolvedStatus = isBeforeActivation ? .noData : .breakDay
                } else if due.type.isPassiveActive {
                    resolvedStatus = isBeforeActivation ? .noData : (day < today ? .taken : .upcoming)
                } else if day < today {
                    resolvedStatus = isBeforeActivation ? .noData : .missed
                } else {
                    resolvedStatus = .upcoming
                }
            } else {
                resolvedStatus = nil
            }
        } else if let due {
            if due.type.isBreakType {
                resolvedStatus = isBeforeActivation ? .noData : .breakDay
            } else if due.type.isPassiveActive {
                resolvedStatus = isBeforeActivation ? .noData : (day < today ? .taken : .upcoming)
            } else if day < today {
                resolvedStatus = isBeforeActivation ? .noData : .missed
            } else {
                resolvedStatus = .upcoming
            }
        } else {
            resolvedStatus = nil
        }

        let snapshot = PillScheduleSnapshot(
            date: day,
            pack: pack,
            cycleDayIndex: pack.cycleDayIndex(on: day, calendar: Calendar.current),
            dueAction: due,
            status: resolvedStatus,
            actionType: actionType
        )

        cache(snapshot: snapshot, forPackID: pack.id, epochDay: dayEpoch)
        return snapshot
    }

    private func dueDatesBackwards(from date: Date, pack: PillPack, maxDueActions: Int) -> [Date] {
        guard maxDueActions > 0 else { return [] }

        let calendar = Calendar.current
        let scanLimitDays = max(365, pack.cycleLength * 24)
        var dueDates: [Date] = []
        var cursor = calendar.startOfDay(for: date)
        var scannedDays = 0

        while dueDates.count < maxDueActions && scannedDays < scanLimitDays {
            if DoseScheduleEngine.dueAction(on: cursor, pack: pack) != nil {
                dueDates.append(cursor)
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
            scannedDays += 1
        }

        return dueDates
    }

    private func epochDay(for date: Date) -> Int {
        Int(startOfDaySafe(date).timeIntervalSince1970)
    }

    private func persist() {
        try? modelContext.save()
    }

    private func scheduleStoreCommit() {
        // Keep taps responsive by committing persistence after immediate UI updates.
        DispatchQueue.main.async { [weak self] in
            self?.persist()
        }
    }

    private func scheduleNotificationResync() {
        // Defer expensive reminder recomputation off the immediate tap frame.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NotificationManager.shared.requestReschedule(from: self, reason: "dose-toggle")
        }
    }

    private func cycleLengthFor(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset,
        customActiveDays: Int?,
        customBreakDays: Int?
    ) -> Int {
        switch method {
        case .pill:
            if regimen == .custom {
                let normalized = PillPack.normalizedCustomValues(active: customActiveDays, breakDays: customBreakDays)
                return normalized.active + normalized.breakDays
            }
            return regimen.cycleLength
        case .patch, .ring:
            return 28
        }
    }

    private func legacyPackType(for regimen: PillPack.PillRegimenPreset) -> PillPack.PackType {
        switch regimen {
        case .twentyOneSeven:
            return .twentyOneSeven
        case .twentyFourFour:
            return .twentyFourFour
        case .twentySixTwo, .twentyEightZero, .eightyFourSeven, .threeSixtyFiveZero, .custom:
            return .twentyEightZero
        }
    }

    private static func normalizedAutoReminderInterval(_ value: Int) -> Int {
        autoReminderIntervalOptions.contains(value) ? value : 10
    }

    private static func normalizedRefillReminderThreshold(_ value: Int) -> Int {
        refillReminderThresholdOptions.contains(value) ? value : 5
    }

    private static func normalizedPatchRestockReminderThreshold(_ value: Int) -> Int {
        patchRestockReminderThresholdOptions.contains(value) ? value : 1
    }
}
