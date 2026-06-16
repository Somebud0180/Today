//
//  NoteCardView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/23/26.
//

import SwiftUI

struct NoteCardView: View {
    @Binding var note: String
    @Binding var transcript: String
    @Binding var isLandscape: Bool
    @State private var isExpanded: Bool = false
    @State private var selectedTab: Int = 0
    @FocusState private var isEditing: Bool
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var expandedDragOffset: CGFloat = 0
    
    private let dragThreshold: CGFloat = 32
    
    var body: some View {
        var cardTitle: String {
            switch selectedTab {
            case 0: return "Note"
            default: return "Transcript"
            }
        }
        
        ZStack {
            // Background overlay (only visible when expanded)
            if isExpanded {
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Collapsed state - bottom positioned card
            if !isExpanded {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 5)
                    
                    TabView(selection: $selectedTab) {
                        NotePreviewView(note: note) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = true
                                isEditing = true
                            }
                        }
                        .tag(0)
                        
                        TranscriptPreviewView(transcript: transcript) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = true
                            }
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page)
                    .frame(maxHeight: 96)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, abs(dragOffset * 2))
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
                        .ignoresSafeArea(edges: .bottom)
                }
                .frame(maxWidth: isLandscape ? 512 : nil, maxHeight: .infinity, alignment: .bottom)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = min(max(value.translation.height, -dragThreshold), 0)
                        }
                        .onEnded { value in
                            let verticalDistance = value.translation.height
                            if verticalDistance < -dragThreshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded = true
                                }
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded = true
                    }
                }
                .transition(.move(edge: .bottom))
            }
            
            // Expanded state - centered overlay card
            if isExpanded {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                        
                        Text(cardTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    
                    Divider()
                    
                    TabView(selection: $selectedTab) {
                        NoteExpandedView(note: $note, isEditing: $isEditing)
                            .tag(0)
                        
                        TranscriptExpandedView(transcript: transcript)
                            .tag(1)
                    }
                    .tabViewStyle(.page)
                    .onChange(of: selectedTab) {
                        if selectedTab > 0 {
                            isEditing = false
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 500)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(isLandscape ? 72 : 24)
                .padding(.horizontal, isLandscape ? 72 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: expandedDragOffset)
                .gesture(
                    DragGesture()
                        .updating($expandedDragOffset) { value, state, _ in
                            state = min(dragThreshold, max(0, value.translation.height))
                        }
                        .onEnded { value in
                            let verticalDistance = value.translation.height
                            if verticalDistance > dragThreshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded = false
                                    isEditing = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    isEditing = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct NotePreviewView: View {
    let note: String
    let onTap: () -> Void
    
    var body: some View {
        Text(note.isEmpty ? "Enter a note..." : note)
            .fontWeight(.medium)
            .foregroundStyle(note.isEmpty ? Color.secondary : Color.white)
            .padding(.horizontal)
            .lineLimit(1)
            .onTapGesture(perform: onTap)
    }
}

struct TranscriptPreviewView: View {
    let transcript: String
    let onTap: () -> Void
    
    var body: some View {
        Text(transcript.isEmpty ? "No transcript" : transcript)
            .fontWeight(.medium)
            .foregroundStyle(transcript.isEmpty ? Color.secondary : Color.white)
            .padding(.horizontal)
            .lineLimit(1)
            .onTapGesture(perform: onTap)
    }
}

struct NoteExpandedView: View {
    @Binding var note: String
    let isEditing: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Enter a note...", text: $note, axis: .vertical)
                .focused(isEditing)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding()
            
            Spacer()
        }
    }
}

struct TranscriptExpandedView: View {
    let transcript: String
    
    var body: some View {
        VStack {
            if transcript.isEmpty {
                Spacer()
                
                Group {
                    Image(systemName: "waveform.slash")
                        .resizable()
                        .frame(maxWidth: 72, maxHeight: 72)
                    
                    Text("No Transcript")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding()
                
                Spacer()
            } else {
                Text(transcript)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding()
                
                Spacer()
            }
        }
    }
}
