import SwiftUI

struct ProtectionPlanFrequencyChoicesSection: View {
    let options: [ProtectionPlanFailureFrequencyContent.Option]
    let selected: MissFrequency?
    let onSelect: (MissFrequency) -> Void

    var body: some View {
        ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(options) { option in
                ProtectionPlanSelectableChip(
                    title: option.title,
                    isSelected: selected == option.bucket,
                    allowsMultipleSelection: false
                ) {
                    onSelect(option.bucket)
                }
            }
        }
    }
}

struct ProtectionPlanRiskWindowChoicesSection: View {
    let title: String
    let subtitle: String
    let choices: [RiskWindow]
    let selected: RiskWindow?
    let onSelect: (RiskWindow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProtectionPlanQuestionSectionHeader(title: title, subtitle: subtitle)
            ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(choices) { window in
                    ProtectionPlanSelectableChip(
                        title: window.title,
                        isSelected: selected == window,
                        allowsMultipleSelection: false
                    ) {
                        onSelect(window)
                    }
                }
            }
        }
    }
}
