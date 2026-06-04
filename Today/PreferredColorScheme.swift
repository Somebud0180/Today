//
//  PreferredColorScheme.swift
//  Today
//
//  Created by Ethan John Lagera on 6/4/26.
//

import SwiftUI

enum PreferredColorScheme: String, CaseIterable, Identifiable {
    case system
    case dark
    case light
    
    /// Color scheme identifier.
    var id: String { rawValue }
    
    /// Human readable title for the color scheme
    var title: String {
        switch self {
        case .system: "System"
        case .dark: "Dark Mode"
        case .light: "Light Mode"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: ColorScheme.dark
        case .light: ColorScheme.light
        }
    }
}
