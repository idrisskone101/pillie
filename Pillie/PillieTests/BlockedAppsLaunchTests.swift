import Testing

@testable import Pillie

struct BlockedAppsLaunchTests {
    @Test func unauthorizedLaunchRequestsScreenTimeBeforeTheEditorSheet() {
        #expect(BlockedAppsLaunch.make(isAuthorized: false) == .authorizeThenPresentEditor)
    }

    @Test func authorizedLaunchPresentsTheEditorWithoutAnotherSystemPrompt() {
        #expect(BlockedAppsLaunch.make(isAuthorized: true) == .presentEditor)
    }

    @Test func pickerStaysClosedUntilScreenTimeIsApproved() {
        #expect(BlockedAppsPickerGate.make(isAuthorized: false) == .waitForAuthorization)
        #expect(BlockedAppsPickerGate.make(isAuthorized: true) == .presentPicker)
    }
}
