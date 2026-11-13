//
//  BlockingRehearsalDebug.swift
//  Pillie
//
//  QA entry points. One debug link opens any stage of the blocking step:
//
//    pillie://debug/plus-app-blocking-setup
//        ?stage=reminder|paused|shake|ask|refused|picks
//        &selected=N                  N sample tiles on the picks card (implies stage=picks)
//        &reason=cancelled|conflict   which refusal the refused stage shows
//        &featured=tiktok|instagram|youtube|messages
//        &selfPlay=on                 let a seeded beat play itself (it holds still otherwise)
//        &access=notAsked             draw the stage as before Apple's prompt (the simulator is always allowed)
//        &terms=hard&expired=1        the locked screen
//
//  With no `stage` and no `selected` the link opens the ask. `stage=` works on
//  any other debug link that lands on the step too.
//

#if DEBUG
import Foundation

struct BlockingRehearsalDebugSeed: Equatable {
    static let storageKey = "pillie_debug_blocking_rehearsal_seed"
    static let setupPath = "/plus-app-blocking-setup"

    let stage: BlockingRehearsalStage
    let refusal: ScreenTimeRefusal
    let featuredApp: BlockingRehearsalApp?
    /// False by default, so a seeded beat is the same screenshot every run.
    let selfPlays: Bool
    /// The simulator always reports Screen Time as allowed. This draws the
    /// stage as a first-time user sees it, until the next request "allows" it.
    let accessNotAsked: Bool
    let sampleTileCount: Int

    init?(link: String) {
        guard let components = URLComponents(string: link) else { return nil }
        func value(_ name: String) -> String? {
            components.queryItems?.first { $0.name == name }?.value
        }

        let selected = value("selected").flatMap(Int.init).map { max($0, 0) } ?? 0
        if let stage = value("stage").flatMap(BlockingRehearsalStage.init(rawValue:)) {
            self.stage = stage
        } else if selected > 0 {
            stage = .picks
        } else if components.path == Self.setupPath {
            stage = .ask
        } else {
            return nil
        }

        refusal = value("reason").flatMap(ScreenTimeRefusal.init(rawValue:)) ?? .notAllowed
        featuredApp = value("featured").flatMap(BlockingRehearsalApp.init(rawValue:))
        selfPlays = value("selfPlay") == "on"
        accessNotAsked = value("access") == "notAsked"
        sampleTileCount = stage == .picks ? (selected > 0 ? selected : 4) : 0
    }

    static func arm(with url: URL, defaults: UserDefaults = .standard) {
        guard let seed = BlockingRehearsalDebugSeed(link: url.absoluteString) else { return }
        // The fragment makes a repeated link a new value, so it seeds again.
        defaults.set("\(url.absoluteString)#\(UUID().uuidString)", forKey: storageKey)

        let manager = AppBlockingManager.shared
        manager.debugSelectionCountOverride = seed.sampleTileCount > 0 ? seed.sampleTileCount : nil
        if seed.stage == .refused {
            manager.debugSimulatorRefusal = seed.refusal
            manager.updateAuthorizationStatus()
        }
    }
}

/// A tile that stands in for a FamilyControls token on the simulator.
struct BlockingRehearsalSamplePick: Hashable {
    enum Kind: Hashable {
        case category(symbol: String)
        case application(BlockingRehearsalIcon)
        case webDomain

        fileprivate var group: Int {
            switch self {
            case .category: 0
            case .application: 1
            case .webDomain: 2
            }
        }
    }

    let kind: Kind
    /// English and never localized: it stands in for a name iOS would draw.
    let name: String

    private static let cycle: [BlockingRehearsalSamplePick] = [
        BlockingRehearsalSamplePick(kind: .category(symbol: "bubble.left.fill"), name: "Social"),
        BlockingRehearsalSamplePick(kind: .category(symbol: "gamecontroller.fill"), name: "Games"),
        BlockingRehearsalSamplePick(kind: .application(.youtube), name: "YouTube"),
        BlockingRehearsalSamplePick(kind: .webDomain, name: "reddit.com"),
        BlockingRehearsalSamplePick(kind: .application(.tiktok), name: "TikTok"),
        BlockingRehearsalSamplePick(kind: .application(.instagram), name: "Instagram"),
        BlockingRehearsalSamplePick(kind: .application(.messages), name: "Messages"),
        BlockingRehearsalSamplePick(kind: .webDomain, name: "news.example.com"),
    ]

    static func tiles(count: Int) -> [BlockingRehearsalPick] {
        let samples = (0..<max(count, 0)).map { index in
            let base = cycle[index % cycle.count]
            let lap = index / cycle.count
            return lap == 0 ? base : BlockingRehearsalSamplePick(kind: base.kind, name: "\(base.name) \(lap + 1)")
        }
        return [0, 1, 2].flatMap { group in
            samples.filter { $0.kind.group == group }.map(BlockingRehearsalPick.sample)
        }
    }
}
#endif
