//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI
import SwiftData
import FluidAudio
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif


private enum TransitionDirection {
    case forward
    case backward
}

struct CreateView: View {
    enum Page {
        case menu
        case video
        case audio
        case save
    }
    
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Binding var tabSelection: Int
    
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    @AppStorage("transcribeOnSave") private var transcribeOnSave: Bool = DefaultSettings.transcribeOnSave
    
    @State private var animateGradient: Bool = false
    @State private var gradientColors: [Color] = [
        Color.purple.opacity(0.5),
        Color.blue.opacity(0.5)
    ]
    
    @State private var screenHasRecording: Bool = false
    @State private var childShouldReset: Bool = false
    @State private var transitionDirection: TransitionDirection = .forward
    
    @State private var recordedAudioURL: URL? = nil
    @State private var recordedAudioWaveform: CodableAudioWaveform? = nil
    @State private var recordedVideoURL: URL? = nil
    @State private var activePage: Page = .menu
    @State private var suggestionTitle: String = ""
    @State private var entryTitle: String = ""
    @State private var entryNote: String = ""
    @State private var transcript: ASRResult?
    @State private var transcriptSuccess: Bool = true
    @State private var transcriptionInProgress: Bool = false
    @State private var invokedTranscription: Bool = false
    
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var noteFieldFocused: Bool
    
    @State private var tempEntry: JournalEntry?
    @State private var isSaving: Bool = false
    @State private var cardOpacity: Double = 0.0
    @State private var cardScale: CGFloat = 0.0
    @State private var cardOffset: CGSize = .zero
    @State private var shadowOpacity: Double = 0.0
    @State private var shadowOffsetY: CGFloat = 0.0
    @State private var cardPositionY: CGFloat = 0.0
    @State private var bottomSectionHeight: CGFloat = 0.0
    @State private var saveBottomInset: CGFloat = 0.0
    @State private var keyboardHeight: CGFloat = 0.0
    @State private var isKeyboardVisible: Bool = false
    @State private var saveBottomPadding: CGFloat = 0.0
    
    private var pageTransition: AnyTransition {
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 12)
                .hueRotation(.degrees(animateGradient ? 45 : -45))
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    titleFieldFocused = false
                    noteFieldFocused = false
                }
                .task {
                    // From https://www.codespeedy.com/gradient-animation-in-swiftui/
                    withAnimation(
                        .easeInOut(duration: 3)
                        .repeatForever())
                    {
                        animateGradient.toggle()
                    }
                }
                
                if !(activePage == .save) {
                    switch activePage {
                    case .menu:
                        GeometryReader { proxy in
                            let isLandscape = proxy.size.width > proxy.size.height
                            
                            VStack {
                                Text("What are we feeling today?")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                
                                if isLandscape {
                                    journalingSuggestionsButton
                                    
                                    HStackLayout (spacing: 24) {
                                        createButtons
                                    }
                                } else {
                                    VStackLayout(spacing: 24) {
#if canImport(JournalingSuggestions)
                                        journalingSuggestionsButton
#endif
                                        createButtons
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 24)
                        .transition(pageTransition)
                        
                    case .video:
                        VideoRecordingView(
                            activePage: $activePage,
                            recordedURL: $recordedVideoURL,
                            hasTemporaryRecording: $screenHasRecording
                        ) {
                            transitionDirection = .backward
                            withAnimation(.snappy) {
                                activePage = .menu
                            }
                        }
                        .transition(pageTransition)
                        
                    case .audio:
                        AudioRecordingView(
                            activePage: $activePage,
                            recordedURL: $recordedAudioURL,
                            recordedWaveform: $recordedAudioWaveform,
                            hasTemporaryRecording: $screenHasRecording
                        ) {
                            transitionDirection = .backward
                            withAnimation(.snappy) {
                                activePage = .menu
                            }
                        }
                        .padding(.bottom)
                        .padding(24)
                        .transition(pageTransition)
                        
                    case .save:
                        EmptyView()
                    }
                } else {
                    GeometryReader { proxy in
                        let isLandscape = proxy.size.width > proxy.size.height
                        
                        if isLandscape {
                            let width = min(proxy.size.width / 2, 220)
                            let height = min(width * (3 / 2), proxy.size.height - 44)
                            let finalWidth = min(width, height * (2 / 3))
                            
                            HStack {
                                previewCard(finalWidth: finalWidth, height: height, proxy: proxy, isLandscape: isLandscape)
                                
                                Spacer(minLength: 0)
                                
                                VStack(spacing: 12) {
                                    if !isSaving,
                                       let activeURL = recordedVideoURL ?? recordedAudioURL {
                                        let mediaType: MediaType = recordedVideoURL != nil ? .video : .audio
                                        let fileExtension = activeURL.pathExtension.isEmpty
                                        ? (mediaType == .video ? "mov" : "m4a")
                                        : activeURL.pathExtension

                                        transcriptionProgress
                                        
                                        saveFields(activeURL: activeURL, fileExtension: fileExtension, mediaType: mediaType, proxy: proxy)
                                            .padding(24)
                                            .transition(.opacity)
                                    }
                                }
                            }
                        } else {
                            let width = min(proxy.size.width / 2, 220)
                            let height = min(width * (3 / 2), proxy.size.height - bottomSectionHeight - keyboardHeight)
                            let finalWidth = min(width, height * (2 / 3))
                            
                            ZStack {
                                if recordedVideoURL != nil || recordedAudioWaveform != nil {
                                    previewCard(finalWidth: finalWidth, height: height, proxy: proxy, isLandscape: isLandscape)
                                }
                                
                                VStack(spacing: 12) {
                                    if !isSaving {
                                        transcriptionProgress
                                    }
                                    
                                    Spacer()
                                    
                                    if !isSaving,
                                       let activeURL = recordedVideoURL ?? recordedAudioURL {
                                        let mediaType: MediaType = recordedVideoURL != nil ? .video : .audio
                                        let fileExtension = activeURL.pathExtension.isEmpty
                                        ? (mediaType == .video ? "mov" : "m4a")
                                        : activeURL.pathExtension
                                        
                                        saveFields(activeURL: activeURL, fileExtension: fileExtension, mediaType: mediaType, proxy: proxy)
                                            .background {
                                                GeometryReader { proxy in
                                                    Color.clear
                                                        .onAppear {
                                                            bottomSectionHeight = proxy.size.height
                                                        }
                                                }
                                            }
                                            .padding(24)
                                            .padding(.bottom, saveBottomPadding)
                                            .transition(.opacity)
                                            .onAppear {
                                                saveBottomInset = proxy.safeAreaInsets.bottom
                                            }
                                    }
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                                handleKeyboardWillShow(notification)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                                handleKeyboardWillHide()
                            }
                        }
                    }
                    .ignoresSafeArea(.keyboard)
                    .transition(pageTransition)
                    .onAppear {
                        if transcribeOnSave {
                            performTranscription()
                        }
                    }
                }
            }
        }
    }
    
#if canImport(JournalingSuggestions)
    var journalingSuggestionsButton: some View {
        HStack {
            JournalingSuggestionsPicker {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue)
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                    Label(suggestionTitle.isEmpty ? "Show suggestions" : suggestionTitle, systemImage: suggestionTitle.isEmpty ? "person.fill.questionmark" : "pencil.and.scribble")
                        .font(.title)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .labelStyle(CenterAlign())
                        .padding(4)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.symbolEffect(.replace))
                }
            } onCompletion: { suggestion in
                entryTitle = suggestion.title
                suggestionTitle = suggestion.title
            }
            .buttonStyle(.plain)
            
            if !suggestionTitle.isEmpty {
                Button(action: {
                    suggestionTitle = ""
                    entryTitle = ""
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue)
                            .glassEffect(
                                .regular.interactive(),
                                in: RoundedRectangle(cornerRadius: 24)
                            )
                        Image(systemName: "xmark")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .padding(8)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 72)
            }
        }
        .frame(maxHeight: 72)
        .animation(.snappy(duration: 0.5), value: suggestionTitle)
    }
#endif
    
    var createButtons: some View {
        Group {
            Button(action: {
                transitionDirection = .forward
                withAnimation(.snappy) {
                    activePage = .video
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.blue)
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                    
                    VStack(spacing: 24) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 64))
                        
                        Text("Create Video Entry")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                    }
                }
            }
            
            Button(action: {
                transitionDirection = .forward
                withAnimation(.snappy) {
                    activePage = .audio
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray)
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                    
                    VStack(spacing: 24) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.black)
                        
                        Text("Create Audio Entry")
                            .foregroundStyle(.black)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    var transcriptionProgress: some View {
        Group {
            if enableTranscription {
                let showPrompt = !transcribeOnSave && !invokedTranscription
                let transcriptExist = transcript != nil
                
                let showProgress = !showPrompt && (transcriptSuccess && !transcriptExist)
                let transcriptStatusText = transcriptSuccess ? transcriptExist ? "Entry transcribed" : "Transcribing entry" : "Transcribing failed"
                let transcriptStatusSymbol = transcriptSuccess ? "checkmark" : "xmark"
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        performTranscription()
                    }, label: {
                        HStack {
                            Text(showPrompt ? "Transcribe entry" : transcriptStatusText)
                                .fontWeight(.medium)
                            
                            Group {
                                if showProgress {
                                    Image(systemName: "progress.indicator")
                                        .symbolEffect(.variableColor.iterative.nonReversing, options: .repeat(.continuous))
                                } else {
                                    Image(systemName: showPrompt ? "questionmark" : transcriptStatusSymbol)
                                }
                            }
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                        }
                        .padding(4)
                        .padding(.horizontal, 8)
                        .glassEffect(
                            .regular,
                            in: Capsule()
                        )
                    })
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }
    
    /// Returns a human-friendly media type string for accessibility.
    private var accessibilityMediaType: String {
        if recordedVideoURL != nil {
            return "Video"
        } else {
            return "Audio"
        }
    }
    
    /// Title if present; otherwise a formatted date string.
    private var accessibilityPrimaryText: String {
        if !entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entryTitle
        } else {
            return Date().formatted(date: .long, time: .omitted)
        }
    }
    
    /// Full label announced by VoiceOver, e.g. "Video, Family Picnic" or "Audio, June 23, 2026".
    var accessibilityTitle: String {
        "\(accessibilityMediaType) entry, \(accessibilityPrimaryText)"
    }
    
    /// Secondary value for additional context. If a title exists, provide the date; otherwise empty.
    var accessibilityValue: String {
        if !entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Date().formatted(date: .long, time: .omitted)
        } else {
            return ""
        }
    }
    
    func previewCard(finalWidth: CGFloat, height: CGFloat, proxy: GeometryProxy, isLandscape: Bool) -> some View {
        ZStack {
            if let recordedVideoURL = recordedVideoURL,
               let thumbnail = videoThumbnail(for: recordedVideoURL)
            {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: finalWidth, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else if
                let linearSample = recordedAudioWaveform?.samplesLinear,
                let waveformLevels = JournalEntry.audioWaveformThumbnailLevels(linearSample, maxBars: max(1, Int(finalWidth / 7)))
            {
                WaveformView(levels: waveformLevels, isThumbnailView: true)
                    .frame(width: finalWidth, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(alignment: .leading) {
                Text(
                    entryTitle.isEmpty ? Date().formatted(date: .numeric, time: .omitted) : entryTitle
                )
                .font(.title2)
                .lineLimit(2)
                .fontWeight(.heavy)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if !entryTitle.isEmpty {
                    Text(Date().formatted(date: .numeric, time: .omitted))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.75))
                }
                
                Spacer()
            }
            .padding(12)
        }
        .ignoresSafeArea(.keyboard)
        .frame(width: finalWidth, height: height, alignment: .center)
        .position(
            x: isLandscape ? (proxy.size.width / 4) : (proxy.size.width / 2),
            y: isLandscape ? (proxy.size.height / 2) : getCardPosY(proxy)
        )
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .offset(cardOffset)
        .shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: shadowOffsetY)
        .onAppear(perform: showCardAnimation)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityValue)
    }
    
    func saveFields(activeURL: URL, fileExtension: String, mediaType: MediaType, proxy: GeometryProxy) -> some View {
        VStack {
            VStack {
                TextField(
                    Date().formatted(date: .numeric, time: .omitted),
                    text: $entryTitle,
                    axis: .vertical
                )
                .focused($titleFieldFocused)
                .font(.largeTitle)
                .accessibilityLabel("Title")
                
                TextField(
                    "Add a note (optional)",
                    text: $entryNote
                )
                .focused($noteFieldFocused)
            }
            
            Divider()
            
            Button(action: {
                tempEntry = JournalEntry(
                    title: entryTitle,
                    note: entryNote,
                    transcript: transcript?.text ?? "",
                    mediaData: try! Data(contentsOf: activeURL),
                    fileExtension: fileExtension,
                    mediaType: mediaType,
                    waveform: mediaType == .audio ? recordedAudioWaveform : nil
                )
                
                withAnimation(.snappy) {
                    isSaving = true
                }
                
                performSaveAnimation(proxy)
            }) {
                Text("Save Entry")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding(12)
            }
            .buttonStyle(.glassProminent)
            .disabled(transcriptionInProgress)
            
            Button(action: {
                transitionDirection = .backward
                withAnimation(.snappy) {
                    if recordedAudioURL != nil {
                        activePage = .audio
                    } else if recordedVideoURL != nil {
                        activePage = .video
                    } else {
                        recordedAudioURL = nil
                        recordedAudioWaveform = nil
                        recordedVideoURL = nil
                        activePage = .menu
                    }
                }
            }) {
                Text("Back")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding(12)
            }
            .buttonStyle(.glass)
            
        }

    }
    
    func getCardPosY(_ proxy: GeometryProxy) -> CGFloat {
        if isSaving {
            return proxy.size.height / 2
        } else if isKeyboardVisible {
            return proxy.size.height / 2 - keyboardHeight + saveBottomInset
        }
        return proxy.size.height / 2 - bottomSectionHeight / 2
    }
    
    func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        withAnimation(.snappy) {
            isKeyboardVisible = true
            keyboardHeight = keyboardFrame.height
        }
        
        recalculateSaveBottomPadding()
    }
    
    func handleKeyboardWillHide() {
        withAnimation(.snappy) {
            isKeyboardVisible = false
            keyboardHeight = 0
            saveBottomPadding = 0
        }
    }
    
    func recalculateSaveBottomPadding() {
        guard isKeyboardVisible else {
            withAnimation(.snappy) {
                saveBottomPadding = 0
            }
            return
        }
        
        withAnimation(.snappy) {
            saveBottomPadding = max(0, keyboardHeight - saveBottomInset)
        }
    }
    
    func videoThumbnail(for URL: URL) -> Image? {
        let data = JournalEntry.generateThumbnailData(from: URL)
        if let data, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    
    func showCardAnimation() {
        cardOpacity = 0.0
        cardScale = 0.8
        shadowOpacity = 0.0
        shadowOffsetY = 0.0
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cardOpacity = 1.0
            cardScale = 1.0
            shadowOpacity = 0.25
            shadowOffsetY = 5.0
        }
    }
    
    func performSaveAnimation(_ proxy: GeometryProxy) {
        cardOffset = .zero
        
        withAnimation(.snappy) {
            cardScale = 1.05
            shadowOpacity = 0.35
        }
        
        withAnimation(.snappy.delay(1.0)) {
            cardOffset = CGSize(width: 20, height: 0)
        }
        
        withAnimation(.snappy.delay(1.5)) {
            cardOffset = CGSize(width: -proxy.size.width, height: 0)
        }
        
        Task { @MainActor in
            if let entry = tempEntry {
                modelContext.insert(entry)
                try? modelContext.save()
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if tempEntry != nil {
                resetVariables()
                tabSelection = 0
                NotificationsManager.cancelCurrentReminderNotification()
            }
        }
    }
    
    func resetVariables() {
        tempEntry = nil
        isSaving = false
        cardOpacity = 0.0
        cardScale = 0.8
        cardOffset = .zero
        shadowOpacity = 0.0
        shadowOffsetY = 0.0
        bottomSectionHeight = 0.0
        keyboardHeight = 0.0
        isKeyboardVisible = false
        saveBottomPadding = 0.0
        
        screenHasRecording = false
        childShouldReset = false
        transitionDirection = .forward
        recordedAudioURL = nil
        recordedAudioWaveform = nil
        recordedVideoURL = nil
        activePage = .menu
        entryTitle = ""
        entryNote = ""
        transcript = nil
        transcriptSuccess = true
        transcriptionInProgress = false
        invokedTranscription = false
    }
    
    func performTranscription() {
        guard transcript == nil, enableTranscription, !transcriptionInProgress else { return }
        
        guard recordedAudioURL != nil || recordedVideoURL != nil else {
            withAnimation(.snappy) {
                transcriptionInProgress = false
                transcriptSuccess = false
            }
            return
        }
        
        withAnimation(.snappy) {
            invokedTranscription = true
            transcriptionInProgress = true
            transcriptSuccess = true // optimistic until proven otherwise
        }
            
        Task {
            let result: (ASRResult?, Bool)
            if let recordedAudioURL {
                result = await transcriptionManager.transcribeAudio(recordedAudioURL)
            } else if let recordedVideoURL {
                result = await transcriptionManager.transcribeVideo(recordedVideoURL)
            } else {
                result = (nil, false)
            }
            
            let (newTranscript, newSuccess) = result
            await MainActor.run {
                withAnimation(.snappy) {
                    transcript = newTranscript
                    transcriptSuccess = newSuccess
                    transcriptionInProgress = false
                }
            }
        }
    }
}


// Source - https://stackoverflow.com/a/69687031
// Posted by Asperi
// Retrieved 2026-06-01, License - CC BY-SA 4.0
/// A custom label style that arranges the icon and title horizontally centered.
struct CenterAlign: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            configuration.icon
            configuration.title
        }
    }
}

#Preview {
    @Previewable @State var tabSelection: Int = 1
    CreateView(tabSelection: $tabSelection)
}
