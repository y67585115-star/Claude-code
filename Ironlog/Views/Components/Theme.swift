import SwiftUI

enum Theme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let surface = Color.white.opacity(0.06)
    static let surfaceRaised = Color.white.opacity(0.10)
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.32)
    static let pr = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let radius: CGFloat = 16
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }

    /// Dark, minimal list/form background used on every screen.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Full screen on iPhone/iPad, a large sheet on Mac.
    @ViewBuilder
    func workoutCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented) {
            content().frame(minWidth: 620, idealWidth: 720, minHeight: 680, idealHeight: 820)
        }
        #endif
    }

    /// Sheet sized sensibly on Mac.
    @ViewBuilder
    func macSheetSize(width: CGFloat = 480, height: CGFloat = 520) -> some View {
        #if os(macOS)
        frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }
}

struct PRBadge: View {
    var compact = false
    var body: some View {
        Label(compact ? "PR" : "New PR", systemImage: "trophy.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.pr, in: Capsule())
            .labelStyle(.titleAndIcon)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(Color.accentColor)
                }
                Text(title).font(.caption).foregroundStyle(Theme.secondary)
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(Theme.tertiary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .foregroundStyle(Theme.secondary)
    }
}
