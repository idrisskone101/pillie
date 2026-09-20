protocol FeatureLoading {
    func fetch() async throws -> String
    func save(_ value: String) throws
}

struct LiveFeatureLoading: FeatureLoading {
    func fetch() async throws -> String { "ok" }
    func save(_ value: String) throws {}
}

struct Feature {
    init() {}
}
