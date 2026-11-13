#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct BlockingRehearsalDebugSeedTests {
    private func seed(_ query: String, path: String = "/plus-app-blocking-setup") -> BlockingRehearsalDebugSeed? {
        BlockingRehearsalDebugSeed(link: "pillie://debug\(path)\(query.isEmpty ? "" : "?\(query)")")
    }

    private func opened(_ query: String, voiceOver: Bool = false) throws -> (BlockingRehearsalState, [BlockingRehearsalEffect]) {
        var opening = BlockingRehearsalOpening(
            demoSeen: false, hasSelection: false, isAuthorized: true, voiceOverRunning: voiceOver
        )
        opening.debugSeed = try #require(seed(query))
        var state = BlockingRehearsalState()
        let effects = state.handle(.appeared(opening))
        return (state, effects)
    }

    // MARK: Parsing

    @Test(arguments: BlockingRehearsalStage.allCases)
    func `The stage parameter names any stage`(stage: BlockingRehearsalStage) {
        #expect(seed("stage=\(stage.rawValue)&lang=en")?.stage == stage)
    }

    @Test func `The bare setup link opens the ask`() {
        #expect(seed("")?.stage == .ask)
        #expect(seed("lang=de&terms=hard")?.stage == .ask)
        #expect(seed("stage=nonsense")?.stage == .ask)
    }

    @Test func `A selection count means the picks with that many sample tiles`() {
        #expect(seed("selected=8")?.stage == .picks)
        #expect(seed("selected=8")?.sampleTileCount == 8)
        #expect(seed("stage=picks")?.sampleTileCount == 4)
        #expect(seed("selected=0")?.stage == .ask)
        #expect(seed("stage=ask&selected=3")?.sampleTileCount == 0)
    }

    @Test func `The refused stage shows either reason`() {
        #expect(seed("stage=refused")?.refusal == .notAllowed)
        #expect(seed("stage=refused&reason=cancelled")?.refusal == .notAllowed)
        #expect(seed("stage=refused&reason=conflict")?.refusal == .heldByAnotherApp)
    }

    @Test func `A seeded beat holds still unless self-play is turned on`() {
        #expect(seed("stage=reminder")?.selfPlays == false)
        #expect(seed("stage=reminder&selfPlay=off")?.selfPlays == false)
        #expect(seed("stage=reminder&selfPlay=on")?.selfPlays == true)
    }

    @Test func `Access can be drawn as not yet asked`() {
        #expect(seed("stage=ask&access=notAsked")?.accessNotAsked == true)
        #expect(seed("stage=ask")?.accessNotAsked == false)
    }

    @Test func `The featured app can be picked`() {
        #expect(seed("stage=paused&featured=instagram")?.featuredApp == .instagram)
        #expect(seed("stage=paused")?.featuredApp == nil)
        #expect(seed("stage=paused&featured=snapchat")?.featuredApp == nil)
    }

    @Test func `Another debug link seeds only when it names a stage`() {
        #expect(seed("lang=en", path: "/trial-granted-moment") == nil)
        #expect(seed("stage=ask&lang=en", path: "/trial-granted-moment")?.stage == .ask)
        #expect(BlockingRehearsalDebugSeed(link: "") == nil)
    }

    @Test func `The same link opened twice is two different stored values with one meaning`() {
        let link = "pillie://debug/plus-app-blocking-setup?stage=shake"
        #expect(BlockingRehearsalDebugSeed(link: "\(link)#first") == BlockingRehearsalDebugSeed(link: "\(link)#second"))
        #expect(BlockingRehearsalDebugSeed(link: "\(link)#first")?.stage == .shake)
    }

    // MARK: Opening the state from a seed

    @Test func `A seeded beat opens on that beat, reports it, and waits for a tap`() throws {
        let (state, effects) = try opened("stage=paused")
        #expect(effects == [.report(.viewed(.paused))])
        #expect(state.stage == .paused)
        #expect(state.timer == nil)

        var tapped = state
        #expect(tapped.handle(.beatControlTapped) == [.report(.played(.paused, by: .herTap))])
        #expect(tapped.timer == .coralSpreads(by: .herTap))
    }

    @Test func `With self-play on a seeded beat plays itself`() throws {
        let (state, _) = try opened("stage=shake&selfPlay=on")
        #expect(state.stage == .shake)
        #expect(state.timer == .selfPlay(.shake))
    }

    @Test func `A seeded refusal carries its reason and can be answered`() throws {
        var (state, effects) = try opened("stage=refused&reason=conflict")
        #expect(effects == [.report(.viewed(.refused))])
        #expect(state.refusal == .heldByAnotherApp)
        #expect(state.handle(.remindersOnlyTapped) == [.report(.choseRemindersOnly(on: .refused)), .useRemindersOnly])
    }

    @Test func `A seed with access not asked opens the ask with no way out until Apple answers`() throws {
        var (state, _) = try opened("stage=ask&access=notAsked")
        #expect(!state.isAuthorized)
        #expect(state.handle(.remindersOnlyTapped) == [])
        #expect(state.handle(.chooseTapped) == [.authorize])
        #expect(state.handle(.authorizationResolved(.granted)) == [.presentPicker])
        #expect(state.isAuthorized)
    }

    @Test func `A seeded ask on the always-allowed simulator has the way out`() throws {
        var (state, _) = try opened("stage=ask")
        #expect(state.isAuthorized)
        #expect(
            state.handle(.remindersOnlyTapped)
                == [.report(.choseRemindersOnly(on: .ask)), .useRemindersOnly]
        )
    }

    @Test func `A link opened while the screen is up moves it to the new stage`() throws {
        var (state, _) = try opened("stage=reminder")
        let effects = state.handle(.debugSeeded(try #require(seed("stage=ask"))))
        #expect(effects == [.report(.viewed(.ask))])
        #expect(state.stage == .ask)
        #expect(state.handle(.chooseTapped) == [.authorize])
    }
}
#endif
