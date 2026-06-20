//
//  ShareSheet.swift
//  Today
//
//  Created by Ethan John Lagera on 6/18/26.
//
//  From https://www.codegenes.net/blog/programmatically-open-sharelink-in-swiftui/#2-programmatic-share-sheets-wrapping-uiactivitycontroller

import SwiftUI
import UIKit
 
// MARK: - UIActivityController Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    /// Content to share (e.g., text, URLs, images)
    var items: [Any]
    /// Optional custom activities (e.g., app-specific sharing)
    var customActivities: [UIActivity]? = nil
    /// Called when the share sheet is dismissed (success/failure)
    var completion: (UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void = { _, _, _, _ in }
 
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: customActivities
        )
        // Set completion handler
        controller.completionWithItemsHandler = completion
        return controller
    }
 
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
