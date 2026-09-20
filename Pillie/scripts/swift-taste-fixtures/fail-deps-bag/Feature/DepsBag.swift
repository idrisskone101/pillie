struct Dependencies {
    var fetch: () async throws -> String
    var save: (String) throws -> Void
}

struct Feature {
    init(dependencies: Dependencies) {
        _ = dependencies
    }
}
