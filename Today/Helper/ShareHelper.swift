//
//  ShareHelper.swift
//  Today
//
//  Created by Ethan John Lagera on 6/26/26.
//

import Foundation
import SwiftUI

@Observable
final class ShareHelper {
    var isPreparingShare: Bool = false
    var sharedURLs: [URL] = []
    var showShareSheet: Bool = false
    
    func prepareEntryForSharing(_ entry: JournalEntry) async {
        await prepareEntriesForSharing([entry])
    }
    
    @MainActor
    func prepareEntriesForSharing(_ selectedEntries: [JournalEntry]) async {
        withAnimation(.snappy) {
            isPreparingShare = true
        }
        
        var urls: [URL] = []
        for entry in selectedEntries {
            if let url = await entry.exportMediaURLForSharing() {
                urls.append(url)
            }
        }
        
        self.sharedURLs = urls
        
        withAnimation(.snappy) {
            self.isPreparingShare = false
        }
        
        if !urls.isEmpty {
            showShareSheet = true
        }
    }
}
