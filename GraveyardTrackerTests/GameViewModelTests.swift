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
}
