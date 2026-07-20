# MTG Graveyard Tracker

An iPhone-first SwiftUI companion for tracking a Commander deck's library, graveyard, and exile zones during play.

## Open and run

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) on macOS (`brew install xcodegen`).
2. Run `xcodegen generate` in this directory.
3. Open `GraveyardTracker.xcodeproj`, choose an iPhone simulator, and run.

The app targets iOS 17. No third-party runtime dependencies are required. Card data is fetched from Scryfall only during import and stored in Core Data for offline play.

## Included MVP

- Multiple local decks: import, rename, edit, and delete
- Fast paste-decklist import with per-card failure reporting
- Library → graveyard one-tap flow, contextual zone actions, and persisted sessions
- Graveyard search, sorting, card-type filters, statistics, and delirium status
- Card detail with cached remote artwork and full rules information
- Reset-game confirmation
- Unit tests for parsing and card-type detection

Moxfield URL import and the other future features in the product brief remain intentionally out of scope.
