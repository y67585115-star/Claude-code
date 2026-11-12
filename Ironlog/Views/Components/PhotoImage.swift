import SwiftUI
import SwiftData

/// Decodes stored photo data off the main thread.
struct PhotoImage: View {
    let photo: ProgressPhoto
    var thumbnail = true
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Theme.surface
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: photo.persistentModelID) {
            let data = thumbnail ? (photo.thumbnailData ?? photo.imageData) : photo.imageData
            let decoded = await ImageUtil.decode(data, maxPixel: thumbnail ? 480 : nil)
            withAnimation(.easeOut(duration: 0.15)) { image = decoded }
        }
    }
}
