import XCTest

/// Captures the App Store screenshots.
///
/// It skips itself unless the host sets CAPTURE_SCREENSHOTS=1 (xcodebuild forwards
/// TEST_RUNNER_CAPTURE_SCREENSHOTS=1), so ordinary test runs are unaffected. Importing the sample deck
/// needs an internet connection because card data comes from Scryfall.
final class ScreenshotTests: XCTestCase {
    private let deckName = "Graveyard Recursion"
    private let commanderName = "Muldrotha, the Gravetide"
    private let decklist = """
    1 Sol Ring
    1 Arcane Signet
    1 Lightning Bolt
    1 Counterspell
    1 Divination
    1 Rhystic Study
    1 Eternal Witness
    1 Mulldrifter
    1 Birds of Paradise
    1 Llanowar Elves
    1 Cultivate
    1 Swords to Plowshares
    1 Reanimate
    1 Faithless Looting
    1 Cyclonic Rift
    1 Command Tower
    1 Evolving Wilds
    6 Forest
    4 Island
    """

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOTS"] == "1",
            "Set TEST_RUNNER_CAPTURE_SCREENSHOTS=1 to capture App Store screenshots."
        )
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        removeExistingDecks(in: app)
        try importSampleDeck(in: app)
        capture("01-decks", pause: 1)

        app.staticTexts[deckName].firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Cards"].waitForExistence(timeout: 20), "The game screen did not open.")
        capture("02-cards", pause: 3)

        moveCardsToGraveyard(in: app, count: 6)
        capture("03-cards-in-play", pause: 1)

        selectTab("Stats", in: app)
        capture("05-stats", pause: 1)

        selectTab("Graveyard", in: app)
        capture("04-graveyard", pause: 1)

        selectTab("Cards", in: app)
        let details = app.buttons["Card details"].firstMatch
        if details.waitForExistence(timeout: 5) {
            details.tap()
            capture("06-card-details", pause: 2)
        }
    }

    @MainActor
    private func importSampleDeck(in app: XCUIApplication) throws {
        let importButton = app.navigationBars["Your Decks"].buttons["Import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 30), "The deck list did not appear.")
        importButton.tap()

        let nameField = app.textFields["Deck name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(deckName)

        let commanderField = app.textFields["Commander (optional)"]
        commanderField.tap()
        commanderField.typeText(commanderName)

        let editor = app.textViews.firstMatch
        editor.tap()
        editor.typeText(decklist)

        app.navigationBars["Import Deck"].buttons["Import"].tap()
        XCTAssertTrue(app.staticTexts[deckName].firstMatch.waitForExistence(timeout: 180), "The deck did not import. Check the internet connection.")
    }

    /// Selects a tab and fails with a description of the screen if the app ends up somewhere unexpected.
    @MainActor
    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "The \(title) tab was not found.")
        // Tap by coordinate at the centre of the tab button, as a finger would.
        let frame = tab.frame
        let window = app.windows.firstMatch.frame
        app.coordinate(withNormalizedOffset: CGVector(dx: frame.midX / window.width, dy: frame.midY / window.height)).tap()
        sleep(2)
        if app.navigationBars["Your Decks"].exists {
            XCTFail("Selecting the \(title) tab returned to the deck list. Screen: \(app.debugDescription.prefix(1200))")
        }
    }

    /// The simulator keeps app data between runs, so start from an empty deck list.
    @MainActor
    private func removeExistingDecks(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Your Decks"].waitForExistence(timeout: 30), "The deck list did not appear.")
        var attempts = 0
        while app.cells.count > 0 && attempts < 20 {
            app.cells.firstMatch.swipeLeft()
            let delete = app.buttons["Delete"]
            guard delete.waitForExistence(timeout: 3) else { break }
            delete.tap()
            sleep(1)
            attempts += 1
        }
    }

    /// Tapping a card row toggles it into the graveyard. Cards are chosen by name so the screenshots show a mix of card types.
    @MainActor
    private func moveCardsToGraveyard(in app: XCUIApplication, count: Int) {
        let names = ["Arcane Signet", "Birds of Paradise", "Command Tower", "Counterspell", "Cultivate", "Cyclonic Rift", "Divination", "Eternal Witness", "Evolving Wilds", "Faithless Looting"]
        var tapped = Set<String>()
        var passes = 0
        while tapped.count < count && passes < 4 {
            for name in names where tapped.count < count && !tapped.contains(name) {
                let label = app.staticTexts[name].firstMatch
                if label.exists && label.isHittable {
                    label.tap()
                    tapped.insert(name)
                    sleep(1)
                }
            }
            if tapped.count < count {
                app.swipeUp()
                passes += 1
            }
        }
        XCTAssertGreaterThanOrEqual(tapped.count, 4, "Fewer than four cards could be moved to the graveyard.")
    }

    private func capture(_ name: String, pause: UInt32) {
        sleep(pause)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
