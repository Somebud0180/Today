import Foundation
import UserNotifications
import SwiftUI

struct NotificationsManager {
    @AppStorage("reminderTime") private static var savedReminderTime: Date = DefaultSettings.reminderTime
    @AppStorage("remindMeToJournal") private static var remindersEnabled: Bool = DefaultSettings.remindMeToJournal
    private static var schedulingTask: Task<Void, Never>?
    static let identifierPrefix = "journal-reminder-"

    /// A rolling window lets saving skip today's reminder without deleting future ones.
    /// Refresh on foreground and settings changes; leave headroom under the pending limit.
    static func reminderDates(time: Date, now: Date, skipToday: Bool, calendar: Calendar = .current) -> [Date] {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return (0..<60).compactMap { offset in
            guard !(skipToday && offset == 0),
                  let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let date = calendar.date(bySettingHour: components.hour ?? 20, minute: components.minute ?? 0, second: 0, of: day),
                  date > now else { return nil }
            return date
        }
    }

    static func registerReminderNotification(_ reminderTime: Date) {
        let lastEntry = UserDefaults.standard.object(forKey: "lastJournalSaveDate") as? Date
        let skipToday = lastEntry.map { Calendar.current.isDateInToday($0) } ?? false
        schedule(time: reminderTime, skipToday: skipToday)
    }

    private static func schedule(time: Date?, skipToday: Bool) {
        schedulingTask?.cancel()
        let previousTask = schedulingTask
        schedulingTask = Task {
            await previousTask?.value
            guard !Task.isCancelled else { return }
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            // Include the legacy date-based identifiers when migrating existing installs.
            center.removePendingNotificationRequests(withIdentifiers: pending.filter {
                $0.identifier.hasPrefix(identifierPrefix) || $0.content.body == "It's time for your daily journal, spend some time in the app."
            }.map(\.identifier))
            guard let time else { return }
            for date in reminderDates(time: time, now: Date(), skipToday: skipToday) {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = "Today"
                content.body = "It's time for your daily journal, spend some time in the app."
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let request = UNNotificationRequest(identifier: identifierPrefix + String(Int(date.timeIntervalSince1970)), content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                do { try await center.add(request) }
                catch { print("Could not schedule journal reminder: \(error)") }
            }
        }
    }

    static func unregisterReminderNotifications() { schedule(time: nil, skipToday: false) }

    static func cancelCurrentReminderNotification() {
        UserDefaults.standard.set(Date(), forKey: "lastJournalSaveDate")
        refresh()
    }

    static func refresh() {
        guard remindersEnabled else { unregisterReminderNotifications(); return }
        registerReminderNotification(savedReminderTime)
    }

    static func notificatonPermissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
