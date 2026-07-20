import CoreData
import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    let deck: DeckEntity
    @Published var search = ""; @Published var sort: GraveyardSort = .newest; @Published var filter: CardKind?
    init(deck: DeckEntity) { self.deck = deck }

    var library: [DeckCardEntity] { deck.sortedCards.filter { $0.zone == .library } }
    var graveyard: [DeckCardEntity] {
        var result = deck.sortedCards.filter { $0.zone == .graveyard && (search.isEmpty || $0.card.name.localizedCaseInsensitiveContains(search)) && (filter == nil || $0.card.kinds.contains(filter!)) }
        switch sort { case .newest: result.sort { $0.zoneChangedAt > $1.zoneChangedAt }; case .alphabetical: result.sort { $0.card.name < $1.card.name }; case .manaValue: result.sort { $0.card.manaValue < $1.card.manaValue } }
        return result
    }
    var exile: [DeckCardEntity] { deck.sortedCards.filter { $0.zone == .exile } }
    var deliriumTypes: Set<CardKind> { Set(deck.cards.filter { $0.zone == .graveyard }.flatMap { $0.card.kinds }) }
    var deliriumActive: Bool { deliriumTypes.count >= 4 }
    var typeCounts: [(CardKind, Int)] { CardKind.allCases.compactMap { kind in let count = deck.cards.filter { $0.zone == .graveyard && $0.card.kinds.contains(kind) }.count; return count > 0 ? (kind, count) : nil } }

    func toggle(_ item: DeckCardEntity, context: NSManagedObjectContext) { move(item, to: item.zone == .graveyard ? .library : .graveyard, context: context) }
    func move(_ item: DeckCardEntity, to zone: Zone, context: NSManagedObjectContext) { objectWillChange.send(); item.zone = zone; deck.updatedDate = Date(); try? PersistenceController.save(context) }
    func reset(context: NSManagedObjectContext) { objectWillChange.send(); deck.cards.forEach { $0.zone = .library }; deck.updatedDate = Date(); try? PersistenceController.save(context) }
}
