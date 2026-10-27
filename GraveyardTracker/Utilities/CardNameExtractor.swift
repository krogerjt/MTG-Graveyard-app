import CoreGraphics
import Foundation

/// A line of text recognized by the camera, with its frame in view coordinates (y grows downward).
struct ScannedText: Equatable { let text: String; let frame: CGRect }

/// Picks the most likely card name out of on-device text recognition results.
/// It never talks to Scryfall: the name is only cleaned up and offered to the user.
enum CardNameExtractor {
    private static let typeWords: Set<String> = ["artifact", "basic", "battle", "creature", "enchantment", "instant", "kindred", "land", "legendary", "planeswalker", "snow", "sorcery", "token", "tribal", "world"]

    /// The card name sits at the top of the card in the largest print, so prefer the topmost
    /// line among the tallest plausible lines.
    static func bestCandidate(from lines: [ScannedText]) -> String? {
        let plausible = lines.compactMap { line in cleanedName(line.text).map { (name: $0, frame: line.frame) } }
        guard let tallest = plausible.map(\.frame.height).max() else { return nil }
        return plausible
            .filter { $0.frame.height >= tallest * 0.75 }
            .min { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }?
            .name
    }

    /// Strips mana costs and stray symbols from a recognized line, or returns nil when the
    /// line does not look like a card name (type lines, numbers, rules text fragments).
    static func cleanedName(_ text: String) -> String? {
        var name = text.replacingOccurrences(of: #"\{[^}]*\}"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        // OCR reads a mana cost such as "{1}{G}{G}" as trailing tokens like "1GG" or "2 U".
        name = name.replacingOccurrences(of: #"(\s+[0-9WUBRGCX/]+)+$"#, with: "", options: .regularExpression)
        name = name.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard name.count >= 2, name.count <= 60 else { return nil }
        guard !name.contains("—"), !name.contains(" - "), !name.contains(" -"), !name.contains("- ") else { return nil }
        let words = name.lowercased().split(separator: " ").map(String.init)
        guard !words.allSatisfy(typeWords.contains) else { return nil }
        let letters = name.unicodeScalars.filter(CharacterSet.letters.contains).count
        let nonSpaces = name.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) }.count
        guard letters >= 2, Double(letters) / Double(max(nonSpaces, 1)) >= 0.75 else { return nil }
        return name
    }
}
