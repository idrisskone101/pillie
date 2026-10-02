#if os(iOS)
import CoreText
import UIKit

/// Outfit has no CJK glyphs. With `Font.custom`, SwiftUI measures the implicit
/// fallback narrower than it draws it, so a wrapped CJK title sizes itself to
/// its measured width and then ellipsizes the last line. Naming the system's
/// own cascade for the language makes measurement and drawing agree.
enum CJKFontCascade {
    private static let languageCodes: Set<String> = ["ja", "ko", "zh"]
    private static let cache = NSCache<NSString, UIFont>()

    /// Outfit with the system CJK cascade attached, or nil outside CJK languages.
    static func font(name: String, size: CGFloat) -> UIFont? {
        guard let language = cjkLanguage() else { return nil }
        // Matches the body-relative scaling `Font.custom(_:size:)` applies.
        let scaledSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        let key = "\(name)|\(scaledSize)|\(language)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let base = CTFontCreateWithName(name as CFString, scaledSize, nil)
        let cascade = CTFontCopyDefaultCascadeListForLanguages(base, [language] as CFArray)
            as? [UIFontDescriptor] ?? []
        let descriptor = UIFontDescriptor(name: name, size: scaledSize)
            .addingAttributes([.cascadeList: cascade])
        let font = UIFont(descriptor: descriptor, size: scaledSize)
        cache.setObject(font, forKey: key)
        return font
    }

    /// The in-app language choice wins over the device language, as in `AppLanguage.resolvedLocale`.
    private static func cjkLanguage() -> String? {
        let stored = UserDefaults.standard.string(forKey: AppLanguagePreference.storageKey)
        let identifier = AppLanguage(rawValue: stored ?? "")?.catalogIdentifier
            ?? Locale.preferredLanguages.first
            ?? ""
        guard let code = Locale(identifier: identifier).language.languageCode?.identifier,
              languageCodes.contains(code)
        else { return nil }
        return identifier
    }
}
#endif
