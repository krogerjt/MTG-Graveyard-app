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
    func testImportAtCardLimitKeepsCopiesButPersistsOneCardRecord() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let card = fixtureCard(id: "sol-ring", name: "Sol Ring")
        let probe = ImportServiceProbe()
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(found: ["sol ring": card], probe: probe),
            artworkService: FakeArtworkService(data: Data([1]), probe: probe)
        )
        model.decklist = "250 Sol Ring"

        let imported = await model.importDeck(into: context)

        XCTAssertTrue(imported, model.errorMessage ?? "Import should succeed")
        let cards = try context.fetch(NSFetchRequest<CardEntity>(entityName: "CardEntity"))
        let deckCards = try context.fetch(NSFetchRequest<DeckCardEntity>(entityName: "DeckCardEntity"))
        XCTAssertEqual(cards.count, 1, "Duplicate copies should share one persisted card record")
        XCTAssertEqual(deckCards.count, 250)
        XCTAssertEqual(probe.batchLookupCalls, 1)
        XCTAssertEqual(probe.requestedNameCount, 1, "Repeated copies should be looked up once")
        XCTAssertEqual(probe.artworkRequests, 1, "Repeated copies should download artwork once")
        XCTAssertTrue(deckCards.allSatisfy { $0.card == cards[0] })
        XCTAssertTrue(deckCards.allSatisfy { $0.zone == .library })
    }

    @MainActor
    func testImportAtCardLimitPerformance() async throws {
        let runs = 5
        var elapsed = 0.0
        for _ in 0..<runs {
            let persistence = PersistenceController(inMemory: true)
            let context = persistence.container.viewContext
            let card = fixtureCard(id: "sol-ring", name: "Sol Ring")
            let probe = ImportServiceProbe()
            let model = ImportDeckViewModel(
                cardLookup: FakeCardLookupService(found: ["sol ring": card], probe: probe),
                artworkService: FakeArtworkService(data: Data([1]), probe: probe)
            )
            model.decklist = "250 Sol Ring"

            let start = ProcessInfo.processInfo.systemUptime
            let imported = await model.importDeck(into: context)
            elapsed += ProcessInfo.processInfo.systemUptime - start

            XCTAssertTrue(imported, model.errorMessage ?? "Import should succeed")
            let cards = try context.fetch(NSFetchRequest<CardEntity>(entityName: "CardEntity"))
            let deckCards = try context.fetch(NSFetchRequest<DeckCardEntity>(entityName: "DeckCardEntity"))
            XCTAssertEqual(cards.count, 1)
            XCTAssertEqual(deckCards.count, 250)
            XCTAssertEqual(probe.requestedNameCount, 1)
            XCTAssertEqual(probe.artworkRequests, 1)
        }
        XCTContext.runActivity(named: "250-card import performance") { activity in
            activity.add(XCTAttachment(string: "Average duration: \(elapsed / Double(runs)) seconds across \(runs) in-memory imports"))
        }
    }

    @MainActor
    func testImportReusesCachedCardRecordAndArtwork() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let cachedImage = Data([9, 8, 7])
        let cached = CardEntity(context: context)
        cached.id = UUID()
        cached.scryfallID = "sol-ring"
        cached.name = "Sol Ring"
        cached.typeLine = "Artifact"
        cached.imageData = cachedImage
        cached.manaValue = 1
        try context.save()

        let probe = ImportServiceProbe()
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(found: ["sol ring": fixtureCard(id: "sol-ring", name: "Sol Ring")]),
            artworkService: FakeArtworkService(data: Data([1]), probe: probe)
        )
        model.decklist = "2 Sol Ring"

        let imported = await model.importDeck(into: context)

        XCTAssertTrue(imported, model.errorMessage ?? "Import should succeed")
        let cards = try context.fetch(NSFetchRequest<CardEntity>(entityName: "CardEntity"))
        let deckCards = try context.fetch(NSFetchRequest<DeckCardEntity>(entityName: "DeckCardEntity"))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(deckCards.count, 2)
        XCTAssertTrue(deckCards.allSatisfy { $0.card.objectID == cached.objectID })
        XCTAssertEqual(cached.imageData, cachedImage)
        XCTAssertEqual(probe.artworkRequests, 0, "Cached artwork should avoid another download")
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
    func testNetworkFailureDoesNotReplaceDeckOrLookLikeMissingCard() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let existing = try makeSavedDeck(in: context)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        let client = ScryfallClient(session: URLSession(configuration: configuration))
        let model = ImportDeckViewModel(cardLookup: client, artworkService: client)
        model.name = "Replacement"
        model.decklist = "1 HTTP Failure"

        let imported = await model.importDeck(into: context, replacing: existing)

        XCTAssertFalse(imported)
        XCTAssertTrue(model.errorMessage?.contains("HTTP 503") == true, model.errorMessage ?? "Expected a server error message")
        XCTAssertFalse(model.errorMessage?.contains("Correct the card names") == true)
        XCTAssertTrue(model.failures.isEmpty, "A server failure must not be classified as a missing card")
        try assertSeedDeckIsUnchanged(in: context)
    }

    @MainActor
    func testFallbackTransportFailureSurfacesAndDoesNotPartiallyReplaceDeck() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let existing = try makeSavedDeck(in: context)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        let client = ScryfallClient(session: URLSession(configuration: configuration))
        let model = ImportDeckViewModel(cardLookup: client, artworkService: client)
        model.name = "Replacement"
        model.decklist = "1 Front // Back\n1 Fallback Transport Failure"

        let imported = await model.importDeck(into: context, replacing: existing)

        XCTAssertFalse(imported)
        XCTAssertEqual(model.errorMessage, URLError(.notConnectedToInternet).localizedDescription)
        XCTAssertTrue(model.failures.isEmpty, "A transport failure must not be classified as a missing card")
        XCTAssertFalse(model.errorMessage?.contains("Correct the card names") == true)
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
    func testSuccessfulEditReplacesDeckCardsAndPreservesDeckIdentity() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let existing = try makeSavedDeck(in: context)
        let originalID = existing.id
        let originalCreatedDate = existing.createdDate
        let originalUpdatedDate = existing.updatedDate
        let solRing = fixtureCard(id: "sol-ring", name: "Sol Ring")
        let signet = fixtureCard(id: "arcane-signet", name: "Arcane Signet")
        let model = ImportDeckViewModel(
            cardLookup: FakeCardLookupService(found: ["sol ring": solRing, "arcane signet": signet]),
            artworkService: FakeArtworkService(data: Data([1, 2, 3]))
        )
        model.name = "Edited Deck"
        model.commander = "Edited Commander"
        model.decklist = "2 Sol Ring\n1 Arcane Signet"

        let imported = await model.importDeck(into: context, replacing: existing)

        XCTAssertTrue(imported, model.errorMessage ?? "Edit should succeed")
        XCTAssertTrue(model.failures.isEmpty)

        // Reset and refetch so these assertions inspect saved state, not just registered objects.
        context.reset()
        let decks = try context.fetch(DeckEntity.request())
        XCTAssertEqual(decks.count, 1, "Editing must update the deck rather than create another one")
        let deck = try XCTUnwrap(decks.first)
        XCTAssertEqual(deck.id, originalID)
        XCTAssertEqual(deck.createdDate, originalCreatedDate)
        XCTAssertGreaterThan(deck.updatedDate, originalUpdatedDate)
        XCTAssertEqual(deck.name, "Edited Deck")
        XCTAssertEqual(deck.commander, "Edited Commander")

        let deckCards = try context.fetch(NSFetchRequest<DeckCardEntity>(entityName: "DeckCardEntity"))
        XCTAssertEqual(deckCards.count, 3, "The original entry should be replaced, not kept alongside new ones")
        XCTAssertEqual(deck.cards.count, 3)
        XCTAssertEqual(deck.cards.map { $0.card.name }.sorted(), ["Arcane Signet", "Sol Ring", "Sol Ring"])
        XCTAssertFalse(deck.cards.contains { $0.card.scryfallID == "original-card" })
        XCTAssertTrue(deck.cards.allSatisfy { $0.zone == .library })
        XCTAssertTrue(deckCards.allSatisfy { $0.deck == deck })
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

private final class ImportServiceProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var batchLookups = 0
    private var requestedNames = 0
    private var artworkDownloads = 0

    var batchLookupCalls: Int { lock.lock(); defer { lock.unlock() }; return batchLookups }
    var requestedNameCount: Int { lock.lock(); defer { lock.unlock() }; return requestedNames }
    var artworkRequests: Int { lock.lock(); defer { lock.unlock() }; return artworkDownloads }

    func recordBatchLookup(nameCount: Int) {
        lock.lock(); defer { lock.unlock() }
        batchLookups += 1
        requestedNames += nameCount
    }

    func recordArtworkRequest() {
        lock.lock(); defer { lock.unlock() }
        artworkDownloads += 1
    }
}

private struct FakeCardLookupService: CardLookupService {
    let found: [String: ScryfallCard]
    var missing: [String] = []
    var individualLookupFails = false
    var probe: ImportServiceProbe? = nil

    func cards(named names: [String]) async throws -> (found: [String: ScryfallCard], missing: [String]) {
        probe?.recordBatchLookup(nameCount: names.count)
        return (found, missing)
    }

    func card(named name: String) async throws -> ScryfallCard {
        if individualLookupFails { throw ImportError.notFound(name) }
        guard let card = found[name.lowercased()] else {
            throw FixtureServiceError.expectedFailure
        }
        return card
    }
}

private struct FakeArtworkService: ArtworkService {
    var data = Data()
    var shouldFail = false
    var probe: ImportServiceProbe? = nil

    func artwork(at url: String) async throws -> Data {
        probe?.recordArtworkRequest()
        guard !shouldFail else { throw FixtureServiceError.expectedFailure }
        return data
    }
}

private enum FixtureServiceError: Error {
    case expectedFailure
}
