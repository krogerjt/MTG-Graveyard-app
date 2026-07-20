import Foundation

struct ParsedCard: Equatable { let quantity: Int; let name: String }

enum DecklistParser {
    static func parse(_ text: String) throws -> [ParsedCard] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("//") }
        guard !lines.isEmpty else { throw ImportError.emptyDecklist }
        return try lines.map { line in
            let clean = line.replacingOccurrences(of: #"\s*\[[^]]+\]\s*$"#, with: "", options: .regularExpression).replacingOccurrences(of: #"\s+\([^)]*\)\s*\d*\s*$"#, with: "", options: .regularExpression)
            let parts = clean.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let quantity = Int(parts[0]), quantity > 0 else { throw ImportError.invalidLine(line) }
            return ParsedCard(quantity: quantity, name: String(parts[1]).trimmingCharacters(in: .whitespaces))
        }
    }
}
