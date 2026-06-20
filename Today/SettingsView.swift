//
//  SettingsView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/30/26.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen: Bool = DefaultSettings.autoPlayOnOpen
    @AppStorage("remindMeToJournal") private var remindMeToJournal: Bool = DefaultSettings.remindMeToJournal
    @AppStorage("reminderTime") private var reminderTime: Date = DefaultSettings.reminderTime
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    @AppStorage("transcribeOnSave") private var transcribeOnSave: Bool = DefaultSettings.transcribeOnSave
    
    @State var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State var showOnboarding: Bool = false
    
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
                    
                    Button("Restart introduction", action: {
                        showOnboarding = true
                    })
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
                
                Section(header: Text("Audio Transcription"), footer: Text("All features run on-device. Your entries stay safe and never leave your device.")) {
                    Toggle("Enable audio transcription", isOn: $enableTranscription)
                    
                    Toggle(isOn: $transcribeOnSave) {
                        VStack(alignment: .leading) {
                            Text("Transcribe entry on save")
                            Text("Transcribe audio upon creating an entry, you may do this manually within the entry.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                        .disabled(!enableTranscription)
                    
                    HStack {
                        Text("Transcription Status: ")
                        
                        Spacer()
                        
                        Text(transcriptionManager.modelLoadState.description)
                        
                        switch transcriptionManager.modelLoadState {
                        case .loading, .downloading:
                            Image(systemName: "progress.indicator")
                                .symbolEffect(.variableColor.iterative.nonReversing, options: .repeat(.continuous))
                        default:
                            EmptyView()
                        }
                    }
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
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
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
