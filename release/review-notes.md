# App Review Notes

Paste this into App Store Connect → App Review Information → Notes. It answers the Guideline 2.1 information request for the first submission.

**Purpose and audience.** Graveyard Tracker is a companion utility for Magic: The Gathering players, especially Commander players. During a game, many cards care about what is in your graveyard (for example "delirium": four or more card types there), and keeping that in your head or on paper is error-prone. The app lets a player import a decklist, tap cards as they move between library, graveyard and exile, and see the graveyard sorted, searched and filtered, with a delirium indicator and simple statistics. It is a free, offline-capable tool with no accounts. Target audience: Magic players aged 13 and over.

**How to use it (no sign-in, no demo account).**
1. Launch the app. The deck list is empty. Tap the + (Import) button.
2. Enter any deck name and paste this sample decklist (one card per line), then tap Import. An internet connection is needed only for this step.
```
1 Sol Ring
1 Arcane Signet
1 Lightning Bolt
1 Counterspell
1 Divination
1 Rhystic Study
1 Eternal Witness
1 Birds of Paradise
1 Cultivate
1 Command Tower
4 Forest
4 Island
```
3. Tap the deck. On the Cards tab, tap a card to move it to the graveyard (tap again to return it); touch and hold a card for more options such as Exile and Undo.
4. Open the Graveyard tab to see the cards, the Delirium indicator, and the search, sort and type controls. Open the Stats tab for counts by card type. Tap a card's info button for its details.

**External services and platforms.** Scryfall (api.scryfall.com), a free public Magic card database, provides card data and card images over HTTPS. Only card names from the player's decklist are sent. The app has no accounts, authentication service, payment processor, analytics, advertising, crash-reporting SDK or AI service. Decks, card data and downloaded images are stored on the device only (Core Data).

**Regional differences.** None. The app has the same features and content in every region and does not vary by location. An internet connection is required only to import a deck; after that it works offline.

**Third-party material and authorization.** Magic: The Gathering card names, text and artwork belong to Wizards of the Coast. The app is unofficial fan content made under Wizards of the Coast's published Fan Content Policy (https://company.wizards.com/en/legal/fancontentpolicy): it is free, has no ads, subscriptions or in-app purchases, uses no Wizards logos, and states on its App Store page and support page that it is not affiliated with or endorsed by Wizards of the Coast. Card data and images are provided by Scryfall under its API terms (https://scryfall.com/docs/api), which allow them to be used for Magic software and community content under that policy. We do not hold a separate license; we rely on the Fan Content Policy. Support: https://krogerjt.github.io/MTG-Graveyard-app/support. Privacy policy: https://krogerjt.github.io/MTG-Graveyard-app/privacy.

**Screen recording.** A screen recording captured on a physical device is attached in the App Store Connect reply.
