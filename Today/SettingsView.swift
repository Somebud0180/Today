//
//  SettingsView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/30/26.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen: Bool = DefaultSettings.autoPlayOnOpen
    @AppStorage("remindMeToJournal") private var remindMeToJournal: Bool = DefaultSettings.remindMeToJournal
    @AppStorage("reminderTime") private var reminderTime: Date = DefaultSettings.reminderTime
    @AppStorage("enableAI") private var enableAI: Bool = DefaultSettings.enableAI
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    @AppStorage("transcribeOnSave") private var transcribeOnSave: Bool = DefaultSettings.transcribeOnSave
    
    @State var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
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
                    notificationsButton
                    
                    Toggle(isOn: $remindMeToJournal) {
                        Text("Remind me to journal")
                    }
                    .disabled(authorizationStatus != .authorized)
                    .onChange(of: remindMeToJournal) {
                        if remindMeToJournal {
                            NotificationsManager.registerReminderNotification(reminderTime)
                        } else {
                            NotificationsManager.unregisterReminderNotifications()
                        }
                    }
                    
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .disabled(!remindMeToJournal || authorizationStatus != .authorized)
                    .onChange(of: reminderTime) {
                        if remindMeToJournal {
                            NotificationsManager.registerReminderNotification(reminderTime)
                        }
                    }
                }
                
                Section(header: Text("Apple Intelligence"), footer: Text("All features run on-device. Your data stays safe and never leaves your device.")) {
                    Toggle("Enable Apple Intelligence", isOn: $enableAI)
                    
                    Group {
                        Toggle("Enable audio transcription", isOn: $enableTranscription)
                        
                        Toggle("Automatically transcribe entry on save", isOn: $transcribeOnSave)
                            .disabled(!enableTranscription)
                    }
                    .disabled(!enableAI)
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
            .onAppear {
                Task {
                    authorizationStatus = await NotificationsManager.notificatonPermissionStatus()
                }
            }
        }
    }
    
    private var notificationsButton: some View {
        if authorizationStatus == .notDetermined {
            return Button("Enable Notifications") {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
                    if success {
                        authorizationStatus = .authorized
                        if remindMeToJournal {
                            NotificationsManager.registerReminderNotification(reminderTime)
                        }
                    } else if let error {
                        print(error.localizedDescription)
                    }
                }
            }
        } else {
            return Button("Manage Notifications") {
                Task {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        // Ask the system to open that URL.
                        await UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
