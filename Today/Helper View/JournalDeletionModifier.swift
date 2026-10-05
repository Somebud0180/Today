import SwiftUI
import SwiftData

private struct JournalDeletionModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @Binding var entries: [JournalEntry]
    @State private var errorMessage: String?
    @State private var isDeleting = false
    var completion: () -> Void

    func body(content: Content) -> some View {
        content
            .disabled(isDeleting)
            .confirmationDialog("Delete Entries?", isPresented: Binding(
                get: { !entries.isEmpty }, set: { if !$0 { entries = [] } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    let selected = entries
                    entries = []
                    isDeleting = true
                    Task {
                        defer { isDeleting = false }
                        do {
                            try await JournalStore.delete(selected, context: context)
                            completion()
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
                Button("Cancel", role: .cancel) { entries = [] }
            } message: {
                Text("This permanently deletes the selected entries and their recordings.")
            }
            .alert("Deletion Error", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Please try again.") }
    }
}

extension View {
    func journalDeletion(_ entries: Binding<[JournalEntry]>, completion: @escaping () -> Void = {}) -> some View {
        modifier(JournalDeletionModifier(entries: entries, completion: completion))
    }
}
