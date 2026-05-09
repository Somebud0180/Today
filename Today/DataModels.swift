//
//  DataModels.swift
//  Today
//
//  Created by Ethan John Lagera on 5/9/26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class JournalEntries: Identifiable {
    var uuid: UUID = UUID()
    @Relationship(deleteRule: .cascade) var entries: [JournalEntry] = []
    
    init(entries: [JournalEntry]) {
        self.entries = entries
    }
}

@Model
class JournalEntry: Identifiable{
    var uuid: UUID = UUID()
    var date: Date = Date()
    var videoName: String = ""
    var title: String = ""
    var note: String = ""
    
    init(videoName: String, note: String) {
        self.videoName = videoName
        self.note = note
    }
}
