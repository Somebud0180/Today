//
//  NotificationsManager.swift
//  Today
//
//  Created by Ethan John Lagera on 6/7/26.
//
//  Referenced from https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
//  Scheduling local notifications by Paul Hudson
//
//  Additional reference from
//  https://www.createwithswift.com/notifications-tutorial-creating-and-scheduling-user-notifications-with-async-await/
//  Creating and Scheduling Local Notifications with async/await by Tiago Gomes Pereira

import Foundation
import UserNotifications

struct NotificationsManager {
    static func registerReminderNotification(_ reminderTime: Date) {
        // Create the date components for the notification trigger
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        dateComponents.hour = Calendar.current.component(.hour, from: reminderTime)
        dateComponents.minute = Calendar.current.component(.minute, from: reminderTime)
        
        // Remove existing notifications to avoid duplicates
        unregisterReminderNotifications()
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Today"
        content.body = "It's time for your daily journal, spend some time in the app."
        content.sound = UNNotificationSound.default
        
        // Create the notification trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Set a predictable identifier
        let identifier = Date().formatted(date: .numeric, time: .omitted)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add our notification request
        UNUserNotificationCenter.current().add(request)
    }
    
    static func unregisterReminderNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    static func cancelCurrentReminderNotification() {
        let currentDate = Date().formatted(date: .numeric, time: .omitted)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [currentDate])
    }
    
    static func notificatonPermissionStatus() async -> UNAuthorizationStatus {
        let current = UNUserNotificationCenter.current()
        let settings = await current.notificationSettings()
        
        return settings.authorizationStatus
    }
}
