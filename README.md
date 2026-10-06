# MTG Graveyard Tracker

An iPhone-first SwiftUI companion for tracking a Commander deck's library, graveyard, and exile zones during play.

## Open and run

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) on macOS (`brew install xcodegen`).
2. Run `xcodegen generate` in this directory.
3. Open `GraveyardTracker.xcodeproj`, choose an iPhone simulator, and run.

The app targets iOS 17. No third-party runtime dependencies are required. Card data is fetched from Scryfall only during import and stored in Core Data for offline play.

## Implemented features

- Multiple local decks: import, rename, edit, and delete
- Fast paste-decklist import with per-card failure reporting
- Library → graveyard one-tap flow, contextual zone actions, and persisted sessions
- Graveyard search, sorting, card-type filters, statistics, and delirium status
- Card detail with cached remote artwork and full rules information
- Reset-game confirmation
- Undo for zone changes and resets during the current game screen session
- Edit deck contents with an explicit warning that saving resets the game
- Unit tests for parsing and card-type detection

Moxfield URL import and the other future features in the product brief remain intentionally out of scope.

## Validation and limitations

Windows checks cover file metadata, Git whitespace checks, and source review. XcodeGen project generation, the iOS Simulator build, and the Swift test suite have passed (11 tests, 0 failures). Manual device checks, import time, and scrolling performance have not been measured.

New imports download primary artwork into Core Data before saving, so imported images are available offline. Artwork download failure prevents the import from being saved. Double-faced cards show the front image and rules for both faces; there is no back-image toggle yet. Importing artwork can exceed the original ten-second target. Previously imported decks need to be reimported to populate artwork.

On the Mac, verify importing a deck, airplane-mode relaunch, library/graveyard/exile transitions, filtered totals, undo/reset, editing, and restart persistence. Include double-faced cards and Kindred cards. Test a failed network request and an unavailable persistent store. The app icon uses a custom 1024×1024 graveyard-and-cards design.
