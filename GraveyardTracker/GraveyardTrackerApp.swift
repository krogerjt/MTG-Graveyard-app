import SwiftUI

@main
struct GraveyardTrackerApp: App {
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if persistence.isReady {
                    DeckListView()
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                } else if persistence.storeError != nil || persistence.isRetrying {
                    StoreUnavailableView(error: persistence.storeError, isRetrying: persistence.isRetrying) {
                        persistence.loadStore()
                    }





                } else {
                    ProgressView("Opening saved decks…")
                        .accessibilityLabel("Opening saved decks")
                }
            }
        }
    }
}
