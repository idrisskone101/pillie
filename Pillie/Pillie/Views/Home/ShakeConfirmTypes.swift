import Foundation

struct ShakeProgress: Equatable {
    let shakes: Int
    let total: Int

    init(shakes: Int, total: Int) {
        self.shakes = min(max(0, shakes), total)
        self.total = total
    }

    var isDone: Bool { shakes >= total }
    var isPastHalfway: Bool { shakes * 2 > total }
    var fraction: Double { Double(shakes) / Double(total) }

    /// The last shake's clip slice still plays before the reveal, so until then
    /// a finished count reads as the step before it.
    func shown(revealed: Bool) -> ShakeProgress {
        revealed ? self : ShakeProgress(shakes: min(shakes, total - 1), total: total)
    }

    var halftoneIndex: Int {
        if isDone { return 3 }
        if shakes == 0 { return 0 }
        return isPastHalfway ? 2 : 1
    }

    func headline(streak: StreakChange) -> ShakeHeadline {
        let kept = streak.isKept
        if isDone {
            return ShakeHeadline(key: kept ? "shake.streak.headline.kept" : "global.action.done")
        }
        if shakes == 0 {
            return ShakeHeadline(key: kept ? "shake.streak.headline.start" : "today.action.shake")
        }
        if shakes == total - 1 {
            return kept
                ? ShakeHeadline(key: "shake.streak.headline.almost_count", number: streak.after)
                : ShakeHeadline(key: "shake.streak.headline.almost")
        }
        return kept
            ? ShakeHeadline(key: "shake.streak.headline.counting", number: streak.before)
            : ShakeHeadline(key: "shake.streak.headline.keep_going")
    }
}

struct ShakeHeadline: Equatable {
    let key: String
    var number: Int?

    func text(locale: Locale) -> String {
        guard let number else { return PillieLocalization.string(key, locale: locale) }
        return PillieLocalization.formatted(key, locale: locale, arguments: Int64(number))
    }
}

struct ShakeLoggedNote: Equatable {
    let key: String
    let pillNumber: Int?

    init(action: DoseScheduleAction) {
        key = DueActionCopy.loggedKey(for: action)
        pillNumber = action.method == .pill ? action.cycleDay : nil
    }

    func text(loggedAt time: String, locale: Locale) -> String {
        guard let pillNumber else { return PillieLocalization.formatted(key, locale: locale, arguments: time) }
        return PillieLocalization.formatted(key, locale: locale, arguments: Int64(pillNumber), time)
    }
}

struct StreakChange: Equatable {
    let before: Int
    let after: Int

    static let none = StreakChange(before: 0, after: 0)

    var isKept: Bool { before > 0 && after > before }
}

struct StreakOdometerDigits: Equatable {
    struct Wheel: Equatable {
        let from: Character?
        let to: Character

        var rolls: Bool { from != to }
    }

    let wheels: [Wheel]

    init(from: Int, to: Int) {
        let old = Array(String(max(0, from)))
        let new = Array(String(max(0, to)))
        let padding = max(0, new.count - old.count)
        let alignedOld = Array(
            ([Character?](repeating: nil, count: padding) + old.map { Optional($0) }).suffix(new.count)
        )
        wheels = zip(alignedOld, new).map { Wheel(from: $0, to: $1) }
    }
}
