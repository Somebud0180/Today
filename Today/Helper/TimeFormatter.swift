//
//  TimeFormatter.swift
//  Today
//
//  Created by Ethan John Lagera on 6/23/26.
//

import Foundation

struct TimeFormatter {
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    static func accessibleTimeFormat(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        
        let minuteString = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        let secondString = "\(secs) second\(secs == 1 ? "" : "s")"
        
        if hours > 0 {
            let hourString = "\(hours) hour\(hours == 1 ? "" : "s")"
            return "\(hourString), \(minuteString), and \(secondString)"
        } else {
            return "\(minuteString) and \(secondString)"
        }
    }
}
