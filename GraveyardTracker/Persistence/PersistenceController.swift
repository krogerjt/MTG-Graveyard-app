import CoreData
import Combine

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    @Published private(set) var storeError: String?
    @Published private(set) var isReady = false

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GraveyardTracker", managedObjectModel: Self.model)
        if inMemory { container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null") }
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        loadStore()
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func loadStore() {
        storeError = nil
        container.loadPersistentStores { [weak self] _, error in
            DispatchQueue.main.async {
                self?.storeError = error?.localizedDescription
                self?.isReady = error == nil
            }
        }
    }

    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let deck = entity("DeckEntity", DeckEntity.self)
        let card = entity("CardEntity", CardEntity.self)
        let deckCard = entity("DeckCardEntity", DeckCardEntity.self)

        deck.properties = [attribute("id", .UUIDAttributeType), attribute("name", .stringAttributeType), optional("commander", .stringAttributeType), optional("colorIdentity", .stringAttributeType), optional("artworkURL", .stringAttributeType), attribute("createdDate", .dateAttributeType), attribute("updatedDate", .dateAttributeType)]
        card.properties = [attribute("id", .UUIDAttributeType), attribute("scryfallID", .stringAttributeType), attribute("name", .stringAttributeType), optional("manaCost", .stringAttributeType), attribute("manaValue", .doubleAttributeType), attribute("typeLine", .stringAttributeType), optional("oracleText", .stringAttributeType), optional("imageURL", .stringAttributeType), optional("colors", .stringAttributeType), optional("colorIdentity", .stringAttributeType), optional("rarity", .stringAttributeType), optional("power", .stringAttributeType), optional("toughness", .stringAttributeType)]
        let imageData = optional("imageData", .binaryDataAttributeType)
        imageData.allowsExternalBinaryDataStorage = true
        card.properties.append(imageData)
        deckCard.properties = [attribute("id", .UUIDAttributeType), attribute("zoneRaw", .stringAttributeType), attribute("zoneChangedAt", .dateAttributeType)]

        let deckToCards = NSRelationshipDescription(); deckToCards.name = "cards"; deckToCards.destinationEntity = deckCard; deckToCards.minCount = 0; deckToCards.maxCount = 0; deckToCards.deleteRule = .cascadeDeleteRule; deckToCards.isOptional = true; deckToCards.isOrdered = false
        let dcToDeck = NSRelationshipDescription(); dcToDeck.name = "deck"; dcToDeck.destinationEntity = deck; dcToDeck.minCount = 1; dcToDeck.maxCount = 1; dcToDeck.deleteRule = .nullifyDeleteRule; dcToDeck.isOptional = false
        deckToCards.inverseRelationship = dcToDeck; dcToDeck.inverseRelationship = deckToCards
        deck.properties.append(deckToCards); deckCard.properties.append(dcToDeck)

        let cardToDeckCards = NSRelationshipDescription(); cardToDeckCards.name = "deckCards"; cardToDeckCards.destinationEntity = deckCard; cardToDeckCards.minCount = 0; cardToDeckCards.maxCount = 0; cardToDeckCards.deleteRule = .cascadeDeleteRule; cardToDeckCards.isOptional = true; cardToDeckCards.isOrdered = false
        let dcToCard = NSRelationshipDescription(); dcToCard.name = "card"; dcToCard.destinationEntity = card; dcToCard.minCount = 1; dcToCard.maxCount = 1; dcToCard.deleteRule = .nullifyDeleteRule; dcToCard.isOptional = false
        cardToDeckCards.inverseRelationship = dcToCard; dcToCard.inverseRelationship = cardToDeckCards
        card.properties.append(cardToDeckCards); deckCard.properties.append(dcToCard)
        model.entities = [deck, card, deckCard]
        return model
    }()

    private static func entity(_ name: String, _ type: NSManagedObject.Type) -> NSEntityDescription { let e = NSEntityDescription(); e.name = name; e.managedObjectClassName = NSStringFromClass(type); return e }
    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription { let a = NSAttributeDescription(); a.name = name; a.attributeType = type; a.isOptional = false; return a }
    private static func optional(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription { let a = attribute(name, type); a.isOptional = true; return a }

    static func save(_ context: NSManagedObjectContext) throws { if context.hasChanges { try context.save() } }
}
