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
        let identifiers = [
            locale.identifier,
            locale.language.languageCode?.identifier,
        ].compactMap { $0 }

        for identifier in identifiers {
            if let path = appBundle.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return appBundle
    }
}
