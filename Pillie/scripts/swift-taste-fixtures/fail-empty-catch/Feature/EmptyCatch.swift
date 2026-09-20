import Foundation

enum FixtureOp {
    static func load() async {
        do {
            _ = try await Task { "ok" }.value
        } catch {
        }
    }
}
