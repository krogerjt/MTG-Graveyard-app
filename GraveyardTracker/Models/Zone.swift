import Foundation

enum Zone: String, CaseIterable, Codable {
    case library, graveyard, exile

    var title: String { rawValue.capitalized }
}

enum GraveyardSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case alphabetical = "Name"
    case manaValue = "Mana value"
    var id: Self { self }
}

enum CardKind: String, CaseIterable, Identifiable {
    case creature = "Creature", instant = "Instant", sorcery = "Sorcery"
    case artifact = "Artifact", enchantment = "Enchantment", land = "Land"
    case planeswalker = "Planeswalker", battle = "Battle", tribal = "Tribal"
    var id: Self { self }
}
