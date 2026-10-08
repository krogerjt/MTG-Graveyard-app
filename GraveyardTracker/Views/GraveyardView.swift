import SwiftUI

struct GraveyardView: View {
    @Environment(\.managedObjectContext) private var context; @ObservedObject var model: GameViewModel
    var body: some View {
        let graveyard = model.graveyard
        // No NavigationStack of its own: this view lives inside GameView, which the deck list already pushed onto a stack.
        VStack(spacing: 0) {
            GraveyardControls(model: model)
            List {
                DeliriumBanner(model: model)
                ForEach(graveyard) { item in NavigationLink { CardDetailView(item: item, model: model) } label: { CardRow(item: item) }.swipeActions(edge: .leading) { Button { model.move(item, to: .library, context: context) } label: { Label("Library", systemImage: "rectangle.stack") }.tint(.blue) }.swipeActions { Button { model.move(item, to: .exile, context: context) } label: { Label("Exile", systemImage: "flame") }.tint(.orange) } }
            }
            .overlay { if graveyard.isEmpty { ContentUnavailableView("Graveyard Empty", systemImage: "cross", description: Text(model.search.isEmpty ? "Tap a library card to put it here." : "No cards match your search.")) } }
            .navigationTitle("Graveyard")
        }
    }
}

struct CardRow: View {
    @ObservedObject var item: DeckCardEntity
    var body: some View { HStack(spacing: 12) { CardArtwork(card: item.card).frame(width: 48, height: 67).clipShape(RoundedRectangle(cornerRadius: 4)); VStack(alignment: .leading, spacing: 3) { Text(item.card.name).font(.headline); Text(item.card.typeLine).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Text(item.card.manaValue.formatted()).font(.caption.monospacedDigit()).padding(6).background(.thinMaterial, in: Circle()) } }
}

private struct DeliriumBanner: View {
    @ObservedObject var model: GameViewModel
    var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Label("Delirium", systemImage: model.deliriumActive ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(model.deliriumActive ? .green : .secondary); Spacer(); Text("\(model.deliriumTypes.count) types").foregroundStyle(.secondary) }; if !model.deliriumTypes.isEmpty { Text(model.deliriumTypes.map(\.rawValue).sorted().joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 4) }
}

/// Search, sort and type filter live in the list screen itself, not the navigation bar: this screen sits inside
/// GameView, whose navigation bar belongs to the deck list stack.
private struct GraveyardControls: View {
    @ObservedObject var model: GameViewModel
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search card names", text: $model.search).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
                }
            }
            .padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Picker("Sort", selection: $model.sort) { ForEach(GraveyardSort.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                Spacer()
                Picker("Type", selection: $model.filter) { Text("All types").tag(CardKind?.none); ForEach(CardKind.allCases) { Text($0.rawValue).tag(CardKind?.some($0)) } }.pickerStyle(.menu)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }
}
