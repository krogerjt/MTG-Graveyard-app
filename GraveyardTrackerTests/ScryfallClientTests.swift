import XCTest
@testable import GraveyardTracker

final class ScryfallClientTests: XCTestCase {
    private let fixture = #"{"id":"test","name":"Front // Back","cmc":2,"type_line":"Creature — Human // Creature — Werewolf","color_identity":["G"],"card_faces":[{"name":"Front","mana_cost":"{1}{G}","oracle_text":"Front rules","power":"2","toughness":"2","image_uris":{"normal":"https://example.com/front.jpg"}},{"name":"Back","oracle_text":"Back rules"}]}"#

    func testDoubleFacedCardUsesFaceArtworkAndBothRules() throws {
        let card = try JSONDecoder().decode(ScryfallCard.self, from: Data(fixture.utf8))
        XCTAssertEqual(card.displayImageURL, "https://example.com/front.jpg")
        XCTAssertEqual(card.displayRules, "Front\nFront rules\n\nBack\nBack rules")
        XCTAssertEqual(card.displayManaCost, "{1}{G}")
    }

    func testCollectionRetainsRequestedFaceName() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        let client = ScryfallClient(session: URLSession(configuration: configuration))
        let result = try await client.cards(named: ["Front", "Missing"])
        XCTAssertEqual(result.found["front"]?.name, "Front // Back")
        XCTAssertEqual(result.missing, ["Missing"])
    }
}

private final class FixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let data = Data(#"{"data":[{"id":"test","name":"Front // Back","cmc":2,"type_line":"Creature","color_identity":[],"card_faces":[{"name":"Front"},{"name":"Back"}]}],"not_found":[{"name":"Missing"}]}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
