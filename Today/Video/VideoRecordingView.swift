//
//  VideoRecordingView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/15/26.
//

import SwiftUI
import UIKit
import AVFoundation

struct VideoRecordingView: View {
    @StateObject var manager: VideoRecorderManager
    @StateObject var videoViewModel: VideoViewModel
    @Binding var activePage: CreateView.Page
    @Binding var recordedURL: URL?
    @Binding var hasTemporaryRecording: Bool
    var onBack: () -> Void
    
    @State private var localRecordedURL: URL?
    @State private var focusPoint: CGPoint?
    @State private var focusVisible = false
    @State private var isAdjustingExposure = false
    @State private var exposureStartY: CGFloat = 0
    @State private var isZooming = false
    @State private var showDiscardConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLandscape: Bool = false
    
    init(activePage: Binding<CreateView.Page>, recordedURL: Binding<URL?>, hasTemporaryRecording: Binding<Bool>, onBack: @escaping () -> Void ) {
        _manager = StateObject(wrappedValue: VideoRecorderManager())
        _videoViewModel = StateObject(wrappedValue: VideoViewModel(fileURL: nil))
        self._activePage = activePage
        self._recordedURL = recordedURL
        self._hasTemporaryRecording = hasTemporaryRecording
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            
            ZStack {
                if !manager.showConfirmation {
                    CameraPreviewView(manager: manager)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(focusGesture(in: proxy.size))
                        .simultaneousGesture(exposureGesture(in: proxy.size))
                        .simultaneousGesture(zoomGesture)
                    
                    ZStack(alignment: .top) {
                        if manager.isRecording {
                            Text(TimeFormatter.formatDuration(manager.recordingDuration))
                                .foregroundStyle(.white)
                                .font(.title3)
                                .padding(4)
                                .glassEffect(
                                    .regular.tint(.red),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                                .accessibilityLabel("Elapsed recording time")
                                .accessibilityValue(TimeFormatter.accessibleTimeFormat(manager.recordingDuration))
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                
                if let focusPoint, focusVisible {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .position(focusPoint)
                        .transition(.opacity)
                }
                
                if isLandscape {
                    HStack(spacing: 12) {
                        if manager.showConfirmation {
                            AspectFitPlayerView(player: videoViewModel.player)
                                .frame(maxHeight: .infinity)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    videoViewModel.togglePlayback()
                                }
                        } else {
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            zoomStopsRow(isLandscape: true)
                            bottomControls(isLandscape: true)
                        }
                        .frame(maxWidth: proxy.size.width * 0.5, alignment: .trailing)
                    }
                    .padding(.bottom, 24)
                    .padding(.trailing, 24)
                    .ignoresSafeArea(.all, edges: .trailing)
                } else {
                    VStack(spacing: 12) {
                        if manager.showConfirmation {
                            AspectFitPlayerView(player: videoViewModel.player)
                                .frame(maxHeight: .infinity)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    videoViewModel.togglePlayback()
                                }
                        } else {
                            Spacer()
                        }
                        
                        zoomStopsRow(isLandscape: false)
                        bottomControls(isLandscape: false)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Video Entry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
        .alert("Discard Recording?", isPresented: $showDiscardConfirmation) {
            Button("Discard", role: .destructive) {
                manager.discardRecording()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Discarding will permanently delete this recording.")
        }
        .onChange(of: manager.showConfirmation) { _, newValue in
            if newValue, let url = manager.lastRecordingURL {
                localRecordedURL = url
                videoViewModel.loadVideo(fileURL: localRecordedURL)
                videoViewModel.play()
            } else {
                videoViewModel.unloadVideo()
                localRecordedURL = nil
                hasTemporaryRecording = false
            }
        }
        .onChange(of: manager.lastRecordingURL) { _, newValue in
            if let newValue, manager.showConfirmation {
                localRecordedURL = newValue
                hasTemporaryRecording = true
            }
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            if let newValue {
                errorMessage = newValue
                showError = true
            }
        }
        .task {
            await manager.startSession()
        }
        .onAppear {
            if let recordedURL = recordedURL, localRecordedURL == nil {
                let fileName = recordedURL.lastPathComponent
                
                let liveDirectory = FileManager.default.temporaryDirectory
                let liveRestoredURL = liveDirectory.appending(path: fileName, directoryHint: .notDirectory)
                
                if FileManager.default.fileExists(atPath: liveRestoredURL.path) {
                    self.localRecordedURL = liveRestoredURL
                    manager.restoreVideo(from: liveRestoredURL)
                } else {
                    print("DEBUG: File could not be found at live path: \(liveRestoredURL.path)")
                }
            }
        }
        .sensoryFeedback(trigger: manager.isRecording) { oldValue, newValue in
            if !oldValue && newValue {
                return .start
            } else if oldValue && !newValue {
                return .stop
            }
            return nil
        }
        .onDisappear {
            manager.stopRecording()
            manager.stopSession()
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        isLandscape = proxy.size.width > proxy.size.height
                    }
                    .onChange(of: proxy.size) {
                        isLandscape = proxy.size.width > proxy.size.height
                    }
            }
        )
    }
    
    private func zoomStopsRow(isLandscape: Bool) -> some View {
        let adaptiveLayout = isLandscape ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        
        return adaptiveLayout {
            if localRecordedURL == nil {
                let sortedZoomStops = isLandscape ? manager.availableZoomStops.sorted(by: >) : manager.availableZoomStops.sorted(by: <)
                
                Spacer()
                
                ForEach(sortedZoomStops, id: \ .self) { stop in
                    Button(action: { manager.setZoomFactor(stop) }) {
                        Text(zoomLabel(stop))
                            .font(.headline)
                            .fontWeight(.regular)
                            .padding(12)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.interactive(),
                        in: Circle()
                    )
                }
                
                if manager.showCenterStage && manager.activePosition == .front {
                    Button(action: { manager.setCenterStage(true) }) {
                        Label("Center Stage", systemImage: "person.fill.viewfinder")
                            .labelStyle(.iconOnly)
                            .font(.headline)
                            .fontWeight(.regular)
                            .padding(12)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.interactive(),
                        in: Circle()
                    )
                }
                
                Spacer()
            }
        }
    }
    
    private func bottomControls(isLandscape: Bool) -> some View {
        Group {
            if !manager.showConfirmation {
                if isLandscape {
                    VStack(spacing: 0) {
                        flipButton
                        Spacer()
                        recordButton
                        Spacer()
                        backButton
                    }
                } else {
                    HStack(spacing: 0) {
                        backButton
                        Spacer()
                        recordButton
                        Spacer()
                        flipButton
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Button(action: {
                        recordedURL = localRecordedURL
                        activePage = .save
                    }) {
                        Text("Confirm Recording")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(12)
                    }
                    .buttonStyle(.glassProminent)
                    
                    Button(action: { showDiscardConfirmation = true }) {
                        Text("Record again")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(12)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
    
    private var backButton: some View {
        Button(action: {
            manager.stopRecording()
            onBack()
        }) {
            Label("Back", systemImage: "chevron.left")
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 44, height: 44)
                .glassEffect(
                    .regular.interactive(),
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(manager.isRecording)
        .opacity(manager.isRecording ? 0.5 : 1.0)
    }
    
    private var recordButton: some View {
        Button(action: toggleRecording) {
            Image(systemName: manager.isRecording ? "square.fill" : "circle.fill")
                .resizable()
                .scaledToFit()
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                .foregroundStyle(Color.red)
                .padding(manager.isRecording ? 16 : 8)
                .glassEffect(
                    .regular.interactive(),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .frame(width: 72, height: 72)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(manager.isRecording ? "Stop recording video" : "Record video")
    }
    
    private var flipButton: some View {
        Button(action: { manager.switchCamera() }) {
            Label("Flip Camera", systemImage: "arrow.triangle.2.circlepath.camera")
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 44, height: 44)
                .glassEffect(
                    .regular.interactive(),
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(manager.isRecording)
        .opacity(manager.isRecording ? 0.5 : 1.0)
    }
    
    private func toggleRecording() {
        if manager.isRecording {
            manager.stopRecording()
        } else {
            manager.startRecording()
        }
    }
    
    private func focusGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let isTap = abs(value.translation.width) < 6 && abs(value.translation.height) < 6
                guard isTap else { return }
                let point = value.location
                focusPoint = point
                focusVisible = true
                manager.focusAndExpose(at: point)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        focusVisible = false
                    }
                }
            }
    }
    
    private func exposureGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !isAdjustingExposure {
                    isAdjustingExposure = true
                    exposureStartY = value.startLocation.y
                    manager.beginExposureAdjustment()
                }
                let delta = (exposureStartY - value.location.y) / max(size.height, 1)
                manager.adjustExposure(by: delta)
            }
            .onEnded { _ in
                isAdjustingExposure = false
            }
    }
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isZooming {
                    isZooming = true
                    manager.beginZoom()
                }
                manager.updateZoom(by: value)
            }
            .onEnded { _ in
                isZooming = false
            }
    }
    
    private func zoomLabel(_ value: CGFloat) -> String {
        if value < 1 {
            return String(format: "%.1fx", value)
        }
        return String(format: "%.0fx", value)
    }
}

#Preview {
    NavigationStack {
        VideoRecordingView(
            activePage: .constant(.video),
            recordedURL: .constant(nil),
            hasTemporaryRecording: .constant(false),
            onBack: { }
        )
    }
}
