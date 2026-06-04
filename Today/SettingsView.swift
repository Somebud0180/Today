//
//  SettingsView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/30/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("enableNotifications") private var enableNotifications: Bool = DefaultSettings.enableNotifications
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen: Bool =
    DefaultSettings.autoPlayOnOpen
    @AppStorage("remindMeToJournal") private var remindMeToJournal: Bool
    = DefaultSettings.remindMeToJournal
    @AppStorage("reminderTime") private var reminderTime: Date =
    DefaultSettings.reminderTime
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Image("Icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                        
                        Text("Today")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Manage your settings here. Change how journals behave, and enable notifications for when it's time to journal, export your entries, and more.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("General")) {
                    Toggle(isOn: $autoPlayOnOpen) {
                        Text("Auto-play entry upon open")
                    }
                    
                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        Text("App Appearance")
                    }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $enableNotifications) {
                        Text("Allow notifications")
                    }
                    
                    Toggle(isOn: $remindMeToJournal) {
                        Text("Remind me to journal")
                    }
                    .disabled(!enableNotifications)
                    
                    DatePicker("Reminder time", selection: Binding(get: {
                        reminderTime
                    }, set: { newValue in
                        reminderTime = newValue
                    }), displayedComponents: .hourAndMinute)
                    .disabled(!remindMeToJournal || !enableNotifications)
                }
                
                Section(header: Text("Export")) {
                    NavigationLink {
                        ExportView()
                    } label: {
                        Text("Export journal entries")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
