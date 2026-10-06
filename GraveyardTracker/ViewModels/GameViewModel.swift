import CoreData
import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    private struct DeckSnapshot {
        let sortedCards: [DeckCardEntity]
        let library: [DeckCardEntity]
        let graveyard: [DeckCardEntity]
        let exile: [DeckCardEntity]
        let deliriumTypes: Set<CardKind>
        let typeCounts: [(CardKind, Int)]
    }
    let deck: DeckEntity
    @Published var search = ""; @Published var sort: GraveyardSort = .newest; @Published var filter: CardKind?
    @Published var errorMessage: String?
    private var history: [[(DeckCardEntity, Zone, Date)]] = []
    private var cachedSnapshot: DeckSnapshot?
    private var contextObserver: NSObjectProtocol?
    var canUndo: Bool { !history.isEmpty }
    var graveyardCount: Int { snapshot.graveyard.count }
    init(deck: DeckEntity) {
        self.deck = deck
        if let context = deck.managedObjectContext {
            // Imports and other edits can replace the relationship outside this view model.
            // Invalidate derived data whenever this context processes managed-object changes.
            contextObserver = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextObjectsDidChange,
                object: context,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.invalidateSnapshot(notify: true) }
            }
        }
    }

    deinit {
        if let contextObserver {
            NotificationCenter.default.removeObserver(contextObserver)
        }
    }

    var allCards: [DeckCardEntity] { snapshot.sortedCards }
    var library: [DeckCardEntity] { snapshot.library }
    var graveyard: [DeckCardEntity] {
        var result = snapshot.graveyard.filter { (search.isEmpty || $0.card.name.localizedCaseInsensitiveContains(search)) && (filter == nil || $0.card.kinds.contains(filter!)) }
        switch sort { case .newest: result.sort { $0.zoneChangedAt > $1.zoneChangedAt }; case .alphabetical: result.sort { $0.card.name < $1.card.name }; case .manaValue: result.sort { $0.card.manaValue < $1.card.manaValue } }
        return result
    }
    var exile: [DeckCardEntity] { snapshot.exile }
    var deliriumTypes: Set<CardKind> { snapshot.deliriumTypes }
    var deliriumActive: Bool { deliriumTypes.count >= 4 }
    var typeCounts: [(CardKind, Int)] { snapshot.typeCounts }

    private var snapshot: DeckSnapshot {
        if let cachedSnapshot { return cachedSnapshot }
        let sortedCards = deck.cards.sorted { $0.card.name < $1.card.name }
        var library: [DeckCardEntity] = []
        var graveyard: [DeckCardEntity] = []
        var exile: [DeckCardEntity] = []
        var kindsByKind: [CardKind: Int] = [:]
        var deliriumTypes: Set<CardKind> = []
        for item in sortedCards {
            switch item.zone {
            case .library: library.append(item)
            case .graveyard:
                graveyard.append(item)
                for kind in item.card.kinds {
                    deliriumTypes.insert(kind)
                    kindsByKind[kind, default: 0] += 1
                }
            case .exile: exile.append(item)
            }
        }
        let snapshot = DeckSnapshot(
            sortedCards: sortedCards,
            library: library,
            graveyard: graveyard,
            exile: exile,
            deliriumTypes: deliriumTypes,
            typeCounts: CardKind.allCases.compactMap { kind in
                guard let count = kindsByKind[kind] else { return nil }
                return (kind, count)
            }
        )
        cachedSnapshot = snapshot
        return snapshot
    }

    private func invalidateSnapshot(notify: Bool) {
        cachedSnapshot = nil
        if notify { objectWillChange.send() }
    }

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
        invalidateSnapshot(notify: false)
        do { try PersistenceController.save(context); history.append(snapshot) }
        catch { context.rollback(); invalidateSnapshot(notify: false); errorMessage = "Could not save: \(error.localizedDescription)" }
    }
    func clearHistory() { history.removeAll(); objectWillChange.send() }
    func undo(context: NSManagedObjectContext) {
        guard let snapshot = history.last else { return }
        objectWillChange.send()
        for (item, zone, date) in snapshot where !item.isDeleted {
            item.zoneRaw = zone.rawValue; item.zoneChangedAt = date
        }
        deck.updatedDate = Date()
        invalidateSnapshot(notify: false)
        do { try PersistenceController.save(context); history.removeLast() }
        catch { context.rollback(); errorMessage = "Could not undo: \(error.localizedDescription)" }
    }
}
