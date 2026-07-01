//
//  JournalGridView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/23/26.
//

import SwiftUI
import SwiftData

struct JournalGridView<Destination: View>: View {
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedEntries: [JournalEntry]
    let entries: [JournalEntry]
    let metrics: ViewLayoutMetrics
    let isEditing: Bool
    let namespace: Namespace.ID
    let destination: (JournalEntry) -> Destination
    var onShare: ((JournalEntry) -> Void)? = nil
    
    var body: some View {
        LazyVGrid(columns: metrics.columns, alignment: .leading, spacing: metrics.spacing) {
            ForEach(entries) { entry in
                let isSelected = selectedEntries.contains(entry)
                
                NavigationLink(destination: destination(entry)) {
                    GridCardView(for: entry, size: metrics.cardSize)
                        .matchedTransitionSource(id: entry, in: namespace)
                }
                .buttonStyle(.plain)
                .id(entry.date)
                .opacity(isEditing && !isSelected ? 0.8 : 1)
                .accessibilityHidden(isEditing)
                .allowsHitTesting(!isEditing)
                .contextMenu {
                    if let onShare {
                        Button {
                            onShare(entry)
                        } label: {
                            Label("Export Entry", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(entry)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                    
#if DEBUG
                    Button {
                        
                    } label: {
                        Label("\(entry.mediaURL?.fileSizeString ?? "File size unavailable")", systemImage: "info.circle")
                    }
#endif
                }
                .overlay {
                    if isEditing {
                        Color.clear
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                            .onTapGesture {
                                if isSelected {
                                    selectedEntries.removeAll(where: { $0 == entry })
                                } else {
                                    selectedEntries.append(entry)
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel(GridCardView.accessibilityTitle(for: entry))
                            .accessibilityValue(isSelected ? "Selected" : "Not selected")
                            .accessibilityHint("Double-tap to select")
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction {
                                if isSelected {
                                    selectedEntries.removeAll(where: { $0 == entry })
                                } else {
                                    selectedEntries.append(entry)
                                }
                            }
                    }
                }
            }
        }
        .scrollTargetLayout()
    }
}
