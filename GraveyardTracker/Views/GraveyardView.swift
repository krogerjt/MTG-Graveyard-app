import SwiftUI

struct GraveyardView: View {
    @Environment(\.managedObjectContext) private var context; @ObservedObject var model: GameViewModel
    var body: some View {
        NavigationStack {
            List {
                DeliriumBanner(model: model)
                ForEach(model.graveyard) { item in NavigationLink { CardDetailView(item: item, model: model) } label: { CardRow(item: item) }.swipeActions(edge: .leading) { Button { model.move(item, to: .library, context: context) } label: { Label("Library", systemImage: "rectangle.stack") }.tint(.blue) }.swipeActions { Button { model.move(item, to: .exile, context: context) } label: { Label("Exile", systemImage: "flame") }.tint(.orange) } }
            }
            .overlay { if model.graveyard.isEmpty { ContentUnavailableView("Graveyard Empty", systemImage: "cross", description: Text(model.search.isEmpty ? "Tap a library card to put it here." : "No cards match your search.")) } }
            .navigationTitle("Graveyard").searchable(text: $model.search, prompt: "Search card names")
            .toolbar { Menu { Picker("Sort", selection: $model.sort) { ForEach(GraveyardSort.allCases) { Text($0.rawValue).tag($0) } }; Divider(); Button("All types") { model.filter = nil }; ForEach(CardKind.allCases) { kind in Button(kind.rawValue) { model.filter = kind } } } label: { Label("Sort and filter", systemImage: model.filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") } }
        }
    }
}

struct CardRow: View {
    @ObservedObject var item: DeckCardEntity
    var body: some View { HStack(spacing: 12) { AsyncImage(url: item.card.imageURL.flatMap(URL.init)) { image in image.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15).overlay { Image(systemName: "photo") } }.frame(width: 48, height: 67).clipShape(RoundedRectangle(cornerRadius: 4)); VStack(alignment: .leading, spacing: 3) { Text(item.card.name).font(.headline); Text(item.card.typeLine).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Text(item.card.manaValue.formatted()).font(.caption.monospacedDigit()).padding(6).background(.thinMaterial, in: Circle()) } }
}

private struct DeliriumBanner: View {
    @ObservedObject var model: GameViewModel
    var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Label("Delirium", systemImage: model.deliriumActive ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(model.deliriumActive ? .green : .secondary); Spacer(); Text("\(model.deliriumTypes.count) types").foregroundStyle(.secondary) }; if !model.deliriumTypes.isEmpty { Text(model.deliriumTypes.map(\.rawValue).sorted().joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 4) }
}
