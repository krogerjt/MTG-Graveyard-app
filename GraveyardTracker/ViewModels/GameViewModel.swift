import CoreData
import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    let deck: DeckEntity
    @Published var search = ""; @Published var sort: GraveyardSort = .newest; @Published var filter: CardKind?
    @Published var errorMessage: String?
    private var history: [[(DeckCardEntity, Zone, Date)]] = []
    var canUndo: Bool { !history.isEmpty }
    var graveyardCount: Int { deck.cards.filter { $0.zone == .graveyard }.count }
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
    func move(_ item: DeckCardEntity, to zone: Zone, context: NSManagedObjectContext) {
        guard item.zone != zone else { return }
        change([item], to: zone, context: context)
    }
    func reset(context: NSManagedObjectContext) { change(Array(deck.cards), to: .library, context: context) }
    private func change(_ items: [DeckCardEntity], to zone: Zone, context: NSManagedObjectContext) {
        let snapshot = items.map { ($0, $0.zone, $0.zoneChangedAt) }
        objectWillChange.send()
        items.forEach { $0.zone = zone }; deck.updatedDate = Date()
        do { try PersistenceController.save(context); history.append(snapshot) }
        catch { context.rollback(); errorMessage = "Could not save: \(error.localizedDescription)" }
    }
    func clearHistory() { history.removeAll(); objectWillChange.send() }
    func undo(context: NSManagedObjectContext) {
        guard let snapshot = history.last else { return }
        objectWillChange.send()
        for (item, zone, date) in snapshot where !item.isDeleted {
            item.zoneRaw = zone.rawValue; item.zoneChangedAt = date
        }
        deck.updatedDate = Date()
        do { try PersistenceController.save(context); history.removeLast() }
        catch { context.rollback(); errorMessage = "Could not undo: \(error.localizedDescription)" }
    }
}
