//
//  PillPackCard.swift
//  Pillie
//

import SwiftUI

struct PillPackCard: View {
    @Environment(PillStore.self) var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var hasRunEntranceAnimation = false
    @State private var pendingEntranceAnimation: DispatchWorkItem?
    @State private var cachedCycleSnapshots: [Int: PillScheduleSnapshot] = [:]
    @State private var showNewPackConfirmation = false

    private var cycleLength: Int { store.pack.cycleLength }
    private var currentCycleDay: Int {
        store.currentDayIndex + 1
    }
    private var stripEntranceAnimation: Animation {
        .easeInOut(duration: 1.05)
    }

    private var headerTitle: String {
        switch store.pack.method {
        case .pill:
            return "Pill \(currentCycleDay) · Day \(currentCycleDay)"
        case .patch, .ring:
            return "\(store.pack.methodTitle) Cycle · Day \(currentCycleDay)"
        }
    }

    private var displayedIndices: [Int] {
        let maxWindow = 56
        guard cycleLength > maxWindow else {
            return Array(0..<cycleLength)
        }
        // Start at day 1 (index 0) and shift forward only enough
        // to keep the current day visible near the right edge.
        // Never wrap backwards before index 0.
        let padding = 4  // keep a few upcoming days visible after today
        let minStart = max(0, store.currentDayIndex + padding - maxWindow + 1)
        let start = min(minStart, cycleLength - maxWindow)
        return (0..<maxWindow).map { offset in
            start + offset
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.pillieBodySemibold())
                        .foregroundStyle(.white)

                    Text("Pack \(store.pack.packNumber) · \(store.pack.regimenLabel)")
                        .font(.pillieCaption())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)
                }

                Spacer()

                Menu {
                    Button {
                        showNewPackConfirmation = true
                    } label: {
                        Label(
                            store.pack.method == .pill ? "Start New Pack" : "Start New Cycle",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                } label: {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(displayedIndices, id: \.self) { index in
                            pillCircle(for: index)
                                .id(index)
                        }
                    }
                }
                .onAppear {
                    refreshCycleSnapshots()
                    animatePillStripEntrance(with: proxy)
                }
                .onChange(of: store.protocolChangeVersion) { _, _ in
                    refreshCycleSnapshots()
                    resetAndRecenterPillStrip(with: proxy)
                }
                .onChange(of: store.pack.id) { _, _ in
                    refreshCycleSnapshots()
                    resetAndRecenterPillStrip(with: proxy)
                }
                .onChange(of: store.currentDayIndex) { _, _ in
                    refreshCycleSnapshots()
                }
                .onChange(of: store.isTodayTaken) { _, _ in
                    refreshCycleSnapshots()
                }
                .onDisappear {
                    hasRunEntranceAnimation = false
                    pendingEntranceAnimation?.cancel()
                    pendingEntranceAnimation = nil
                }
            }

            if cycleLength > displayedIndices.count {
                Text("Showing \(displayedIndices.count)-day window")
                    .font(.pillieCaption())
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(1)
            }

            // Footer
            Text("Day \(currentCycleDay) of \(store.pack.cycleLength)")
                .font(.pillieCaption())
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
        }
        .padding(20)
        .background(PillieTheme.dark)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .alert(
            store.pack.method == .pill ? "Start New Pack?" : "Start New Cycle?",
            isPresented: $showNewPackConfirmation
        ) {
            Button(store.pack.method == .pill ? "Start New Pack" : "Start New Cycle") {
                store.startNewPack()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will start a new \(store.pack.method == .pill ? "pack" : "cycle") from today. Your previous history will be preserved.")
        }
    }

    // MARK: - Pill Circle

    @ViewBuilder
    private func pillCircle(for index: Int) -> some View {
        let snapshot = cachedCycleSnapshots[index] ?? store.scheduleSnapshot(forCycleIndex: index, in: store.pack)
        let status = snapshot?.status
        let isCurrent = index == store.currentDayIndex
        let due = snapshot?.dueAction
        let isPassive = snapshot?.isPassiveActive ?? false
        let isBreak = snapshot?.isBreak ?? false

        ZStack {
            if status == .taken {
                Circle()
                    .fill(PillieTheme.sage.opacity(0.24))

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)

                if isCurrent {
                    Circle()
                        .strokeBorder(PillieTheme.coral, lineWidth: 2)
                }
            } else if isCurrent && (due?.type.isBreakType ?? false) {
                Circle()
                    .fill(PillieTheme.lavender)

                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 10, height: 10)
            } else if isCurrent {
                Circle()
                    .fill(PillieTheme.coral)

                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 10, height: 10)
            } else if status == .noData && isPassive {
                // Past passive ring days after cycle-day skip — visually completed
                Circle()
                    .fill(PillieTheme.sage.opacity(0.24))

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else if status == .noData && isBreak {
                // Past break ring days after cycle-day skip — visually break style
                Circle()
                    .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                if due?.type.isBreakType ?? false {
                    Circle()
                        .fill(PillieTheme.lavender.opacity(0.35))
                        .frame(width: 12, height: 12)
                }
            } else if status == .noData {
                Circle()
                    .fill(.white.opacity(0.03))
            } else if status == .missed {
                Circle()
                    .fill(PillieTheme.amber.opacity(0.32))

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else if status == .breakDay {
                Circle()
                    .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                if due?.type.isBreakType ?? false {
                    Circle()
                        .fill(PillieTheme.lavender.opacity(0.35))
                        .frame(width: 12, height: 12)
                }
            } else if due != nil && isPassive {
                Circle()
                    .fill(.white.opacity(0.06))
            } else if due != nil && isBreak {
                Circle()
                    .strokeBorder(.white.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } else if due != nil {
                Circle()
                    .fill(.white.opacity(0.08))
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(.white.opacity(0.03))
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Helpers

    private func normalizedIndex(_ value: Int) -> Int {
        let modulo = value % max(1, cycleLength)
        return modulo >= 0 ? modulo : modulo + cycleLength
    }

    private func animatePillStripEntrance(with proxy: ScrollViewProxy) {
        guard !hasRunEntranceAnimation else { return }
        guard let leftMostIndex = displayedIndices.first else { return }
        hasRunEntranceAnimation = true

        let targetIndex = displayedIndices.contains(store.currentDayIndex) ? store.currentDayIndex : leftMostIndex

        DispatchQueue.main.async {
            var immediateTransaction = Transaction()
            immediateTransaction.disablesAnimations = true

            withTransaction(immediateTransaction) {
                proxy.scrollTo(leftMostIndex, anchor: .leading)
            }

            if accessibilityReduceMotion {
                withTransaction(immediateTransaction) {
                    proxy.scrollTo(targetIndex, anchor: .center)
                }
                return
            }

            pendingEntranceAnimation?.cancel()
            let workItem = DispatchWorkItem {
                withAnimation(stripEntranceAnimation) {
                    proxy.scrollTo(targetIndex, anchor: .center)
                }
            }
            pendingEntranceAnimation = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
        }
    }

    private func resetAndRecenterPillStrip(with proxy: ScrollViewProxy) {
        hasRunEntranceAnimation = false
        pendingEntranceAnimation?.cancel()
        pendingEntranceAnimation = nil
        animatePillStripEntrance(with: proxy)
    }

    private func refreshCycleSnapshots() {
        cachedCycleSnapshots = store.cycleSnapshots(for: displayedIndices, in: store.pack)
    }
}

#Preview {
    PillPackCard()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
