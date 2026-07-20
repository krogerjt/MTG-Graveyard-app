import SwiftUI

struct StatsView: View {
    @ObservedObject var model: GameViewModel
    var body: some View { NavigationStack { List { Section { HStack { Text("Cards in graveyard"); Spacer(); Text("\(model.graveyard.count)").font(.title.bold()).monospacedDigit() } }; Section("Card types") { if model.typeCounts.isEmpty { Text("No cards in graveyard").foregroundStyle(.secondary) }; ForEach(model.typeCounts, id: \.0) { kind, count in HStack { Text(kind.rawValue); Spacer(); Text("\(count)").foregroundStyle(.secondary).monospacedDigit() } } }; Section("Delirium") { Label(model.deliriumActive ? "Active" : "Not active", systemImage: model.deliriumActive ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(model.deliriumActive ? .green : .secondary); Text("\(model.deliriumTypes.count) distinct card types in your graveyard; four are required.").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("Statistics") } }
}
