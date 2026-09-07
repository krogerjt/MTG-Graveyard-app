import SwiftUI
import CoreData

struct DeckListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(fetchRequest: DeckEntity.request()) private var decks: FetchedResults<DeckEntity>
    @State private var showingImport = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty { ContentUnavailableView("No Decks", systemImage: "rectangle.stack.badge.plus", description: Text("Import a decklist to start tracking a game.")) }
                else { List { ForEach(decks) { deck in NavigationLink(value: deck.objectID) { DeckRow(deck: deck) }.swipeActions { Button(role: .destructive) { context.delete(deck); do { try PersistenceController.save(context) } catch { context.rollback(); errorMessage = error.localizedDescription } } label: { Label("Delete", systemImage: "trash") } } } } }
            }
            .navigationTitle("Your Decks")
            .alert("Unable to save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .toolbar { Button { showingImport = true } label: { Label("Import", systemImage: "plus") } }
            .sheet(isPresented: $showingImport) { ImportDeckView() }
            .navigationDestination(for: NSManagedObjectID.self) { id in if let deck = try? context.existingObject(with: id) as? DeckEntity { GameView(deck: deck) } }
        }
    }
}

private struct DeckRow: View {
    @ObservedObject var deck: DeckEntity
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(deck.name).font(.headline); HStack { if let commander = deck.commander { Text(commander) }; Spacer(); Text("\(deck.cards.count) cards").foregroundStyle(.secondary) }.font(.subheadline) } }
}
