//
//  SettingsView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/30/26.
//

import SwiftUI

struct SettingsView: View {
    @State var enableNotifications: Bool = false
    @State var autoPlayOnOpen: Bool = false
    @State var remindMe: Bool = true
    // Default reminder to 8 PM
    @State var reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    
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
                }
                
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $enableNotifications) {
                        Text("Allow notifications")
                    }
                    
                    Toggle(isOn: $remindMe) {
                        Text("Remind me to journal")
                    }
                    .disabled(!enableNotifications)
                    
                    DatePicker("Reminder time", selection: Binding(get: {
                        reminderTime
                    }, set: { newValue in
                        reminderTime = newValue
                    }), displayedComponents: .hourAndMinute)
                    .disabled(!remindMe || !enableNotifications)
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

struct ExportView: View {
    @State var includedIndex: Int = 2
    @State var organizationIndex: Int = 0
    @State var groupingIndex: Int = 0
    @State var showExportConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Image(systemName: "square.and.arrow.up.on.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .offset(x: -2)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 64, height: 64)
                            )
                            .frame(width: 64, height: 64)

                        Text("Export")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose how you prefer your entries to be exported. You can select multiple organizations, and your export will be prepared accordingly.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("What's included"), footer: Text("Pick which parts of your entries you want to export. You can choose to include either media and notes")) {
                    Picker("Include", selection: $includedIndex) {
                        Text("Media only").tag(0)
                        Text("Notes only").tag(1)
                        Text("Both media and notes").tag(2)
                    }
                }
                
                if includedIndex == 2 {
                    Section(header: Text("Organization"), footer: Text("Create a folder per entry? Or group all media together and all notes together?")) {
                        Picker("Organize by", selection: $organizationIndex) {
                            Text("One folder per entry").tag(0)
                            Text("Group media and notes").tag(1)
                        }
                    }
                }
                
                Section(header: Text("Grouping"), footer: Text("How do you want your export grouped? By day, week, month, or year?")) {
                    Picker("Group by", selection: $groupingIndex) {
                        Text("Day").tag(0)
                        Text("Month").tag(1)
                        Text("Year").tag(2)
                    }
                }
                
                Section(header: Text("Preview & Export")) {
                    VStack(spacing: 12) {
                        NavigationLink {
                            NavigationStack {
                                Form {
                                    NavigationLink {
                                        NavigationStack {
                                            Form {
                                                Text("Notes.txt")
                                                Text("Media.mov")
                                            }
                                        }
                                    } label: {
                                        Text("May 30, 2026")
                                    }
                                    
                                    NavigationLink {
                                        NavigationStack {
                                            Form {
                                                Text("Notes.txt")
                                                Text("Media.mov")
                                            }
                                        }
                                    } label: {
                                        Text("May 31, 2026")
                                    }
                                }
                            }
                        } label: {
                            Text("May 2026")
                        }
                        
                        Divider()
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                        
                        NavigationLink {
                            
                        } label: {
                            Text("June 2026")
                        }
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    }
                    
                    Button("Export") {
                        showExportConfirmation = true
                    }
                    .padding(.leading, 2)
                }
            }
            .navigationTitle("Export Journal")
            .transition(.slide)
            .animation(.easeInOut(duration: 0.3), value: includedIndex)
            .animation(.easeInOut(duration: 0.3), value: organizationIndex)
            .animation(.easeInOut(duration: 0.3), value: groupingIndex)
            .alert("Are you sure with your export choices?", isPresented: $showExportConfirmation, actions: {
                Button("Yes, export") {
                    // Export
                }
                Button("Cancel", role: .cancel) {}
            })
        }
    }
}

#Preview {
    SettingsView()
}
