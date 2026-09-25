import UserNotifications

protocol NotificationCenterScheduling: AnyObject {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void)
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    )
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void)
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getDeliveredNotifications(completionHandler: @escaping @Sendable ([UNNotification]) -> Void)
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterScheduling {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }
}
