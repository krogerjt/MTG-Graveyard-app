import XCTest
import CoreData
@testable import GraveyardTracker

final class CardKindTests: XCTestCase {
    func testDetectsMultiTypeCard() {
        let persistence = PersistenceController(inMemory: true)
        let card = CardEntity(context: persistence.container.viewContext)
        card.typeLine = "Artifact Creature — Golem"
        XCTAssertEqual(card.kinds, [.artifact, .creature])
    }
}
