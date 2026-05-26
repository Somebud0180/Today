//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI
import SwiftData

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
    
    @Environment(\.modelContext) private var modelContext
    @Binding var tabSelection: Int
    
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
    @State private var entryTitle: String = ""
    @State private var entryNote: String = ""
    
    @State private var tempEntry: JournalEntry?
    @State private var isSaving: Bool = false
    @State private var cardOpacity: Double = 0.0
    @State private var cardScale: CGFloat = 0.0
    @State private var cardOffset: CGSize = .zero
    @State private var shadowOpacity: Double = 0.0
    @State private var shadowOffsetY: CGFloat = 0.0
    @State private var inputSectionHeight: CGFloat = 0.0
    
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
                            let menuLayout: AnyLayout = isLandscape
                            ? AnyLayout(HStackLayout(spacing: 24))
                            : AnyLayout(VStackLayout(spacing: 32))
                            
                            VStack {
                                Text("What are we feeling today?")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                
                                menuLayout {
                                    Button(action: {
                                        transitionDirection = .forward
                                        withAnimation(.easeInOut(duration: 0.3)) {
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
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        transitionDirection = .forward
                                        withAnimation(.easeInOut(duration: 0.3)) {
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
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.bottom)
                        .padding(.horizontal, 24)
                        .transition(pageTransition)
                        
                    case .video:
                        VideoRecordingView(
                            activePage: $activePage,
                            recordedURL: $recordedVideoURL,
                            hasTemporaryRecording: $screenHasRecording
                        ) {
                            transitionDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
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
                            withAnimation(.easeInOut(duration: 0.3)) {
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
                        let width = min(proxy.size.width / 2, 220)
                        let height = width * (3 / 2)
                        
                        ZStack {
                            if recordedVideoURL != nil || recordedAudioWaveform != nil {
                                ZStack {
                                    if let recordedVideoURL = recordedVideoURL,
                                       let thumbnail = videoThumbnail(for: recordedVideoURL)
                                    {
                                        thumbnail
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: width, height: height)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                                    } else if
                                        let recordedAudioWaveform = recordedAudioWaveform,
                                        let linearSample = recordedAudioWaveform.samplesLinear as? [Double],
                                        let waveformLevels = JournalEntry.audioWaveformThumbnailLevels(linearSample, maxBars: max(1, Int(width / 7)))
                                    {
                                        WaveformView(levels: waveformLevels, isThumbnailView: true)
                                            .frame(width: width, height: height)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.gray.opacity(0.25))
                                        .glassEffect(
                                            .clear.tint(.gray.opacity(0.25)),
                                            in: RoundedRectangle(cornerRadius: 16)
                                        )
                                    
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
                                .frame(width: width, height: height, alignment: .center)
                                .position(
                                    x: proxy.size.width / 2,
                                    y: isSaving ? proxy.size.height / 2 : (proxy.size.height / 2 - inputSectionHeight / 2 - 24)
                                )
                                .opacity(cardOpacity)
                                .scaleEffect(cardScale)
                                .offset(cardOffset)
                                .shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: shadowOffsetY)
                                .onAppear(perform: showCardAnimation)
                            }
                            
                            VStack(spacing: 12) {
                                Spacer()
                                
                                if !isSaving,
                                   let activeURL = recordedVideoURL ?? recordedAudioURL {
                                    let mediaType: MediaType = recordedVideoURL != nil ? .video : .audio
                                    let fileExtension = activeURL.pathExtension.isEmpty
                                    ? (mediaType == .video ? "mov" : "m4a")
                                    : activeURL.pathExtension
                                    
                                    VStack {
                                        TextField(
                                            Date().formatted(date: .numeric, time: .omitted),
                                            text: $entryTitle,
                                            axis: .vertical
                                        )
                                        .font(.largeTitle)
                                        
                                        TextField(
                                            "Add a note (optional)",
                                            text: $entryNote
                                        )
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            tempEntry = JournalEntry(
                                                title: entryTitle,
                                                note: entryNote,
                                                mediaData: try! Data(contentsOf: activeURL),
                                                fileExtension: fileExtension,
                                                mediaType: mediaType,
                                                waveform: mediaType == .audio ? recordedAudioWaveform : nil
                                            )
                                            
                                            withAnimation(.easeInOut(duration: 0.3)) {
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
                                        
                                        Button(action: {
                                            transitionDirection = .backward
                                            withAnimation(.easeInOut(duration: 0.3)) {
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
                                    .padding(.bottom)
                                    .padding(24)
                                    .transition(pageTransition)
                                    .background {
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    inputSectionHeight = proxy.size.height
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
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
        
        withAnimation(.easeInOut(duration: 0.5)) {
            cardScale = 1.05
            shadowOpacity = 0.35
        }
        
        withAnimation(.easeInOut(duration: 0.5).delay(1.0)) {
            cardOffset = CGSize(width: 20, height: 0)
        }
        
        withAnimation(.easeInOut(duration: 0.5).delay(1.5)) {
            cardOffset = CGSize(width: -proxy.size.width, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let entry = tempEntry {
                modelContext.insert(entry)
                try? modelContext.save()
                resetVariables()
                tabSelection = 0
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
        
        screenHasRecording = false
        childShouldReset = false
        transitionDirection = .forward
        recordedAudioURL = nil
        recordedAudioWaveform = nil
        recordedVideoURL = nil
        activePage = .menu
        entryTitle = ""
        entryNote = ""
    }
}

#Preview {
    @Previewable @State var tabSelection: Int = 1
    CreateView(tabSelection: $tabSelection)
}
