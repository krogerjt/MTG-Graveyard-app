import CoreData
import Foundation

@MainActor
final class ImportDeckViewModel: ObservableObject {
    @Published var name = ""; @Published var commander = ""; @Published var decklist = ""
    @Published private(set) var isImporting = false; @Published private(set) var progress = 0.0
    @Published var failures: [String] = []; @Published var errorMessage: String?
    private let client = ScryfallClient()

    func importDeck(into context: NSManagedObjectContext) async -> Bool {
        isImporting = true; progress = 0; failures = []; errorMessage = nil
        defer { isImporting = false }
        do {
            let parsed = try DecklistParser.parse(decklist)
            let expanded = parsed.flatMap { item in Array(repeating: item.name, count: item.quantity) }
            let collection = try await client.cards(named: expanded)
            var lookup = collection.found
            for (index, cardName) in collection.missing.enumerated() {
                do { lookup[cardName.lowercased()] = try await client.card(named: cardName) } catch { failures.append(cardName) }
                progress = 0.8 + (0.2 * Double(index + 1) / Double(max(collection.missing.count, 1)))
            }
            let cards = expanded.compactMap { lookup[$0.lowercased()] }
            progress = 1
            guard !cards.isEmpty else { errorMessage = "No cards could be imported."; return false }
            guard failures.isEmpty else {
                errorMessage = "Correct the card names listed below, then import again. No partial deck was saved."
                return false
            }
            let deck = DeckEntity(context: context); deck.id = UUID(); deck.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Imported Deck" : name; deck.commander = commander.nilIfEmpty; deck.createdDate = Date(); deck.updatedDate = Date()
            for result in cards {
                let cached = cachedCard(scryfallID: result.id, context: context)
                let card = cached ?? CardEntity(context: context)
                if cached == nil { card.id = UUID() }
                card.scryfallID = result.id; card.name = result.name; card.manaCost = result.manaCost; card.manaValue = result.cmc; card.typeLine = result.typeLine; card.oracleText = result.oracleText; card.imageURL = result.imageUris?["normal"]; card.colors = result.colors?.joined(); card.colorIdentity = result.colorIdentity.joined(); card.rarity = result.rarity; card.power = result.power; card.toughness = result.toughness
                let item = DeckCardEntity(context: context); item.id = UUID(); item.deck = deck; item.card = card; item.zoneRaw = Zone.library.rawValue; item.zoneChangedAt = Date()
            }
            deck.colorIdentity = Set(cards.flatMap(\.colorIdentity)).sorted().joined()
            try PersistenceController.save(context)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    private func cachedCard(scryfallID: String, context: NSManagedObjectContext) -> CardEntity? { let request = NSFetchRequest<CardEntity>(entityName: "CardEntity"); request.predicate = NSPredicate(format: "scryfallID == %@", scryfallID); request.fetchLimit = 1; return try? context.fetch(request).first }
}

private extension String { var nilIfEmpty: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
