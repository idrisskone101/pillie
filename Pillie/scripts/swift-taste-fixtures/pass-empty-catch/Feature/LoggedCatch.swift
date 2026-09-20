import Foundation
import os

enum FixtureOp {
    static func load() async {
        do {
            _ = try await Task { "ok" }.value
        } catch {
            let log = Logger(subsystem: "pillie.fixture", category: "taste")
            log.error("fixture.load failed id=selftest cause=\(error.localizedDescription, privacy: .public)")
        }
    }
}
