import SwiftUI

@main
struct GraveyardTrackerApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DeckListView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
