import SwiftUI

struct ThemesView: View {
    @Environment(AppModel.self) private var appModel

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                    themeCard(theme, graph: CardGraphKind.at(index))
                }
            }
            .padding(16)
        }
        .moneyStalkerScreen()
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeCard(_ theme: AppTheme, graph: CardGraphKind) -> some View {
        let selected = appModel.settings.theme == theme
        let preview = theme.palette(for: .light)
        return Button {
            appModel.settings.theme = theme
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(colors: [preview.heroStart, preview.heroMid, preview.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    CardGraphWash(kind: graph, tint: Color.white)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.white)
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 96)
                Text(theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.moneyStalkerSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.moneyStalkerCard)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Color.moneyStalkerPrimary : Color.moneyStalkerBorder, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
