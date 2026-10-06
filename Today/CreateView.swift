//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI
import SwiftData
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var tabSelection: Int
    @Binding var backgroundBlur: CGFloat
    
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    @AppStorage("transcribeOnSave") private var transcribeOnSave: Bool = DefaultSettings.transcribeOnSave
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
    
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
    @State private var transcript: String?
    @State private var transcriptSuccess: Bool = true
    @State private var transcriptionInProgress: Bool = false
    @State private var invokedTranscription: Bool = false
    
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var noteFieldFocused: Bool
    
    @State private var saveError: String?
    @State private var previewThumbnail: UIImage?
    @State private var isSaving: Bool = false
    @State private var showSavingText: Bool = false
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
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                
                if !(activePage == .save) {
                    switch activePage {
                    case .menu:
                        VStack {
                            Text("What are we feeling today?")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            
                            if isLandscape {
#if canImport(JournalingSuggestions)
                                journalingSuggestionsButton
#endif
                                
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
                    Group {
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
                                            .transition(.opacity)
                                    }
                                }
                            }
                        } else {
                            let width = min(proxy.size.width / 2, 220)
                            let height = min(width * (3 / 2), proxy.size.height - bottomSectionHeight)
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
                    .onAppear {
                        saveBottomInset = proxy.safeAreaInsets.bottom
                        if transcribeOnSave {
                            performTranscription()
                        }
                    }
                    .onChange(of: proxy.safeAreaInsets.bottom) {
                        saveBottomInset = proxy.safeAreaInsets.bottom
                    }
                    .onChange(of: proxy.size) {
                        recalculateSaveBottomPadding()
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: transcriptionInProgress) {
                if transcriptionInProgress {
                    UIAccessibility.post(notification: .announcement, argument: "Transcribing entry")
                } else {
                    if transcriptSuccess && transcript == nil {
                        UIAccessibility.post(notification: .announcement, argument: "Entry failed to transcribe")
                    } else {
                        UIAccessibility.post(notification: .announcement, argument: "Entry transcribed")
                    }
                }
            }
            .task(id: recordedVideoURL) {
                previewThumbnail = nil
                guard let url = recordedVideoURL else { return }
                let data = try? await ThumbnailLoader.videoData(url: url)
                guard !Task.isCancelled else { return }
                previewThumbnail = data.flatMap(UIImage.init(data:))
            }
            .alert("Couldn’t Save Entry", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "Your recording is still available. Please try again.") }
            .sensoryFeedback(.success, trigger: transcriptSuccess) { oldValue,newValue in
                return newValue == true && transcript != nil
            }
            .sensoryFeedback(.error, trigger: transcriptSuccess) { oldValue,newValue in
                return newValue == false && transcript == nil
            }
            .background(
                GeometryReader { proxy in
                    Image(selectedBackground)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                        .clipped()
                        .blur(radius: backgroundBlur, opaque: true)
                        .animation(.smooth(duration: 0.4)) { content in
                            content.blur(radius: backgroundBlur, opaque: true)
                        }
                        .accessibilityHidden(true)
                        .animation(.easeInOut(duration: 0.5), value: colorScheme)
                        .onTapGesture(perform: hideKeyboard)
                }
                    .ignoresSafeArea(.all)
            )
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
            if recordedVideoURL != nil,
               let thumbnail = previewThumbnail
            {
                Image(uiImage: thumbnail)
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
        .scaleEffect(cardScale)
        .shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: shadowOffsetY)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityValue)
        .overlay(alignment: .bottom) {
            Text("Saving…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.bottom) { dimensions in dimensions[.top] - 24 }
                .opacity(showSavingText ? 1 : 0)
                .accessibilityHidden(!showSavingText)
                .allowsHitTesting(false)
        }
        .position(
            x: isLandscape ? (proxy.size.width / 4) : (proxy.size.width / 2),
            y: isLandscape ? (proxy.size.height / 2) : getCardPosY(proxy)
        )
        .opacity(cardOpacity)
        .offset(cardOffset)
        .onAppear(perform: showCardAnimation)
        .safeAreaPadding(.top, proxy.safeAreaInsets.top)
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
                
                Divider()
                
                TextField(
                    "Add a note (optional)",
                    text: $entryNote
                )
                .focused($noteFieldFocused)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .glassEffect(
                        .regular.interactive().tint(colorScheme == .light ? .white.opacity(0.75) : .black.opacity(0.75)),
                        in:
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
            )
            
            Button(action: {
                guard !isSaving else { return }
                hideKeyboard()
                let liftStarted = ContinuousClock.now
                withAnimation(.snappy(duration: 0.4)) {
                    isSaving = true
                    showSavingText = true
                    cardScale = 1.05
                    cardOffset = CGSize(width: 0, height: -12)
                    shadowOpacity = 0.35
                    shadowOffsetY = 12
                }
                UIAccessibility.post(notification: .announcement, argument: "Saving entry")
                Task {
                    do {
                        _ = try await JournalStore.saveRecording(
                            source: activeURL, title: entryTitle, note: entryNote,
                            transcript: transcript ?? "", mediaType: mediaType,
                            waveform: mediaType == .audio ? recordedAudioWaveform : nil,
                            context: modelContext)
                        // Even a fast save should let the initial lift finish before throwing.
                        let remainingLift = Duration.milliseconds(400) - liftStarted.duration(to: .now)
                        if remainingLift > .zero { try? await Task.sleep(for: remainingLift) }
                        await performSaveAnimation(proxy)
                    } catch {
                        withAnimation(.snappy) {
                            isSaving = false
                            showSavingText = false
                            cardScale = 1
                            cardOffset = .zero
                            shadowOpacity = 0.25
                            shadowOffsetY = 5
                        }
                        saveError = error.localizedDescription
                    }
                }
            }) {
                Text("Save Entry")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding(12)
            }
            .buttonStyle(.glassProminent)
            .disabled(transcriptionInProgress || isSaving)
            
            Button(action: {
                hideKeyboard()
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
            return proxy.size.height / 2 - bottomSectionHeight
        }
        return proxy.size.height / 2 - bottomSectionHeight / 2
    }
    
    func hideKeyboard() {
        titleFieldFocused = false
        noteFieldFocused = false
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
    
    func performSaveAnimation(_ proxy: GeometryProxy) async {
        await animateSave(.easeOut(duration: 0.2)) {
            showSavingText = false
        }
        await animateSave(.snappy(duration: 0.25)) {
            cardOffset.width = 20
        }
        await animateSave(.snappy(duration: 0.45)) {
            cardOffset.width = -proxy.size.width
        }
        resetVariables()
        tabSelection = 0
        NotificationsManager.cancelCurrentReminderNotification()
    }

    /// Sequence the fade and throw by animation completion, not a fixed save timer.
    private func animateSave(_ animation: Animation, updates: () -> Void) async {
        await withCheckedContinuation { continuation in
            withAnimation(animation, completionCriteria: .removed, updates) {
                continuation.resume()
            }
        }
    }

    func resetVariables() {
        previewThumbnail = nil
        isSaving = false
        showSavingText = false
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
            let result: (String?, Bool)
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
    CreateView(tabSelection: $tabSelection, backgroundBlur: .constant(24))
}
