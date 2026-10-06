import CoreData
import XCTest
@testable import GraveyardTracker

final class GameViewModelTests: XCTestCase {
    @MainActor
    func testFilteringDoesNotChangeTotalsAndUndoRestoresTimestamp() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let deck = DeckEntity(context: context)
        deck.id = UUID(); deck.name = "Test"; deck.createdDate = Date(); deck.updatedDate = Date()
        let card = CardEntity(context: context)
        card.id = UUID(); card.scryfallID = "fixture"; card.name = "Sol Ring"
        card.typeLine = "Artifact"; card.manaValue = 1
        let item = DeckCardEntity(context: context)
        item.id = UUID(); item.deck = deck; item.card = card
        item.zoneRaw = Zone.library.rawValue; item.zoneChangedAt = Date(timeIntervalSince1970: 100)
        try context.save()
        let model = GameViewModel(deck: deck)
        model.toggle(item, context: context)
        let enteredAt = item.zoneChangedAt
        model.search = "No match"
        model.filter = .creature
        XCTAssertTrue(model.graveyard.isEmpty)
        XCTAssertEqual(model.graveyardCount, 1)
        model.reset(context: context)
        XCTAssertEqual(item.zone, .library)
        model.undo(context: context)
        XCTAssertEqual(item.zone, .graveyard)
        XCTAssertEqual(item.zoneChangedAt, enteredAt)
        model.toggle(item, context: context)
        XCTAssertEqual(item.zone, .library)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testLargeDeckDerivedListsAndStats() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let deck = DeckEntity(context: context)
        deck.id = UUID(); deck.name = "Large deck"; deck.createdDate = Date(); deck.updatedDate = Date()
        let types = ["Creature", "Instant", "Sorcery", "Artifact", "Enchantment", "Land"]

        for index in 0..<250 {
            let card = CardEntity(context: context)
            card.id = UUID(); card.scryfallID = "card-\(index)"; card.name = String(format: "Card %03d", index)
            card.typeLine = types[index % types.count]; card.manaValue = Double(index % 8)
            let item = DeckCardEntity(context: context)
            item.id = UUID(); item.deck = deck; item.card = card
            item.zoneRaw = [Zone.library, .graveyard, .exile][index % 3].rawValue
            item.zoneChangedAt = Date(timeIntervalSince1970: TimeInterval(index))
        }
        try context.save()

        measure {
            let model = GameViewModel(deck: deck)
            XCTAssertEqual(model.allCards.count, 250)
            XCTAssertEqual(model.library.count, 84)
            XCTAssertEqual(model.graveyardCount, 83)
            XCTAssertEqual(model.exile.count, 83)
            XCTAssertEqual(model.typeCounts.reduce(0) { $0 + $1.1 }, 83)
            XCTAssertEqual(model.deliriumTypes.count, 2)
        }
    }
}
