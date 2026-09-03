import SwiftUI
import UIKit

/// Head-and-shoulders crop for a Play tile. Loads via `PlayerHeadshotStore` (cached).
struct PlayerHeadshotView: View {
    let name: String
    let leagueTag: String
    let propDescription: String

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    JuicdTheme.leaguePillColor(tag: leagueTag).opacity(0.45),
                    JuicdTheme.card
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.18)
                    .offset(y: 14)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
                    .offset(y: 6)
            }
            LinearGradient(
                colors: [.clear, JuicdTheme.card.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 36)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipped()
        .task(id: PlayerHeadshotLookup.cacheKey(name: name, leagueTag: leagueTag)) {
            let data = await PlayerHeadshotStore.shared.imageData(
                name: name,
                leagueTag: leagueTag,
                propDescription: propDescription
            )
            if let data, let ui = UIImage(data: data) {
                image = ui
            }
        }
    }
}
