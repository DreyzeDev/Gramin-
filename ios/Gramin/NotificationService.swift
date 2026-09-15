import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func scheduleWeeklyReport() async {
        let content = UNMutableNotificationContent()
        content.title = "Еженедельный отчёт Gramin"
        content.body = "Откройте приложение, чтобы посмотреть расходы за неделю."
        content.sound = .default
        var date = DateComponents(); date.weekday = 2; date.hour = 10
        let request = UNNotificationRequest(identifier: "weekly-report", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func showLocal(title: String, body: String) async {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
}

