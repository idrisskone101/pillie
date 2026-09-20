struct HomeDependencies {
    var fetch: () -> String
    var save: (String) -> Void
}
