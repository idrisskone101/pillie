import SwiftUI

struct ProtectionPlanIntentChoicesSection: View {
    let choices: [DistractionChoice]
    let selected: Set<DistractionChoice>
    let onSelect: (DistractionChoice) -> Void

    var body: some View {
        ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(choices) { choice in
                ProtectionPlanSelectableChip(
                    title: choice.title,
                    isSelected: selected.contains(choice)
                ) {
                    onSelect(choice)
                }
            }
        }
    }
}

struct ProtectionPlanDesiredOutcomeSection: View {
    let title: String
    let subtitle: String
    let outcomes: [DelayConsequence]
    let selected: DelayConsequence?
    let onSelect: (DelayConsequence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProtectionPlanQuestionSectionHeader(title: title, subtitle: subtitle)
            ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(outcomes) { outcome in
                    ProtectionPlanSelectableChip(
                        title: outcome.desiredOutcomeTitle,
                        isSelected: selected == outcome,
                        allowsMultipleSelection: false
                    ) {
                        onSelect(outcome)
                    }
                }
            }
        }
    }
}
