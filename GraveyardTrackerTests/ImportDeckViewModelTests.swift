import CoreData
import XCTest
@testable import GraveyardTracker

final class ImportDeckViewModelTests: XCTestCase {
    @MainActor
    func testImportPersistsArtworkForOfflineUse() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let artwork = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])
        let card = fixtureCard(id: "sol-ring", name: "Sol Ring")
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(found: ["sol ring": card]),
            artworkService: FakeArtworkService(data: artwork)
        )
        model.name = "Artifacts"
        model.decklist = "1 Sol Ring"

        let imported = await model.importDeck(into: context)

        XCTAssertTrue(imported, model.errorMessage ?? "Import should succeed")
        context.reset()

        let cards = try context.fetch(NSFetchRequest<CardEntity>(entityName: "CardEntity"))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.name, "Sol Ring")
        XCTAssertEqual(cards.first?.imageData, artwork)
        let decks = try context.fetch(DeckEntity.request())
        XCTAssertEqual(decks.count, 1)
        XCTAssertEqual(decks.first?.name, "Artifacts")
        XCTAssertEqual(decks.first?.cards.count, 1)
    }

    @MainActor
    func testMissingCardLookupDoesNotReplaceOrPartiallySaveDeck() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let existing = try makeSavedDeck(in: context)
        let foundCard = fixtureCard(id: "sol-ring", name: "Sol Ring")
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(
                found: ["sol ring": foundCard],
                missing: ["Unknown Card"],
                individualLookupFails: true
            ),
            artworkService: FakeArtworkService(data: Data([1]))
        )
        model.name = "Replacement"
        model.decklist = "1 Sol Ring\n1 Unknown Card"

        let imported = await model.importDeck(into: context, replacing: existing)

        XCTAssertFalse(imported)
        XCTAssertEqual(model.failures, ["Unknown Card"])
        try assertSeedDeckIsUnchanged(in: context)
    }

    @MainActor
    func testArtworkDownloadFailureDoesNotReplaceOrPartiallySaveDeck() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let existing = try makeSavedDeck(in: context)
        let card = fixtureCard(id: "sol-ring", name: "Sol Ring")
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(found: ["sol ring": card]),
            artworkService: FakeArtworkService(shouldFail: true)
        )
        model.name = "Replacement"
        model.decklist = "1 Sol Ring"

        let imported = await model.importDeck(into: context, replacing: existing)

        XCTAssertFalse(imported)
        XCTAssertNotNil(model.errorMessage)
        try assertSeedDeckIsUnchanged(in: context)
    }

    @MainActor
    private func makeSavedDeck(in context: NSManagedObjectContext) throws -> DeckEntity {
        let deck = DeckEntity(context: context)
        deck.id = UUID()
        deck.name = "Original Deck"
        deck.createdDate = Date(timeIntervalSince1970: 1)
        deck.updatedDate = Date(timeIntervalSince1970: 1)

        let card = CardEntity(context: context)
        card.id = UUID()
        card.scryfallID = "original-card"
        card.name = "Original Card"
        card.typeLine = "Creature"
        card.manaValue = 1

        let item = DeckCardEntity(context: context)
        item.id = UUID()
        item.deck = deck
        item.card = card
        item.zoneRaw = Zone.library.rawValue
        item.zoneChangedAt = Date(timeIntervalSince1970: 1)
        try context.save()
        return deck
    }

    @MainActor
    private func assertSeedDeckIsUnchanged(in context: NSManagedObjectContext) throws {
        // Reset and refetch so these assertions inspect saved state, not just registered objects.
        context.reset()
        let decks = try context.fetch(DeckEntity.request())
        XCTAssertEqual(decks.count, 1, "A failed replacement must not create a partial deck")
        XCTAssertEqual(decks.first?.name, "Original Deck")
        XCTAssertEqual(decks.first?.cards.map { $0.card.name }, ["Original Card"])

        let cards = try context.fetch(NSFetchRequest<CardEntity>(entityName: "CardEntity"))
        XCTAssertEqual(cards.map(\.name), ["Original Card"], "No cards from the failed import should be persisted")
        let deckCards = try context.fetch(NSFetchRequest<DeckCardEntity>(entityName: "DeckCardEntity"))
        XCTAssertEqual(deckCards.count, 1)
    }

    private func fixtureCard(id: String, name: String) -> ScryfallCard {
        ScryfallCard(
            id: id,
            name: name,
            manaCost: nil,
            cmc: 1,
            typeLine: "Artifact",
            oracleText: nil,
            colors: nil,
            colorIdentity: [],
            rarity: "rare",
            power: nil,
            toughness: nil,
            imageUris: ["normal": "https://example.com/\(id).jpg"],
            cardFaces: nil
        )
    }
}

private struct FakeCardLookupService: CardLookupService {
    let found: [String: ScryfallCard]
    var missing: [String] = []
    var individualLookupFails = false

    func cards(named names: [String]) async throws -> (found: [String: ScryfallCard], missing: [String]) {
        (found, missing)
    }

    func card(named name: String) async throws -> ScryfallCard {
        guard !individualLookupFails, let card = found[name.lowercased()] else {
            throw FixtureServiceError.expectedFailure
        }
        return card
    }
}

private struct FakeArtworkService: ArtworkService {
    var data = Data()
    var shouldFail = false

    func artwork(at url: String) async throws -> Data {
        guard !shouldFail else { throw FixtureServiceError.expectedFailure }
        return data
    }
}

private enum FixtureServiceError: Error {
    case expectedFailure
}
