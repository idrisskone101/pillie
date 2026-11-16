//
//  BlockingRehearsalDebug.swift
//  Pillie
//
//  QA entry points. One debug link opens any stage of the blocking step:
//
//    pillie://debug/plus-app-blocking-setup
//        ?stage=reminder|paused|shake|ask|refused|picks
//        &selected=N                  a stand-in selection of N picks (implies stage=picks)
//        &reason=cancelled|conflict   which refusal the refused stage shows
//        &featured=tiktok|instagram|youtube|messages
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
    /// The simulator always reports Screen Time as allowed. This draws the
    /// stage as a first-time user sees it, until the next request "allows" it.
    let accessNotAsked: Bool
    let stubSelectionCount: Int

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
        accessNotAsked = value("access") == "notAsked"
        stubSelectionCount = stage == .picks ? (selected > 0 ? selected : 4) : 0
    }

    static func arm(with url: URL, defaults: UserDefaults = .standard) {
        guard let seed = BlockingRehearsalDebugSeed(link: url.absoluteString) else { return }
        // The fragment makes a repeated link a new value, so it seeds again.
        defaults.set("\(url.absoluteString)#\(UUID().uuidString)", forKey: storageKey)

        let manager = AppBlockingManager.shared
        manager.debugSelectionCountOverride = seed.stubSelectionCount > 0 ? seed.stubSelectionCount : nil
        if seed.stage == .refused {
            manager.debugSimulatorRefusal = seed.refusal
            manager.updateAuthorizationStatus()
        }
    }
}

#endif
