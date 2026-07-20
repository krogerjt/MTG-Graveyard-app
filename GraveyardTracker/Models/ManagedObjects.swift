import CoreData
import Foundation

@objc(DeckEntity)
final class DeckEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var commander: String?
    @NSManaged var colorIdentity: String?
    @NSManaged var artworkURL: String?
    @NSManaged var createdDate: Date
    @NSManaged var updatedDate: Date
    @NSManaged var cards: Set<DeckCardEntity>
}

extension DeckEntity {
    static func request() -> NSFetchRequest<DeckEntity> {
        let request = NSFetchRequest<DeckEntity>(entityName: "DeckEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DeckEntity.updatedDate, ascending: false)]
        return request
    }
    var sortedCards: [DeckCardEntity] { cards.sorted { $0.card.name < $1.card.name } }
}

@objc(CardEntity)
final class CardEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var scryfallID: String
    @NSManaged var name: String
    @NSManaged var manaCost: String?
    @NSManaged var manaValue: Double
    @NSManaged var typeLine: String
    @NSManaged var oracleText: String?
    @NSManaged var imageURL: String?
    @NSManaged var colors: String?
    @NSManaged var colorIdentity: String?
    @NSManaged var rarity: String?
    @NSManaged var power: String?
    @NSManaged var toughness: String?
    @NSManaged var deckCards: Set<DeckCardEntity>

    var kinds: Set<CardKind> {
        Set(CardKind.allCases.filter { typeLine.localizedCaseInsensitiveContains($0.rawValue) })
    }
}

@objc(DeckCardEntity)
final class DeckCardEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var zoneRaw: String
    @NSManaged var zoneChangedAt: Date
    @NSManaged var deck: DeckEntity
    @NSManaged var card: CardEntity

    var zone: Zone {
        get { Zone(rawValue: zoneRaw) ?? .library }
        set { zoneRaw = newValue.rawValue; zoneChangedAt = Date() }
    }
}
