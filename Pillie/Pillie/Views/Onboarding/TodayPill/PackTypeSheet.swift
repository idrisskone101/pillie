//
//  PackTypeSheet.swift
//  Pillie
//

import SwiftUI

struct PackTypeSheet: View {
    let current: PackChoice
    let onPick: (PackChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentHeight: CGFloat = 640

    private let feedback = OnboardingInteractionFeedback()

    private static let tiles = PillPack.PillRegimenPreset.allCases.compactMap(\.packSheetTile)
    private static let tileRows = stride(from: 0, to: tiles.count, by: 2).map { Array(tiles[$0..<min($0 + 2, tiles.count)]) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PillieLocalization.string("onboarding.pack_sheet.title"))
                        .font(.pillie(26, weight: .bold))
                        .tracking(-0.52)
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("packSheetTitle")
                    Text(PillieLocalization.string("onboarding.pack_sheet.subtitle"))
                        .font(.pillie(15, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)

                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(Self.tileRows, id: \.first?.preset) { row in
                        GridRow {
                            ForEach(row, id: \.preset) { tile in
                                PackTypeTile(tile: tile, isSelected: tile.preset == current.preset) {
                                    pick(tile.preset)
                                }
                            }
                        }
                    }
                }

                Text(PillieLocalization.string("onboarding.pack_sheet.footer"))
                    .font(.pillie(14, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.top, 31)
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
            .padding(.bottom, 30)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(PillieTheme.bg)
    }

    private func pick(_ preset: PillPack.PillRegimenPreset) {
        feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
        let choice = PackChoice(preset: preset)
        if choice != current { onPick(choice) }
        dismiss()
    }
}

private struct PackTypeTile: View {
    let tile: PackSheetTile
    let isSelected: Bool
    let onTap: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    private var regimen: PackRegimen {
        tile.preset.resolvedRegimen(custom: nil)
    }

    private var title: String {
        switch tile.title {
        case .routineName: tile.preset.localizedRoutineDisplayName()
        case .split: "\(regimen.activeDays) + \(regimen.breakDays)"
        }
    }

    private var detail: String {
        PillieLocalization.string(tile.detailKey)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                PackGlyph(regimen: regimen, size: .tile)
                    .frame(width: 84, height: 46, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                    Text(detail)
                        .font(.pillie(12, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Self.shape.fill(isSelected ? PillieTheme.coralLight : PillieTheme.cardWhite))
            .overlay(
                Self.shape.strokeBorder(
                    isSelected ? PillieTheme.coral : Color.black.opacity(0.05),
                    lineWidth: isSelected ? 2 : 1.5
                )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected { checkBadge }
            }
            .shadow(color: .black.opacity(isSelected ? 0 : 0.04), radius: 5, y: 5)
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("packSheet.\(tile.idSuffix)")
    }

    private var checkBadge: some View {
        Circle()
            .fill(PillieTheme.coral)
            .frame(width: 22, height: 22)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 2.5, y: 6.25))
                    path.addLine(to: CGPoint(x: 4.75, y: 8.5))
                    path.addLine(to: CGPoint(x: 9.5, y: 3.75))
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 12)
            )
            .padding(12)
            .accessibilityHidden(true)
    }
}

private struct PackSheetTile {
    enum Title {
        case routineName
        case split
    }

    let preset: PillPack.PillRegimenPreset
    let title: Title
    let detailKey: String
    let idSuffix: String
}

private extension PillPack.PillRegimenPreset {
    // Custom stays off the sheet until ENG-147 ships its editor.
    var packSheetTile: PackSheetTile? {
        switch self {
        case .twentyOneSeven:
            PackSheetTile(preset: self, title: .split, detailKey: "onboarding.pack_sheet.detail.21_7", idSuffix: "21_7")
        case .twentyOneOnly:
            PackSheetTile(preset: self, title: .routineName, detailKey: "onboarding.pack_sheet.detail.21_only", idSuffix: "21_only")
        case .twentyFourFour:
            PackSheetTile(preset: self, title: .split, detailKey: "onboarding.pack_sheet.detail.24_4", idSuffix: "24_4")
        case .twentySixTwo:
            PackSheetTile(preset: self, title: .split, detailKey: "onboarding.pack_sheet.detail.26_2", idSuffix: "26_2")
        case .everyDay:
            PackSheetTile(preset: self, title: .routineName, detailKey: "onboarding.pack_sheet.detail.28_0", idSuffix: "28_0")
        case .twentyOneFour:
            PackSheetTile(preset: self, title: .split, detailKey: "onboarding.pack_sheet.detail.21_4", idSuffix: "21_4")
        case .custom:
            nil
        }
    }
}
