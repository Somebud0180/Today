//
//  OnboardingView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/1/26.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State var currentStep: Int = 0
    @State var animateGlyph: Bool = false
    @State var calendarGridColumn: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    @State var showNotificaitonsSheet: Bool = false
    @State var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    @AppStorage("remindMeToJournal") private var remindMeToJournal: Bool = DefaultSettings.remindMeToJournal
    @AppStorage("reminderTime") private var reminderTime: Date = DefaultSettings.reminderTime
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black.opacity(colorScheme == .dark ? 0.5 : 0.25), .black.opacity(0.0), .black.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    switch currentStep {
                    case 0:
                        Text("Welcome to")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                        
                        Spacer()
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundProminentButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    case 1:
                        Text("Journal your everyday life")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Pick between audio and video entries")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Image(systemName: animateGlyph ? "video.badge.waveform" : "waveform.mid")
                            .resizable()
                            .scaledToFit()
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeat(.continuous))
                            .padding(32)
                            .task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation(.bouncy){
                                    animateGlyph.toggle()
                                }
                            }
                        
                        
                        Spacer()
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundProminentButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    case 2:
                        Text("The Jog Book")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Keep a track of your daily entries through the journal log book.")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            HStack(alignment: .bottom) {
                                Group {
                                    Text("Jog Book")
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                                    
                                    Spacer ()
                                    
                                    Text(Date.now, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.red)
                                        .padding(.bottom, 2)
                                }
                                .lineLimit(2)
                                .minimumScaleFactor(0.3)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            )
                            
                            
                            LazyVGrid(columns: calendarGridColumn, spacing: 8) {
                                let daysInCurrentMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
                                
                                ForEach(0...daysInCurrentMonth, id: \.self) { block in
                                    let isActive = Float.random(in: 0...2) > 0.25
                                    RoundedRectangle(cornerRadius: 6)
                                        .foregroundStyle(isActive ? .orange : .gray)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .aspectRatio(4/3, contentMode: .fit)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .glassEffect(
                                    .regular,
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                
                        )
                        .aspectRatio(0.95, contentMode: .fit)
                        .padding(.horizontal, 32)
                        
                        Spacer()
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundProminentButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    case 3:
                        Text("Get reminded")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Get a nudge everyday to reflect on your day and make a quick entry")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .glassEffect(
                                    .regular.interactive(),
                                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            
                            HStack(spacing: 8) {
                                Image("Icon")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Today")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Text("It's time for your daily journal, spend some time in the app.")
                                }
                                
                                Spacer()
                            }
                            .padding(8)
                            .padding(.trailing, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 72)
                        .padding(.horizontal, 16)
                        
                        Spacer()
                        
                        Button("Get Reminders") {
                            showNotificaitonsSheet = true
                        }
                        .buttonStyle(RoundProminentButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundGlassButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    default:
                        Text("Let's get started!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button("Continue") {
                            dismiss()
                        }
                        .buttonStyle(RoundProminentButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            }
            .sheet(isPresented: $showNotificaitonsSheet) {
                notificationsSheet
                    .presentationBackgroundInteraction(.disabled)
                    .presentationDetents([.fraction(0.3)])
            }
            .background(
                Image("Background1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: colorScheme)
            )
            .onAppear {
                Task {
                    authorizationStatus = await NotificationsManager.notificatonPermissionStatus()
                }
            }
        }
    }
    
    var notificationsSheet: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .frame(width: 44, height: 6)
            
            Button(authorizationStatus != .notDetermined ? "Manage Notifications" : "Allow Notifications") {
                if authorizationStatus != .notDetermined {
                    Task {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            // Ask the system to open that URL.
                            await UIApplication.shared.open(url)
                        }
                    }
                } else {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                        if success {
                            authorizationStatus = .authorized
                        } else if let error {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
            .buttonStyle(RoundProminentButton())
            .font(.title2)
            .fontWeight(.semibold)
            
            Divider()
            
            Group {
                Toggle(isOn: $remindMeToJournal) {
                    Text("Remind me to journal")
                }
                .onChange(of: remindMeToJournal) {
                    if remindMeToJournal {
                        NotificationsManager.registerReminderNotification(reminderTime)
                    } else {
                        NotificationsManager.unregisterReminderNotifications()
                    }
                }
                
                DatePicker("Reminder time", selection: Binding(get: {
                    reminderTime
                }, set: { newValue in
                    reminderTime = newValue
                    NotificationsManager.registerReminderNotification(reminderTime)
                }), displayedComponents: .hourAndMinute)
                .onChange(of: reminderTime) {
                    if remindMeToJournal {
                        NotificationsManager.registerReminderNotification(reminderTime)
                    }
                }
            }
            .disabled(authorizationStatus != .authorized)
            
            Spacer()
        }
        .padding(16)
    }
}

struct RoundGlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .glassEffect(
                .regular.interactive(),
                in: Capsule()
            )
            .contentShape(Capsule())
    }
}

struct RoundProminentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .glassEffect(
                .regular.interactive().tint(.green.opacity(0.5)),
                in: Capsule()
            )
            .contentShape(Capsule())
    }
}

#Preview {
    OnboardingView()
}
