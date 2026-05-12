//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI

struct CreateView: View {
    private enum Page {
        case menu
        case video
        case audio
    }

    private enum TransitionDirection {
        case forward
        case backward
    }

    @State private var activePage: Page = .menu
    @State private var transitionDirection: TransitionDirection = .forward
    @State private var manager = AudioRecorderManager()

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
                switch activePage {
                case .menu:
                    VStack(spacing: 48) {
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
                    .transition(pageTransition)

                case .video:
                    VStack {
                        Spacer()
                        Text("Video Entry Page")
                        Spacer()
                        Button(action: {
                            transitionDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activePage = .menu
                            }
                        }) {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                                .padding(8)
                        }
                        .buttonStyle(.glass)
                    }
                    .transition(pageTransition)

                case .audio:
                    AudioRecordingView(manager: manager) {
                        transitionDirection = .backward
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activePage = .menu
                        }
                    }
                    .transition(pageTransition)
                }
            }
            .padding(24)
            .navigationTitle("Create Entry")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CreateView()
}
