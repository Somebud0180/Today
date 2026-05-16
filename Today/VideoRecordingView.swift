//
//  VideoRecordingView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/15/26.
//

import SwiftUI
import UIKit

struct VideoRecordingView: View {
    @StateObject var manager: VideoRecorderManager
    @StateObject var videoViewModel: VideoViewModel
    @Binding var activePage: CreateView.Page
    @Binding var recordedURL: URL?
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
    
    init(activePage: Binding<CreateView.Page>, recordedURL: Binding<URL?>, onBack: @escaping () -> Void ) {
        _manager = StateObject(wrappedValue: VideoRecorderManager())
        _videoViewModel = StateObject(wrappedValue: VideoViewModel(fileURL: nil))
        self._activePage = activePage
        self._recordedURL = recordedURL
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !manager.showConfirmation {
                    CameraPreviewView(manager: manager)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(focusGesture(in: proxy.size))
                        .simultaneousGesture(exposureGesture(in: proxy.size))
                        .simultaneousGesture(zoomGesture)
                } else {
                    VideoPlayerView(player: videoViewModel.player)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            videoViewModel.loadVideo(fileURL: localRecordedURL)
                            videoViewModel.play()
                        }
                        .onTapGesture {
                            videoViewModel.togglePlayback()
                        }
                }
                
                if let focusPoint, focusVisible {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .position(focusPoint)
                        .transition(.opacity)
                }
                
                VStack {
                    Spacer()
                    zoomStopsRow
                    bottomControls
                }
                .padding(16)
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
                localRecordedURL = nil
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Discarding will permanently delete this recording.")
        }
        .onChange(of: manager.showConfirmation) { _, newValue in
            if newValue, let url = manager.lastRecordingURL {
                localRecordedURL = url
            } else {
                localRecordedURL = nil
            }
        }
        .onChange(of: manager.lastRecordingURL) { _, newValue in
            if let newValue, manager.showConfirmation {
                localRecordedURL = newValue
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
        .onDisappear {
            manager.stopRecording()
            manager.stopSession()
        }
    }
    
//    private var topControls: some View {
//        HStack(spacing: 12) {
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 8) {
//                    ForEach(manager.availableLensOptions) { lens in
//                        Button(action: { manager.selectLens(lens) }) {
//                            Text(lens.displayName)
//                                .font(.caption)
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 6)
//                        }
//                        .buttonStyle(.glass)
//                        .tint(manager.selectedLens == lens ? .blue : .gray)
//                    }
//                }
//            }
//        }
//    }
    
    private var zoomStopsRow: some View {
        HStack(spacing: 12) {
            Button(action: { manager.switchCamera() }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .padding(2)
            }
            .buttonStyle(.glass)
            
            ForEach(manager.availableZoomStops, id: \ .self) { stop in
                Button(action: { manager.setZoomFactor(stop) }) {
                    Text(zoomLabel(stop))
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            if !manager.showConfirmation {
                HStack(spacing: 16) {
                    Button(action: toggleRecording) {
                        Text(manager.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                }
                
                Button(action: {
                    manager.stopRecording()
                    onBack()
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glass)
                .disabled(manager.isRecording)
                .opacity(manager.isRecording ? 0.5 : 1.0)
            } else {
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
            onBack: { }
        )
    }
}
