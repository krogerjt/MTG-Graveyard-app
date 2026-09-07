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
                } else if let error = persistence.storeError {
                    VStack(spacing: 16) {
                        Text("Could not open saved decks").font(.headline)
                        Text(error).font(.caption)
                        Text("Your saved files have not been deleted.")
                        Button("Retry") { persistence.loadStore() }
                    }.padding()
                } else { ProgressView("Opening decks…") }
            }
        }
    }
}
