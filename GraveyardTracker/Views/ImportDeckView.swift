import SwiftUI

struct ImportDeckView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.managedObjectContext) private var context
    @StateObject private var model = ImportDeckViewModel()
    let existing: DeckEntity?
    init(existing: DeckEntity? = nil) { self.existing = existing }
    var body: some View {
        NavigationStack {
            Form {
                if existing != nil { Section { Text("Saving deck edits replaces the card list and resets all cards to Library.") } }
                Section("Deck") { TextField("Deck name", text: $model.name); TextField("Commander (optional)", text: $model.commander).autocorrectionDisabled() }
                Section("Decklist") { TextEditor(text: $model.decklist).autocorrectionDisabled().frame(minHeight: 240).font(.system(.body, design: .monospaced)); Text("One card per line, such as “1 Sol Ring”.").font(.caption).foregroundStyle(.secondary) }
                if model.isImporting { Section { ProgressView(value: model.progress); Text("Importing cards… \(Int(model.progress * 100))%").font(.caption) } }
                if let error = model.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                if !model.failures.isEmpty { Section("Cards not found") { ForEach(model.failures, id: \.self) { Text($0) } } }
            }
            .onAppear {
                guard let existing, model.decklist.isEmpty else { return }
                model.name = existing.name; model.commander = existing.commander ?? ""
                model.decklist = existing.sortedCards.map { "1 " + $0.card.name }.joined(separator: "\n")
            }
            .navigationTitle(existing == nil ? "Import Deck" : "Edit Deck").navigationBarTitleDisplayMode(.inline).interactiveDismissDisabled(model.isImporting)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isImporting) }; ToolbarItem(placement: .confirmationAction) { Button("Import") { Task { if await model.importDeck(into: context, replacing: existing) { dismiss() } } }.disabled(model.isImporting || model.decklist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}
