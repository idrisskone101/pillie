import Foundation
import Observation

/// In-app language override. `system` follows the iPhone language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"
    case italian = "it"
    case french = "fr"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case dutch = "nl"

    var id: String { rawValue }

    /// Native name, shown in the picker so users can find their language
    /// even when the rest of the UI is still in another locale.
    var nativeName: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portugueseBrazil: return "Português (Brasil)"
        case .dutch: return "Nederlands"
        }
    }

    var catalogIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .german: return "de"
        case .italian: return "it"
        case .french: return "fr"
        case .spanish: return "es"
        case .portugueseBrazil: return "pt-BR"
        case .dutch: return "nl"
        }
    }

    var resolvedLocale: Locale {
        if let catalogIdentifier {
            return Locale(identifier: catalogIdentifier)
        }
        return .autoupdatingCurrent
    }
}

@Observable
@MainActor
final class AppLanguagePreference {
    static let storageKey = "pillie.appLanguage"

    var selection: AppLanguage {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale { selection.resolvedLocale }

    init(defaults: UserDefaults = .standard) {
        let stored = defaults.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        selection = AppLanguage(rawValue: stored) ?? .system
    }
}
