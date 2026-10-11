# Reply to App Review: Guideline 2.1, Information Needed

Reply in App Store Connect (Resolution Center → Reply) and also paste the same details into App Review Information → Notes (the text is in `release/review-notes.md`).

## Before you reply (only you can do these)

1. **Test the submitted build on your own iPhone.** Apple asks that apps are tested on a physical device, and this build has not been run on one yet. The build is already in TestFlight: App Store Connect → your app → TestFlight → Internal Testing → add yourself as an internal tester → install the TestFlight app on the iPhone → install build 1.0 (1). Check the full flow below, including a fresh install with no network (import should show a clear error, not crash) and then with network.
2. **Record the screen on the iPhone** (add "Screen Recording" in Settings → Control Center, then swipe down and tap the record button). Start the recording *before* launching the app, so it begins with the launch. Suggested flow, about 1 to 2 minutes:
   - Launch the app (from the home screen), show the empty deck list.
   - Tap + , enter a deck name and paste the sample decklist from the notes, tap Import, wait for it to finish.
   - Open the deck. On the Cards tab tap several cards to move them to the graveyard; touch and hold one to show the menu.
   - Open the Graveyard tab: show the Delirium indicator, then use search, the sort menu and the type filter.
   - Open the Stats tab, then go back and open a card's details.
   - Show that deleting a deck works (swipe a deck in the deck list and tap Delete).
   The app has no accounts, no user-generated content shared with others, and no paid features, so there are no registration, deletion-of-account, reporting or purchase flows to show. Say so in the reply.
3. Make sure the device is on the latest iOS. Trim nothing important; keep the recording under the upload size limit (compress if needed).

## Message to paste into the reply

Thank you for the review. Here is the information requested.

1. **Screen recording:** attached, captured on a physical iPhone, beginning with launching the app and showing the typical flow (importing a deck, moving cards between zones, the graveyard, stats, deleting a deck). The app has no account registration, login or account deletion, no user-generated content that is shared with other users (so no reporting or blocking is needed), and no paid content or features.

2. **Purpose and target audience:** Graveyard Tracker is a companion utility for Magic: The Gathering players, especially Commander players. Many cards care about what is in a player's graveyard (for example "delirium", which needs four or more card types there), and tracking that mentally or on paper is error-prone during a game. The app lets a player import a decklist, tap cards as they move between library, graveyard and exile, and view the graveyard with search, sorting, type filtering, a delirium indicator and simple statistics. Target audience: Magic players aged 13 and over. It is free.

3. **Setup and access:** No sign-in or demo account is needed. Tap + on the deck list, enter any deck name, paste the sample decklist from the Notes field, and tap Import (internet required for this step only). Open the deck and tap cards to move them to the graveyard; use the Graveyard and Stats tabs.

4. **External services:** Scryfall (api.scryfall.com) provides card data and card images over HTTPS; only card names from the player's decklist are sent. There is no authentication service, payment processor, analytics, advertising, crash-reporting SDK or AI service. All decks and downloaded images are stored on the device.

5. **Regional differences:** None. The app has the same features and content in every region. An internet connection is needed only to import a deck.

6. **Protected third-party material:** Magic: The Gathering card names, text and artwork are the property of Wizards of the Coast. The app is unofficial fan content made under Wizards of the Coast's Fan Content Policy (https://company.wizards.com/en/legal/fancontentpolicy). It is free, has no advertising, subscriptions or in-app purchases, uses no Wizards logos, and states that it is not affiliated with or endorsed by Wizards of the Coast on its App Store page and support page (https://krogerjt.github.io/MTG-Graveyard-app/support). Card data and images come from Scryfall, whose API terms (https://scryfall.com/docs/api) allow them to be used for Magic software and community content under that policy. We do not hold a separate license and rely on the Fan Content Policy. Our privacy policy is at https://krogerjt.github.io/MTG-Graveyard-app/privacy.

## Things to double-check before sending (decisions that are yours)

- **Is every statement true for you?** Especially "free, no ads, no in-app purchases" and "we do not hold a separate license". The Fan Content Policy requires fan content to stay free for the community, so adding purchases or a paywall later would conflict with it.
- **Disclaimer wording.** The policy gives template wording for the required notice (unofficial, not approved or endorsed, portions are Wizards' property, with the Wizards copyright line). The notice on your listing and support page is a paraphrase. Compare it with the template on the policy page and use their wording if it differs. Consider also showing it inside the app (for example an About screen), which would need a new build.
- **Trademark use.** The listing description names "Magic: The Gathering" to say what the app is for. The policy restricts using Wizards' logos and trademarks without permission, so check that this plain-text reference is acceptable to you.
- **Scryfall's rules:** no Scryfall logos or implied endorsement, and no paywalling of its data. Its API also expects a User-Agent and an Accept header on every request; the app sends a User-Agent, and URLSession adds a default Accept header, but confirm this if Scryfall ever returns errors.
