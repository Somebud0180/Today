//
//  NoteCardView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/23/26.
//

import SwiftUI

struct NoteCardView: View {
    @Binding var note: String
    @Binding var isLandscape: Bool
    @State private var isExpanded: Bool = false
    @FocusState private var isEditing: Bool
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var expandedDragOffset: CGFloat = 0
    
    private let dragThreshold: CGFloat = 32
    
    var body: some View {
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
                    
                    Text(note.isEmpty ? "Enter a note..." : note)
                        .fontWeight(.medium)
                        .foregroundStyle(note.isEmpty ? Color.secondary : Color.white)
                        .padding(.horizontal)
                        .lineLimit(1)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = true
                                isEditing = true
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, isLandscape ? 44 : 64)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
                        .ignoresSafeArea(edges: .bottom)
                }
                .frame(maxWidth: isLandscape ? 512 : nil, maxHeight: .infinity, alignment: .bottom)
                .offset(y: dragOffset < dragThreshold ? dragOffset : 0)
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
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                        
                        Text("Note")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    
                    // Text field
                    TextField("Enter a note...", text: $note, axis: .vertical)
                        .focused($isEditing)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding()
                    
                    Spacer()
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

#Preview {
    @Previewable @State var note = "This is a sample note that can be expanded by tapping or swiping upwards."
    @Previewable @State var isLandscape = false
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            NoteCardView(note: $note, isLandscape: $isLandscape)
        }
    }
}

