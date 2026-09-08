import Foundation

enum PillieLocalization {
    private final class BundleToken {}

    static func string(
        _ key: String,
        table: String? = nil,
        locale: Locale = .current
    ) -> String {
        localizedBundle(for: locale).localizedString(
            forKey: key,
            value: nil,
            table: table ?? tableName(for: key)
        )
    }

    static func formatted(
        _ key: String,
        table: String? = nil,
        locale: Locale = .current,
        arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, table: table, locale: locale),
            locale: locale,
            arguments: arguments
        )
    }

    private static func tableName(for key: String) -> String {
        if key.hasPrefix("notification.") {
            return "Notifications"
        }
        if key == "onboarding.demo.free_body"
            || key == "onboarding.blocking_setup.plus_locked" {
            return "Commerce"
        }
        return "Localizable"
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let appBundle = Bundle(for: BundleToken.self)
        for identifier in bundleCandidates(for: locale) {
            if let path = appBundle.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return appBundle
    }

    /// Catalog folders are `ms.lproj`, `zh-Hans.lproj`. `Locale.current` often
    /// reports `ms_MY` / `zh_CN` instead, so try the identifier, hyphen form,
    /// language code, and script from `maximalIdentifier`.
    static func bundleCandidates(for locale: Locale) -> [String] {
        var candidates: [String] = [
            locale.identifier,
            locale.identifier.replacingOccurrences(of: "_", with: "-"),
        ]
        if let code = locale.language.languageCode?.identifier {
            candidates.append(code)
        }
        if let head = locale.identifier.split(whereSeparator: { $0 == "_" || $0 == "-" }).first {
            candidates.append(String(head))
        }
        let maximalParts = locale.language.maximalIdentifier.split(separator: "-").map(String.init)
        if maximalParts.count >= 2, maximalParts[1] == "Hans" || maximalParts[1] == "Hant" {
            candidates.append("\(maximalParts[0])-\(maximalParts[1])")
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted && !$0.isEmpty }
    }
}
