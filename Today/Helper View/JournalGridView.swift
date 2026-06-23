//
//  JournalGridView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/23/26.
//

import SwiftUI

struct JournalGridView<Destination: View>: View {
    let entries: [JournalEntry]
    let metrics: ViewLayoutMetrics
    let isEditing: Bool
    @Binding var selectedEntries: [JournalEntry]
    let destination: (JournalEntry) -> Destination
    let namespace: Namespace.ID
    
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
