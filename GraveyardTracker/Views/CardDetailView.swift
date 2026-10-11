import SwiftUI

struct CardDetailView: View {
    @Environment(\.managedObjectContext) private var context; @ObservedObject var item: DeckCardEntity; @ObservedObject var model: GameViewModel
    // Check the entry before touching `item.card`: a sheet can keep a selected entry after it has been deleted.
    var body: some View {
        if item.isDeletedOrDetached {
            ContentUnavailableView("Card Unavailable", systemImage: "rectangle.slash", description: Text("This card is no longer in the deck.")).navigationTitle("Card").navigationBarTitleDisplayMode(.inline)
        } else {
            details
        }
    }
    private var details: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) { CardArtwork(card: item.card).aspectRatio(0.716, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(radius: 6); VStack(alignment: .leading, spacing: 10) { HStack { Text(item.card.name).font(.title2.bold()); Spacer(); Text(item.card.manaCost ?? "") }; Text(item.card.typeLine).font(.headline).foregroundStyle(.secondary); if let rules = item.card.oracleText { Text(rules) }; if let power = item.card.power, let toughness = item.card.toughness { Text("\(power) / \(toughness)").font(.title3.bold()) }; LabeledContent("Color identity", value: item.card.colorIdentity?.isEmpty == false ? item.card.colorIdentity! : "Colorless") }; Menu("Move from \(item.zone.title)") { ForEach(Zone.allCases, id: \.self) { zone in Button(zone.title) { model.move(item, to: zone, context: context) } } }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity) }.padding() }.navigationTitle(item.card.name).navigationBarTitleDisplayMode(.inline)
    }
}
