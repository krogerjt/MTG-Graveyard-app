import SwiftUI

struct GameView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var model: GameViewModel; @State private var showingReset = false; @State private var editingName = false; @State private var draftName = ""
    init(deck: DeckEntity) { _model = StateObject(wrappedValue: GameViewModel(deck: deck)) }
    var body: some View {
        TabView {
            allCards.tabItem { Label("Cards", systemImage: "rectangle.stack") }
            GraveyardView(model: model).tabItem { Label("Graveyard", systemImage: "cross.fill") }.badge(model.graveyard.count)
            StatsView(model: model).tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .navigationTitle(model.deck.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { Menu { Button("Rename", systemImage: "pencil") { draftName = model.deck.name; editingName = true }; Button("Reset game", systemImage: "arrow.counterclockwise", role: .destructive) { showingReset = true } } label: { Image(systemName: "ellipsis.circle") } }
        .confirmationDialog("Return every card to the library?", isPresented: $showingReset, titleVisibility: .visible) { Button("Reset Game", role: .destructive) { model.reset(context: context) } }
        .alert("Rename Deck", isPresented: $editingName) { TextField("Name", text: $draftName); Button("Cancel", role: .cancel) {}; Button("Save") { model.deck.name = draftName; model.deck.updatedDate = Date(); try? PersistenceController.save(context) } }
    }
    private var allCards: some View {
        List { Section { zoneSummary }; Section("Library") { ForEach(model.library) { item in CardRow(item: item).contentShape(Rectangle()).onTapGesture { model.toggle(item, context: context) }.contextMenu { zoneMenu(item) } } }; if !model.exile.isEmpty { Section("Exile") { ForEach(model.exile) { item in CardRow(item: item).contextMenu { zoneMenu(item) } } } } }
    }
    private var zoneSummary: some View { HStack { Label("\(model.graveyard.count)", systemImage: "cross.fill"); Spacer(); Label("\(model.library.count)", systemImage: "rectangle.stack"); Spacer(); Label("\(model.exile.count)", systemImage: "flame") }.foregroundStyle(.secondary) }
    @ViewBuilder private func zoneMenu(_ item: DeckCardEntity) -> some View { Button("Move to graveyard") { model.move(item, to: .graveyard, context: context) }; Button("Return to library") { model.move(item, to: .library, context: context) }; Button("Exile") { model.move(item, to: .exile, context: context) } }
}
