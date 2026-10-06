import SwiftUI

struct GameView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var model: GameViewModel; @State private var showingReset = false; @State private var editingName = false; @State private var draftName = ""
    @State private var showingEdit = false
    @State private var selectedCard: DeckCardEntity?
    init(deck: DeckEntity) { _model = StateObject(wrappedValue: GameViewModel(deck: deck)) }
    var body: some View {
        TabView {
            allCards.tabItem { Label("Cards", systemImage: "rectangle.stack") }
            GraveyardView(model: model).tabItem { Label("Graveyard", systemImage: "cross.fill") }.badge(model.graveyardCount)
            StatsView(model: model).tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .navigationTitle(model.deck.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { Menu { Button("Undo", systemImage: "arrow.uturn.backward") { model.undo(context: context) }.disabled(!model.canUndo); Button("Edit deck") { showingEdit = true }; Button("Rename", systemImage: "pencil") { draftName = model.deck.name; editingName = true }; Button("Reset game", systemImage: "arrow.counterclockwise", role: .destructive) { showingReset = true } } label: { Image(systemName: "ellipsis.circle") } }
        .confirmationDialog("Return every card to the library?", isPresented: $showingReset, titleVisibility: .visible) { Button("Reset Game", role: .destructive) { model.reset(context: context) } }
        .sheet(isPresented: $showingEdit, onDismiss: { model.clearHistory() }) { ImportDeckView(existing: model.deck) }
        .sheet(item: $selectedCard) { item in NavigationStack { CardDetailView(item: item, model: model) } }
        .alert("Unable to save", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Rename Deck", isPresented: $editingName) { TextField("Name", text: $draftName); Button("Cancel", role: .cancel) {}; Button("Save") { model.deck.name = draftName; model.deck.updatedDate = Date(); do { try PersistenceController.save(context); model.objectWillChange.send() } catch { context.rollback(); model.errorMessage = error.localizedDescription } } }
    }
    private var allCards: some View {
        List {
            Section { zoneSummary }
            Section("All cards · tap to toggle graveyard") {
                ForEach(model.allCards) { item in
                    HStack {
                        Button { model.toggle(item, context: context) } label: {
                            VStack(alignment: .leading) {
                                CardRow(item: item)
                                Text(item.zone.title).font(.caption).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { selectedCard = item } label: { Image(systemName: "info.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Card details")
                    }.contextMenu { zoneMenu(item) }
                }
            }
        }
    }
    private var zoneSummary: some View { HStack { Label("\(model.graveyardCount)", systemImage: "cross.fill"); Spacer(); Label("\(model.library.count)", systemImage: "rectangle.stack"); Spacer(); Label("\(model.exile.count)", systemImage: "flame") }.foregroundStyle(.secondary) }
    @ViewBuilder private func zoneMenu(_ item: DeckCardEntity) -> some View { Button("Undo") { model.undo(context: context) }.disabled(!model.canUndo); Button("Move to graveyard") { model.move(item, to: .graveyard, context: context) }; Button("Return to library") { model.move(item, to: .library, context: context) }; Button("Exile") { model.move(item, to: .exile, context: context) } }
}
