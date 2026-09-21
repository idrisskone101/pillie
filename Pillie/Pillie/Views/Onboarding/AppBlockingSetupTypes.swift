struct AppBlockingSetupPermissionState: Equatable {
    enum Phase: Equatable {
        case ready
        case requesting
        case recovery
    }

    enum Resolution: Equatable {
        case openPicker
        case showRecovery
    }

    private(set) var phase: Phase = .ready

    var isRequesting: Bool { phase == .requesting }
    var isRecoveryVisible: Bool { phase == .recovery }

    mutating func beginRequest() -> Bool {
        guard !isRequesting else { return false }
        phase = .requesting
        return true
    }

    mutating func completeRequest(isAuthorized: Bool) -> Resolution {
        if isAuthorized {
            phase = .ready
            return .openPicker
        }

        phase = .recovery
        return .showRecovery
    }

    /// Simulator FamilyControls authorization is always approved, so DEBUG UI QA
    /// needs a way to render the exact recovery state a real denial reaches.
    mutating func showRecoveryForDebug() {
        phase = .recovery
    }
}

enum AppBlockingSetupPhase: Equatable {
    case empty
    case recovery
    case selected
    case locked

    static func resolve(
        canSetUpBlocking: Bool,
        isEmpty: Bool,
        isRecoveryVisible: Bool
    ) -> Self {
        guard canSetUpBlocking else { return .locked }
        if isRecoveryVisible { return .recovery }
        return isEmpty ? .empty : .selected
    }
}

enum AppBlockingSetupPrimaryAction: Equatable {
    case requestAuthorization
    case finishSetup

    static func resolve(hasSelection: Bool, isAuthorized: Bool) -> Self {
        hasSelection && isAuthorized ? .finishSetup : .requestAuthorization
    }
}
