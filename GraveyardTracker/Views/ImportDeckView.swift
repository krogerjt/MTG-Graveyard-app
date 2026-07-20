import SwiftUI

struct ImportDeckView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.managedObjectContext) private var context
    @StateObject private var model = ImportDeckViewModel()
    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") { TextField("Deck name", text: $model.name); TextField("Commander (optional)", text: $model.commander) }
                Section("Decklist") { TextEditor(text: $model.decklist).frame(minHeight: 240).font(.system(.body, design: .monospaced)); Text("One card per line, such as “1 Sol Ring”.").font(.caption).foregroundStyle(.secondary) }
                if model.isImporting { Section { ProgressView(value: model.progress); Text("Importing cards… \(Int(model.progress * 100))%").font(.caption) } }
                if let error = model.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                if !model.failures.isEmpty { Section("Cards not found") { ForEach(model.failures, id: \.self) { Text($0) } } }
            }
            .navigationTitle("Import Deck").navigationBarTitleDisplayMode(.inline).interactiveDismissDisabled(model.isImporting)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isImporting) }; ToolbarItem(placement: .confirmationAction) { Button("Import") { Task { if await model.importDeck(into: context) { dismiss() } } }.disabled(model.isImporting || model.decklist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}
