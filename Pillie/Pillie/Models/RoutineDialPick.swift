//
//  RoutineDialPick.swift
//  Pillie
//

import Foundation

struct RoutineDialPick: OnboardingDraftPick {
    let method: RoutineDialMethod
    let cycleDay: Int
    let answer: TodayPillPick.Answer?

    init?(method: RoutineDialMethod, cycleDay: Int, answer: TodayPillPick.Answer?) {
        guard (1...RoutineDialDay.cycleLength).contains(cycleDay) else { return nil }
        let asksQuestion = RoutineDialDay.day(cycleDay, method: method).task != nil
        guard asksQuestion ? answer != nil : answer == nil else { return nil }
        self.method = method
        self.cycleDay = cycleDay
        self.answer = answer
    }

    var day: RoutineDialDay {
        RoutineDialDay.day(cycleDay, method: method)
    }

    var logsAnAction: Bool {
        answer == .taken
    }

    static let storageKey = "pillie_onboarding_routine_dial_pick"

    private enum CodingKeys: String, CodingKey {
        case method
        case cycleDay
        case answer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let pick = RoutineDialPick(
            method: try container.decode(RoutineDialMethod.self, forKey: .method),
            cycleDay: try container.decode(Int.self, forKey: .cycleDay),
            answer: try container.decodeIfPresent(TodayPillPick.Answer.self, forKey: .answer)
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "pick does not fit its cycle")
            )
        }
        self = pick
    }
}
