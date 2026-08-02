import Foundation

enum CycleNounPresentation {
    struct StartNewConfirmation: Equatable {
        let title: String
        let body: String
    }

    static func localizedNoun(
        for method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> String {
        let key = method == .pill
            ? "today.pack.noun.pill"
            : "today.pack.noun.cycle"
        return PillieLocalization.string(key, locale: locale)
    }

    static func startNewConfirmation(
        for method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> StartNewConfirmation {
        let keySuffix = method == .pill ? "pill" : "cycle"
        return StartNewConfirmation(
            title: PillieLocalization.string(
                "today.pack.start_new.\(keySuffix).title",
                locale: locale
            ),
            body: PillieLocalization.string(
                "today.pack.start_new.\(keySuffix).body",
                locale: locale
            )
        )
    }
}
