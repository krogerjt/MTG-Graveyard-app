import SwiftUI
import UIKit

struct CardArtwork: View {
    @ObservedObject var card: CardEntity
    var body: some View {
        if let data = card.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.15))
                .overlay { Image(systemName: "photo").accessibilityLabel("Artwork unavailable. Reimport this deck to download images.") }
        }
    }
}
