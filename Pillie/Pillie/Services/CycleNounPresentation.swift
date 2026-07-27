import Foundation

enum CycleNounPresentation {
    static func localizedNoun(
        for method: ContraceptiveMethod,
        locale: Locale = .current
    ) -> String {
        let key = method == .pill
            ? "today.pack.noun.pill"
            : "today.pack.noun.cycle"
        return PillieLocalization.string(key, locale: locale)
    }
}
