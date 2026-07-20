import Foundation

struct ScryfallCard: Decodable, Sendable {
    let id: String; let name: String; let manaCost: String?; let cmc: Double
    let typeLine: String; let oracleText: String?; let colors: [String]?
    let colorIdentity: [String]; let rarity: String?; let power: String?; let toughness: String?
    let imageUris: [String: String]?
    enum CodingKeys: String, CodingKey { case id, name, cmc, colors, rarity, power, toughness; case manaCost = "mana_cost"; case typeLine = "type_line"; case oracleText = "oracle_text"; case colorIdentity = "color_identity"; case imageUris = "image_uris" }
}

actor ScryfallClient {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func cards(named names: [String]) async throws -> (found: [String: ScryfallCard], missing: [String]) {
        var found: [String: ScryfallCard] = [:]
        var missing: [String] = []
        let uniqueNames = Array(Set(names))
        for start in stride(from: 0, to: uniqueNames.count, by: 75) {
            let chunk = Array(uniqueNames[start..<min(start + 75, uniqueNames.count)])
            var request = URLRequest(url: URL(string: "https://api.scryfall.com/cards/collection")!)
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("GraveyardTracker/1.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONEncoder().encode(CollectionRequest(identifiers: chunk.map { Identifier(name: $0) }))
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            let collection = try JSONDecoder().decode(CollectionResponse.self, from: data)
            collection.data.forEach { found[$0.name.lowercased()] = $0 }
            missing.append(contentsOf: collection.notFound.compactMap(\.name))
        }
        return (found, missing)
    }

    func card(named name: String) async throws -> ScryfallCard {
        var components = URLComponents(string: "https://api.scryfall.com/cards/named")!
        components.queryItems = [URLQueryItem(name: "fuzzy", value: name)]
        var request = URLRequest(url: components.url!); request.setValue("GraveyardTracker/1.0", forHTTPHeaderField: "User-Agent"); request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ImportError.notFound(name) }
        return try JSONDecoder().decode(ScryfallCard.self, from: data)
    }
}

private struct Identifier: Codable { let name: String }
private struct CollectionRequest: Encodable { let identifiers: [Identifier] }
private struct CollectionResponse: Decodable { let data: [ScryfallCard]; let notFound: [Identifier]; enum CodingKeys: String, CodingKey { case data; case notFound = "not_found" } }

enum ImportError: LocalizedError {
    case emptyDecklist, invalidLine(String), notFound(String)
    var errorDescription: String? {
        switch self { case .emptyDecklist: "Paste at least one card."; case .invalidLine(let line): "Could not parse: \(line)"; case .notFound(let name): "Scryfall could not find \(name)." }
    }
}
