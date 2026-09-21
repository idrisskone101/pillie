enum RoutineExactDayCardAction: Equatable {
    case expand
    case collapse

    static func resolve(isEditingExactDay: Bool) -> Self {
        isEditingExactDay ? .collapse : .expand
    }
}
