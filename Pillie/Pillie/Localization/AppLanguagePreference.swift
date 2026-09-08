import Foundation
import Observation

/// In-app language override. `system` follows the iPhone language.
///
/// Every case except `system` is a String Catalog language the app ships.
/// `rawValue` doubles as the catalog identifier and the persisted value.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case arabic = "ar"
    case bengali = "bn"
    case catalan = "ca"
    case czech = "cs"
    case danish = "da"
    case german = "de"
    case greek = "el"
    case spanish = "es"
    case finnish = "fi"
    case french = "fr"
    case gujarati = "gu"
    case hebrew = "he"
    case hindi = "hi"
    case croatian = "hr"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case kannada = "kn"
    case korean = "ko"
    case malayalam = "ml"
    case marathi = "mr"
    case malay = "ms"
    case norwegianBokmal = "nb"
    case dutch = "nl"
    case odia = "or"
    case punjabi = "pa"
    case polish = "pl"
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case swedish = "sv"
    case tamil = "ta"
    case telugu = "te"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case urdu = "ur"
    case vietnamese = "vi"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var id: String { rawValue }

    /// Native name, shown in the picker so users can find their language
    /// even when the rest of the UI is still in another locale.
    var nativeName: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .arabic: return "العربية"
        case .bengali: return "বাংলা"
        case .catalan: return "Català"
        case .czech: return "Čeština"
        case .danish: return "Dansk"
        case .german: return "Deutsch"
        case .greek: return "Ελληνικά"
        case .spanish: return "Español"
        case .finnish: return "Suomi"
        case .french: return "Français"
        case .gujarati: return "ગુજરાતી"
        case .hebrew: return "עברית"
        case .hindi: return "हिन्दी"
        case .croatian: return "Hrvatski"
        case .hungarian: return "Magyar"
        case .indonesian: return "Bahasa Indonesia"
        case .italian: return "Italiano"
        case .japanese: return "日本語"
        case .kannada: return "ಕನ್ನಡ"
        case .korean: return "한국어"
        case .malayalam: return "മലയാളം"
        case .marathi: return "मराठी"
        case .malay: return "Bahasa Melayu"
        case .norwegianBokmal: return "Norsk bokmål"
        case .dutch: return "Nederlands"
        case .odia: return "ଓଡ଼ିଆ"
        case .punjabi: return "ਪੰਜਾਬੀ"
        case .polish: return "Polski"
        case .portugueseBrazil: return "Português (Brasil)"
        case .portuguesePortugal: return "Português (Portugal)"
        case .romanian: return "Română"
        case .russian: return "Русский"
        case .slovak: return "Slovenčina"
        case .slovenian: return "Slovenščina"
        case .swedish: return "Svenska"
        case .tamil: return "தமிழ்"
        case .telugu: return "తెలుగు"
        case .thai: return "ไทย"
        case .turkish: return "Türkçe"
        case .ukrainian: return "Українська"
        case .urdu: return "اردو"
        case .vietnamese: return "Tiếng Việt"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }

    var catalogIdentifier: String? {
        self == .system ? nil : rawValue
    }

    var resolvedLocale: Locale {
        if let catalogIdentifier {
            return Locale(identifier: catalogIdentifier)
        }
        return .autoupdatingCurrent
    }

    /// Picker order: System first, English second, then every other language
    /// sorted by its native name so users can scan the list.
    static var pickerOrder: [AppLanguage] {
        let rest = allCases
            .filter { $0 != .system && $0 != .english }
            .sorted { $0.nativeName.localizedStandardCompare($1.nativeName) == .orderedAscending }
        return [.system, .english] + rest
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
