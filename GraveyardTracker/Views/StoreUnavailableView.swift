import SwiftUI

struct StoreUnavailableView: View {
    let error: String?
    let isRetrying: Bool
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("Saved decks are unavailable")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)

                Text("Graveyard Tracker couldn’t open your saved decks.")
                    .font(.body)

                Label {
                    Text("Retrying won’t delete your decks.")
                } icon: {
                    Image(systemName: "info.circle")
                        .accessibilityHidden(true)
                }
                .font(.body)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What you can try")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    Label("Retry opening your decks.", systemImage: "arrow.clockwise")
                    Label("If the problem continues, close and reopen the app.", systemImage: "power")
                }
                .font(.body)

                if let error {
                    DisclosureGroup("Technical details") {
                        Text(error)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }

                Button {
                    // The controller also refuses overlapping loads; this keeps
                    // a fast second tap from reaching it at all.
                    guard !isRetrying else { return }
                    retry()
                } label: {
                    HStack(spacing: 10) {
                        if isRetrying {
                            ProgressView()
                                .accessibilityHidden(true)
                            Text("Retrying…")
                        } else {
                            Text("Retry")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)
                .accessibilityLabel(isRetrying ? "Retrying to open saved decks" : "Retry opening saved decks")
                .accessibilityHint(isRetrying ? "Please wait while the saved decks are reopened." : "Attempts to open your saved decks again.")
                .accessibilityAddTraits(isRetrying ? .updatesFrequently : [])
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: isRetrying) { _, nowRetrying in
            if nowRetrying {
                UIAccessibility.post(notification: .announcement, argument: "Retrying to open saved decks")
            }
        }
    }
}
