//
//  BacgroundApp.swift
//  MoneyStalker
//

import SwiftUI

enum MoneyStalkerMeshStyle {
    case screen
    case card
    case hero
}

enum CardGraphKind: Int, CaseIterable {
    case line, bars, area, ring, dots, columns, wave, spark

    static func at(_ index: Int) -> CardGraphKind {
        let kinds = allCases
        return kinds[((index % kinds.count) + kinds.count) % kinds.count]
    }
}

struct MoneyStalkerMesh: View {
    var style: MoneyStalkerMeshStyle = .card
    var graph: CardGraphKind? = .line
    var splash: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
            if style == .card, splash {
                splashImage
            } else if style == .card, let graph {
                CardGraphWash(kind: graph, tint: ThemeCenter.palette.primary)
            }
        }
    }

    private var splashImage: some View {
        let palette = ThemeCenter.palette
        let wash: [Color] = colorScheme == .dark
            ? [palette.card.opacity(0.78), palette.heroMid.opacity(0.55), palette.primary.opacity(0.5)]
            : [palette.heroStart.opacity(0.2), palette.heroMid.opacity(0.16), palette.primary.opacity(0.24)]
        return Color.clear
            .overlay {
                Image("CardSplash")
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(colors: wash, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var start: UnitPoint {
        switch style {
        case .screen: .top
        case .card, .hero: .topLeading
        }
    }

    private var end: UnitPoint {
        switch style {
        case .screen: .bottom
        case .card, .hero: .bottomTrailing
        }
    }

    private var colors: [Color] {
        switch style {
        case .screen: screenColors
        case .card: cardColors
        case .hero: heroColors
        }
    }

    private var screenColors: [Color] {
        [ThemeCenter.palette.background, ThemeCenter.palette.backgroundEnd]
    }

    private var cardColors: [Color] {
        let palette = ThemeCenter.palette
        return [palette.card, palette.cardEnd, palette.primary.opacity(0.16)]
    }

    private var heroColors: [Color] {
        [ThemeCenter.palette.heroStart, ThemeCenter.palette.heroMid, ThemeCenter.palette.heroEnd]
    }
}

struct CardGraphWash: View {
    var kind: CardGraphKind
    var tint: Color
    private let ink = 0.1

    var body: some View {
        GeometryReader { geo in
            let mark = tint.opacity(ink)
            switch kind {
            case .line:
                curve(in: geo.size, samples: [0.72, 0.58, 0.66, 0.42, 0.5, 0.3, 0.38])
                    .stroke(mark, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            case .bars:
                bars(in: geo.size, ratios: [0.24, 0.42, 0.3, 0.56, 0.36, 0.62], widthRatio: 0.03)
            case .area:
                area(in: geo.size, samples: [0.7, 0.5, 0.58, 0.36, 0.44, 0.28])
                    .fill(mark)
            case .ring:
                ring(in: geo.size)
                    .stroke(mark, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
            case .dots:
                dots(in: geo.size)
            case .columns:
                bars(in: geo.size, ratios: [0.34, 0.62, 0.46, 0.74], widthRatio: 0.07)
            case .wave:
                curve(in: geo.size, samples: [0.55, 0.4, 0.62, 0.36, 0.58, 0.42, 0.6, 0.38])
                    .stroke(mark, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                curve(in: geo.size, samples: [0.7, 0.55, 0.76, 0.5, 0.72, 0.56, 0.74, 0.52])
                    .stroke(mark, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            case .spark:
                curve(in: geo.size, samples: [0.8, 0.62, 0.7, 0.4, 0.48, 0.26])
                    .stroke(mark, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                bars(in: geo.size, ratios: [0.16, 0.28, 0.2, 0.34], widthRatio: 0.025)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func curve(in size: CGSize, samples: [CGFloat]) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }
        let step = size.width / CGFloat(samples.count - 1)
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: CGFloat(index) * step, y: size.height * sample)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func area(in size: CGSize, samples: [CGFloat]) -> Path {
        var path = curve(in: size, samples: samples)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func ring(in size: CGSize) -> Path {
        let side = min(size.width, size.height) * 0.72
        let rect = CGRect(x: size.width - side * 0.72, y: size.height * 0.08, width: side, height: side)
        return Path(ellipseIn: rect)
    }

    private func dots(in size: CGSize) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(0.15, 0.7), (0.28, 0.48), (0.4, 0.62), (0.55, 0.36), (0.68, 0.5), (0.82, 0.28), (0.9, 0.42)]
        return ZStack {
            ForEach(Array(spots.enumerated()), id: \.offset) { _, spot in
                Circle()
                    .fill(tint.opacity(ink))
                    .frame(width: 8, height: 8)
                    .position(x: size.width * spot.0, y: size.height * spot.1)
            }
        }
    }

    private func bars(in size: CGSize, ratios: [CGFloat], widthRatio: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: max(4, size.width * 0.02)) {
            ForEach(Array(ratios.enumerated()), id: \.offset) { _, ratio in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint.opacity(ink))
                    .frame(width: max(6, size.width * widthRatio), height: max(8, size.height * ratio))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(10)
    }
}

struct BacgroundApp: View {
    var body: some View {
        MoneyStalkerMesh(style: .screen)
            .ignoresSafeArea()
    }
}

#Preview {
    BacgroundApp()
}
