import XCTest
@testable import GraveyardTracker

final class DecklistParserTests: XCTestCase {
    func testParsesQuantitiesAndNames() throws {
        XCTAssertEqual(try DecklistParser.parse("1 Sol Ring\n2 Island"), [ParsedCard(quantity: 1, name: "Sol Ring"), ParsedCard(quantity: 2, name: "Island")])
    }
    func testStripsCommonSetSuffixes() throws {
        XCTAssertEqual(try DecklistParser.parse("1 Sol Ring (CMM) 396"), [ParsedCard(quantity: 1, name: "Sol Ring")])
    }
    func testRejectsMalformedLine() { XCTAssertThrowsError(try DecklistParser.parse("Sol Ring")) }
    func testRejectsUnboundedQuantity() { XCTAssertThrowsError(try DecklistParser.parse("999999999 Island")) }
}

final class DuplicateDecklistLineTests: XCTestCase {
    func testKeepsRepeatedLinesSeparately() throws {
        XCTAssertEqual(try DecklistParser.parse("1 Forest\n1 Forest"), [ParsedCard(quantity: 1, name: "Forest"), ParsedCard(quantity: 1, name: "Forest")])
    }
}
