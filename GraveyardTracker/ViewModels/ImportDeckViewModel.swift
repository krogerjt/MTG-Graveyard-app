import CoreData
import Foundation
import Combine

@MainActor
final class ImportDeckViewModel: ObservableObject {
    @Published var name = ""; @Published var commander = ""; @Published var decklist = ""
    @Published private(set) var isImporting = false; @Published private(set) var progress = 0.0
    @Published var failures: [String] = []; @Published var errorMessage: String?
    private let cardLookup: any CardLookupService
    private let artworkService: any ArtworkService

    init() {
        let client = ScryfallClient()
        self.cardLookup = client
        self.artworkService = client
    }

    init(cardLookup: any CardLookupService, artworkService: any ArtworkService) {
        self.cardLookup = cardLookup
        self.artworkService = artworkService
    }

    func importDeck(into context: NSManagedObjectContext, replacing existing: DeckEntity? = nil) async -> Bool {
        isImporting = true; progress = 0; failures = []; errorMessage = nil
        defer { isImporting = false }
        do {
            let parsed = try DecklistParser.parse(decklist)
            guard parsed.reduce(0, { $0 + $1.quantity }) <= 250 else { errorMessage = "Import at most 250 cards at a time."; return false }
            let expanded = parsed.flatMap { item in Array(repeating: item.name, count: item.quantity) }
            var seenNames = Set<String>()
            let uniqueNames = expanded.filter { seenNames.insert($0.lowercased()).inserted }
            let collection = try await cardLookup.cards(named: uniqueNames)
            var lookup = collection.found
            for (index, cardName) in collection.missing.enumerated() {
                do { lookup[cardName.lowercased()] = try await cardLookup.card(named: cardName) } catch { failures.append(cardName) }
                progress = 0.4 * Double(index + 1) / Double(max(collection.missing.count, 1))
            }
            let cards = expanded.compactMap { lookup[$0.lowercased()] }
            progress = 0.4
            guard !cards.isEmpty else { errorMessage = "No cards could be imported."; return false }
            guard failures.isEmpty, cards.count == expanded.count else {
                errorMessage = "Correct the card names listed below, then import again. No partial deck was saved."
                return false
            }
            // Fetch each Scryfall record once; `cards` remains expanded so every copy
            // still gets its own DeckCardEntity below.
            var uniqueCards: [String: ScryfallCard] = [:]
            for card in cards where uniqueCards[card.id] == nil {
                uniqueCards[card.id] = card
            }
            var uniqueCardIDs = Array(uniqueCards.keys)
            uniqueCardIDs.sort()
            var cachedCards = try cachedCards(for: uniqueCardIDs, context: context)

            var images: [String: Data] = [:]
            for (index, cardID) in uniqueCardIDs.enumerated() {
                guard let result = uniqueCards[cardID] else { continue }
                if let cached = cachedCards[result.id]?.imageData {
                    images[result.id] = cached
                } else if let url = result.displayImageURL {
                    images[result.id] = try await artworkService.artwork(at: url)
                }
                progress = 0.4 + 0.6 * Double(index + 1) / Double(max(uniqueCards.count, 1))
            }
            let deck = existing ?? DeckEntity(context: context)
            if existing == nil { deck.id = UUID(); deck.createdDate = Date() }
            else { deck.cards.forEach(context.delete) }
            deck.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Imported Deck" : name
            deck.commander = commander.nilIfEmpty; deck.updatedDate = Date()
            for result in uniqueCards.values {
                let cached = cachedCards[result.id]
                let card = cached ?? CardEntity(context: context)
                if cached == nil { card.id = UUID(); cachedCards[result.id] = card }
                card.scryfallID = result.id; card.name = result.name; card.manaCost = result.displayManaCost; card.manaValue = result.cmc; card.typeLine = result.typeLine; card.oracleText = result.displayRules; card.imageURL = result.displayImageURL; card.imageData = images[result.id]; card.colors = result.colors?.joined(); card.colorIdentity = result.colorIdentity.joined(); card.rarity = result.rarity; card.power = result.power ?? result.cardFaces?.first?.power; card.toughness = result.toughness ?? result.cardFaces?.first?.toughness
            }
            for result in cards {
                let item = DeckCardEntity(context: context); item.id = UUID(); item.deck = deck; item.card = cachedCards[result.id]!; item.zoneRaw = Zone.library.rawValue; item.zoneChangedAt = Date()
            }
            deck.colorIdentity = Set(cards.flatMap(\.colorIdentity)).sorted().joined()
            try PersistenceController.save(context)
            progress = 1
            return true
        } catch { context.rollback(); errorMessage = error.localizedDescription; return false }
    }

    private func cachedCards(for scryfallIDs: [String], context: NSManagedObjectContext) throws -> [String: CardEntity] {
        guard !scryfallIDs.isEmpty else { return [:] }
        let request = NSFetchRequest<CardEntity>(entityName: "CardEntity")
        request.predicate = NSPredicate(format: "scryfallID IN %@", scryfallIDs)
        return try context.fetch(request).reduce(into: [:]) { result, card in
            result[card.scryfallID] = card
        }
    }
}

private extension String { var nilIfEmpty: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
