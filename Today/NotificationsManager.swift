//
//  NotificationsManager.swift
//  Today
//
//  Created by Ethan John Lagera on 6/7/26.
//
//  Referenced from https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
//  Scheduling local notifications by Paul Hudson

import Foundation
import UserNotifications

struct NotificationsManager {
    static func registerReminderNotification(_ reminderTime: Date) {
        // Remove existing notifications to avoid duplicates
        unregisterReminderNotifications()
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Today"
        content.subtitle = "It's time for your daily journal, spend some time in the app."
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderTime.timeIntervalSinceNow, repeats: true)
        
        // Choose a random identifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // Add our notification request
        UNUserNotificationCenter.current().add(request)
    }
    
    static func unregisterReminderNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
