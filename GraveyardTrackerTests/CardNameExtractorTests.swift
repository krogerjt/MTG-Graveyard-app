import CoreGraphics
import XCTest
@testable import GraveyardTracker

final class CardNameExtractorTests: XCTestCase {
    func testPicksTopmostLargeLineAsName() {
        let lines = [
            ScannedText(text: "Basic Land — Forest", frame: CGRect(x: 20, y: 300, width: 200, height: 18)),
            ScannedText(text: "Forest", frame: CGRect(x: 20, y: 40, width: 90, height: 20)),
            ScannedText(text: "Add {G}.", frame: CGRect(x: 30, y: 360, width: 60, height: 12)),
        ]
        XCTAssertEqual(CardNameExtractor.bestCandidate(from: lines), "Forest")
    }

    func testIgnoresSmallTextAboveTheCard() {
        let lines = [
            ScannedText(text: "booster box", frame: CGRect(x: 0, y: 5, width: 60, height: 8)),
            ScannedText(text: "Llanowar Elves G", frame: CGRect(x: 20, y: 40, width: 160, height: 20)),
        ]
        XCTAssertEqual(CardNameExtractor.bestCandidate(from: lines), "Llanowar Elves")
    }

    func testStripsManaCostFromName() {
        XCTAssertEqual(CardNameExtractor.cleanedName("Sol Ring 1"), "Sol Ring")
        XCTAssertEqual(CardNameExtractor.cleanedName("Counterspell {U}{U}"), "Counterspell")
        XCTAssertEqual(CardNameExtractor.cleanedName("Lightning Bolt R"), "Lightning Bolt")
    }

    func testRejectsTypeLinesAndNumbers() {
        XCTAssertNil(CardNameExtractor.cleanedName("Creature — Elf Druid"))
        XCTAssertNil(CardNameExtractor.cleanedName("Legendary Artifact"))
        XCTAssertNil(CardNameExtractor.cleanedName("1/1"))
        XCTAssertNil(CardNameExtractor.bestCandidate(from: []))
    }

    func testKeepsNamesThatStartWithTypeWords() {
        XCTAssertEqual(CardNameExtractor.cleanedName("Land Tax W"), "Land Tax")
    }
}
