import Foundation

struct ScryfallCard: Decodable, Sendable {
    let id: String; let name: String; let manaCost: String?; let cmc: Double
    let typeLine: String; let oracleText: String?; let colors: [String]?
    let colorIdentity: [String]; let rarity: String?; let power: String?; let toughness: String?
    let imageUris: [String: String]?
    let cardFaces: [Face]?
    struct Face: Decodable, Sendable {
        let name: String
        let manaCost: String?
        let oracleText: String?
        let imageUris: [String: String]?
        let power: String?
        let toughness: String?
        enum CodingKeys: String, CodingKey { case name, power, toughness; case manaCost = "mana_cost", oracleText = "oracle_text", imageUris = "image_uris" }
    }
    var displayImageURL: String? { imageUris?["normal"] ?? cardFaces?.first?.imageUris?["normal"] }
    var displayRules: String? { oracleText ?? cardFaces?.map { "\($0.name)\n\($0.oracleText ?? "")" }.joined(separator: "\n\n") }
    var displayManaCost: String? { manaCost ?? cardFaces?.compactMap(\.manaCost).joined(separator: " // ") }
    enum CodingKeys: String, CodingKey { case id, name, cmc, colors, rarity, power, toughness; case manaCost = "mana_cost"; case typeLine = "type_line"; case oracleText = "oracle_text"; case colorIdentity = "color_identity"; case imageUris = "image_uris"; case cardFaces = "card_faces" }
}

protocol CardLookupService: Sendable {
    func cards(named names: [String]) async throws -> (found: [String: ScryfallCard], missing: [String])
    func card(named name: String) async throws -> ScryfallCard
}

protocol ArtworkService: Sendable {
    func artwork(at url: String) async throws -> Data
}

actor ScryfallClient: CardLookupService, ArtworkService {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func cards(named names: [String]) async throws -> (found: [String: ScryfallCard], missing: [String]) {
        var found: [String: ScryfallCard] = [:]
        var missing: [String] = []
        let uniqueNames = Array(Set(names))
        for start in stride(from: 0, to: uniqueNames.count, by: 75) {
            if start > 0 { try await Task.sleep(for: .milliseconds(100)) }
            let chunk = Array(uniqueNames[start..<min(start + 75, uniqueNames.count)])
            var request = URLRequest(url: URL(string: "https://api.scryfall.com/cards/collection")!)
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("GraveyardTracker/1.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONEncoder().encode(CollectionRequest(identifiers: chunk.map { Identifier(name: $0) }))
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard http.statusCode == 200 else { throw ImportError.httpFailure(http.statusCode) }
            let collection = try JSONDecoder().decode(CollectionResponse.self, from: data)
            for requested in chunk {
                if let card = collection.data.first(where: { $0.name.caseInsensitiveCompare(requested) == .orderedSame || $0.cardFaces?.contains(where: { $0.name.caseInsensitiveCompare(requested) == .orderedSame }) == true }) {
                    found[requested.lowercased()] = card
                } else {
                    missing.append(requested)
                }
            }
        }
        return (found, missing)
    }

    func card(named name: String) async throws -> ScryfallCard {
        try await Task.sleep(for: .milliseconds(100))
        var components = URLComponents(string: "https://api.scryfall.com/cards/named")!
        components.queryItems = [URLQueryItem(name: "fuzzy", value: name)]
        var request = URLRequest(url: components.url!); request.setValue("GraveyardTracker/1.0", forHTTPHeaderField: "User-Agent"); request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            if http.statusCode == 404 { throw ImportError.notFound(name) }
            throw ImportError.httpFailure(http.statusCode)
        }
        return try JSONDecoder().decode(ScryfallCard.self, from: data)
    }

    func artwork(at url: String) async throws -> Data {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.statusCode == 200 else { throw ImportError.httpFailure(response.statusCode) }
        guard
              response.mimeType?.hasPrefix("image/") == true else { throw URLError(.badServerResponse) }
        return data
    }
}

private struct Identifier: Codable { let name: String }
private struct CollectionRequest: Encodable { let identifiers: [Identifier] }
private struct CollectionResponse: Decodable { let data: [ScryfallCard]; let notFound: [Identifier]; enum CodingKeys: String, CodingKey { case data; case notFound = "not_found" } }

enum ImportError: LocalizedError {
    case emptyDecklist, invalidLine(String), notFound(String), httpFailure(Int)
    var errorDescription: String? {
        switch self { case .emptyDecklist: "Paste at least one card."; case .invalidLine(let line): "Could not parse: \(line)"; case .notFound(let name): "Scryfall could not find \(name)."; case .httpFailure(let statusCode): "Scryfall returned a server error (HTTP \(statusCode)). Please try again." }
    }
}
