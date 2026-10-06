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

    func testCollectionPreservesTransportFailure() async throws {
        let client = makeClient()
        do {
            _ = try await client.cards(named: ["Transport Failure"])
            XCTFail("Expected the URLSession transport failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }

    func testCollectionReportsHTTPFailure() async throws {
        let client = makeClient()
        do {
            _ = try await client.cards(named: ["HTTP Failure"])
            XCTFail("Expected the HTTP failure")
        } catch let error as ImportError {
            guard case .httpFailure(503) = error else {
                return XCTFail("Unexpected import error: \\(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("HTTP 503"))
        }
    }

    func testIndividualLookupOnlyTreatsNotFoundHTTPAsMissingCard() async throws {
        let client = makeClient()
        do {
            _ = try await client.card(named: "Missing Card")
            XCTFail("Expected a missing-card error")
        } catch let error as ImportError {
            guard case .notFound("Missing Card") = error else {
                return XCTFail("Unexpected missing-card result: \\(error)")
            }
        }

        do {
            _ = try await client.card(named: "HTTP Failure")
            XCTFail("Expected the HTTP failure")
        } catch let error as ImportError {
            guard case .httpFailure(503) = error else {
                return XCTFail("A server error must not be reported as a missing card: \\(error)")
            }
        }
    }

    private func makeClient() -> ScryfallClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureProtocol.self]
        return ScryfallClient(session: URLSession(configuration: configuration))
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

final class FixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body = requestBody
        let lookupName = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "fuzzy" })?.value
        if lookupName == "Fallback Transport Failure" || body.contains("\"Transport Failure\"") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let statusCode = body.contains("\"HTTP Failure\"") || lookupName == "HTTP Failure" ? 503 : (lookupName == "Missing Card" ? 404 : 200)
        if statusCode != 200 {
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let data = Data(#"{"data":[{"id":"test","name":"Front // Back","cmc":2,"type_line":"Creature","color_identity":[],"card_faces":[{"name":"Front"},{"name":"Back"}]}],"not_found":[{"name":"Missing"}]}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private var requestBody: String {
        if let body = request.httpBody {
            return String(data: body, encoding: .utf8) ?? ""
        }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
