import SwiftUI

struct ThemePalette {
    var primary: Color
    var background: Color
    var backgroundEnd: Color
    var card: Color
    var cardEnd: Color
    var secondary: Color
    var income: Color
    var expense: Color
    var slate: Color
    var border: Color
    var warning: Color
    var heroStart: Color
    var heroMid: Color
    var heroEnd: Color
    var onHero: Color
}

enum ThemeCenter {
    static var palette = AppTheme.glacier.palette(for: .light)

    static func apply(_ theme: AppTheme, _ scheme: ColorScheme) {
        palette = theme.palette(for: scheme)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case glacier
    case midnight
    case lagoon
    case aurora
    case sunset
    case orchid
    case blossom
    case amber
    case harbor
    case graphite
    case cedar
    case sage
    case tide
    case plum
    case dune
    case citrus
    case azure
    case ruby
    case copper
    case iris

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glacier: "Glacier"
        case .midnight: "Midnight"
        case .lagoon: "Lagoon"
        case .aurora: "Aurora"
        case .sunset: "Sunset"
        case .orchid: "Orchid"
        case .blossom: "Blossom"
        case .amber: "Amber"
        case .harbor: "Harbor"
        case .graphite: "Graphite"
        case .cedar: "Cedar"
        case .sage: "Sage"
        case .tide: "Tide"
        case .plum: "Plum"
        case .dune: "Dune"
        case .citrus: "Citrus"
        case .azure: "Azure"
        case .ruby: "Ruby"
        case .copper: "Copper"
        case .iris: "Iris"
        }
    }

    func palette(for scheme: ColorScheme) -> ThemePalette {
        scheme == .dark ? dark : light
    }

    private var light: ThemePalette {
        switch self {
        case .glacier:
            return make(primary: "1877F2", background: "FFFFFF", backgroundEnd: "BFF2F7", card: "FFFFFF", cardEnd: "D1F5FA", secondary: "050505", slate: "65676B", border: "CED1D4", heroStart: "1877F2", heroMid: "29AEEB", heroEnd: "0C4AA6")
        case .midnight:
            return make(primary: "4C3BCF", background: "F7F5FF", backgroundEnd: "E4E0FF", card: "FFFFFF", cardEnd: "EFEAFF", secondary: "161226", slate: "5C5670", border: "D5D0E6", heroStart: "3D2DB5", heroMid: "6E63F5", heroEnd: "241A78")
        case .lagoon:
            return make(primary: "0E8A7A", background: "F3FBFA", backgroundEnd: "D5F4EF", card: "FFFFFF", cardEnd: "E5F7F4", secondary: "06221E", slate: "5A6B68", border: "C9DDD8", heroStart: "0B6E62", heroMid: "2EC4B6", heroEnd: "084E47")
        case .aurora:
            return make(primary: "1B7F45", background: "F4FBF7", backgroundEnd: "D7F3E4", card: "FFFFFF", cardEnd: "E7F7EE", secondary: "0C2416", slate: "5A6B62", border: "C9DDD2", heroStart: "146B3A", heroMid: "3DDC84", heroEnd: "0C3D22")
        case .sunset:
            return make(primary: "E15A3A", background: "FFF8F5", backgroundEnd: "FFE4D8", card: "FFFFFF", cardEnd: "FFF0E8", secondary: "2A120C", slate: "6E5C56", border: "E6D2C8", heroStart: "C2412D", heroMid: "FF8A65", heroEnd: "8C2F22")
        case .orchid:
            return make(primary: "7A4EAB", background: "FBF8FD", backgroundEnd: "EFE4F8", card: "FFFFFF", cardEnd: "F6EEFB", secondary: "1C1228", slate: "655C70", border: "DDD2E6", heroStart: "5E3A8C", heroMid: "B388EB", heroEnd: "3A2358")
        case .blossom:
            return make(primary: "D4537E", background: "FFF7FA", backgroundEnd: "FDE0EA", card: "FFFFFF", cardEnd: "FDECF2", secondary: "2A1018", slate: "705860", border: "E8D0D8", heroStart: "B83B68", heroMid: "FF8FB3", heroEnd: "7A2444")
        case .amber:
            return make(primary: "C4841D", background: "FFFBF4", backgroundEnd: "FDECCE", card: "FFFFFF", cardEnd: "FFF4E2", secondary: "24180A", slate: "6E6456", border: "E6D8C4", heroStart: "A86A10", heroMid: "F0B429", heroEnd: "6B4308")
        case .harbor:
            return make(primary: "1E4E8C", background: "F5F8FC", backgroundEnd: "D9E6F6", card: "FFFFFF", cardEnd: "E8F0FA", secondary: "0C1828", slate: "5A6570", border: "CDD6E2", heroStart: "163E73", heroMid: "4C8DDB", heroEnd: "0E294D")
        case .graphite:
            return make(primary: "2F6FED", background: "F6F7F8", backgroundEnd: "E6E8EC", card: "FFFFFF", cardEnd: "F0F1F3", secondary: "111214", slate: "5C6168", border: "D5D8DE", heroStart: "1C1E21", heroMid: "3A3D42", heroEnd: "111214")
        case .cedar:
            return make(primary: "C4622D", background: "FFF8F4", backgroundEnd: "F8E4D8", card: "FFFFFF", cardEnd: "FBEFE8", secondary: "24140E", slate: "6E5C54", border: "E4D4CA", heroStart: "C14E28", heroMid: "E8835A", heroEnd: "7A3018")
        case .sage:
            return make(primary: "5E8F72", background: "F6FAF7", backgroundEnd: "DCEEE4", card: "FFFFFF", cardEnd: "EAF4EE", secondary: "122018", slate: "5A6B62", border: "CDDDD4", heroStart: "3E6E56", heroMid: "7BB592", heroEnd: "244838")
        case .tide:
            return make(primary: "0F6E8C", background: "F3FAFC", backgroundEnd: "D4EEF5", card: "FFFFFF", cardEnd: "E6F5FA", secondary: "062028", slate: "567078", border: "C8DCE4", heroStart: "0C5870", heroMid: "3AA8C8", heroEnd: "083848")
        case .plum:
            return make(primary: "8E3A5B", background: "FDF7F9", backgroundEnd: "F6E0E8", card: "FFFFFF", cardEnd: "FBECEF", secondary: "240E16", slate: "705860", border: "E4D0D6", heroStart: "722E48", heroMid: "C46A88", heroEnd: "4A1C30")
        case .dune:
            return make(primary: "8C7355", background: "FBF8F4", backgroundEnd: "F0E6D8", card: "FFFFFF", cardEnd: "F7F1E8", secondary: "1C1610", slate: "6A6258", border: "E0D6CA", heroStart: "6E5840", heroMid: "B8956A", heroEnd: "463628")
        case .citrus:
            return make(primary: "6B8F1E", background: "F8FBF3", backgroundEnd: "E6F2CC", card: "FFFFFF", cardEnd: "F0F7E4", secondary: "161E08", slate: "5E6848", border: "D4DEBE", heroStart: "547214", heroMid: "9BC447", heroEnd: "34480C")
        case .azure:
            return make(primary: "1A8CDB", background: "F4FAFE", backgroundEnd: "D6EFFC", card: "FFFFFF", cardEnd: "E8F6FD", secondary: "062033", slate: "567088", border: "C8DCE8", heroStart: "0E74B8", heroMid: "4CB4F0", heroEnd: "084E80")
        case .ruby:
            return make(primary: "C23B4A", background: "FFF7F7", backgroundEnd: "FBE0E2", card: "FFFFFF", cardEnd: "FDECEE", secondary: "280C10", slate: "70585C", border: "E8D0D2", heroStart: "A02E3C", heroMid: "E56B78", heroEnd: "6E1C28")
        case .copper:
            return make(primary: "B87333", background: "FBF7F3", backgroundEnd: "F3E4D4", card: "FFFFFF", cardEnd: "F8EFE6", secondary: "1C120C", slate: "6A5C52", border: "E4D4C8", heroStart: "8C5420", heroMid: "D4924A", heroEnd: "5C3814")
        case .iris:
            return make(primary: "5B6CDB", background: "F6F7FD", backgroundEnd: "E2E6FA", card: "FFFFFF", cardEnd: "EEEFFE", secondary: "121428", slate: "5C6080", border: "D0D4E8", heroStart: "4454C4", heroMid: "8B98F0", heroEnd: "2A3480")
        }
    }

    private var dark: ThemePalette {
        switch self {
        case .glacier:
            return make(primary: "4599FF", background: "08141A", backgroundEnd: "0D3342", card: "1F2E38", cardEnd: "142933", secondary: "E4E6EB", slate: "B0B3B8", border: "3E4042", heroStart: "0F1A2E", heroMid: "1A3866", heroEnd: "0A121F", income: "2EAE6A", expense: "FF6B70", warning: "FFC94A")
        case .midnight:
            return make(primary: "8B80FF", background: "0C0A18", backgroundEnd: "16122C", card: "1C1830", cardEnd: "141028", secondary: "EEEAF8", slate: "B4AEC4", border: "3A3450", heroStart: "1A1440", heroMid: "3A2E86", heroEnd: "0C0A18", income: "3DDC97", expense: "FF7A90", warning: "FFD166")
        case .lagoon:
            return make(primary: "3DDCB8", background: "071614", backgroundEnd: "0E2E2A", card: "122824", cardEnd: "0C1E1C", secondary: "E7F6F3", slate: "A8C4BE", border: "2C4540", heroStart: "0C2420", heroMid: "14685C", heroEnd: "071614", income: "3DDC97", expense: "FF7A80", warning: "FFD166")
        case .aurora:
            return make(primary: "3DDC84", background: "07140E", backgroundEnd: "0E2A1C", card: "12281C", cardEnd: "0C1E14", secondary: "E8F6EE", slate: "A8C4B4", border: "2C4536", heroStart: "0C2416", heroMid: "146B3A", heroEnd: "07140E", income: "5BE7A0", expense: "FF7A80", warning: "FFD166")
        case .sunset:
            return make(primary: "FF8A65", background: "160E0C", backgroundEnd: "2E1812", card: "2A1C18", cardEnd: "1E1410", secondary: "F8EEEA", slate: "C4B0A8", border: "4A342C", heroStart: "2A1410", heroMid: "8C3A28", heroEnd: "160E0C", income: "3DDC97", expense: "FF6B5A", warning: "FFD166")
        case .orchid:
            return make(primary: "C9A6F5", background: "120E16", backgroundEnd: "24182E", card: "241C2C", cardEnd: "1A1422", secondary: "F4EEF8", slate: "C0B4C8", border: "433850", heroStart: "1C1428", heroMid: "4A3270", heroEnd: "120E16", income: "3DDC97", expense: "FF7A9A", warning: "FFD166")
        case .blossom:
            return make(primary: "FF8FB3", background: "160E12", backgroundEnd: "2E1822", card: "2A1820", cardEnd: "1E1218", secondary: "F8EEF2", slate: "C4B0B8", border: "4A343C", heroStart: "2A1420", heroMid: "7A3050", heroEnd: "160E12", income: "3DDC97", expense: "FF6B8A", warning: "FFD166")
        case .amber:
            return make(primary: "F0B429", background: "161208", backgroundEnd: "2E2412", card: "2A2214", cardEnd: "1E180C", secondary: "F8F2E8", slate: "C4B8A4", border: "4A4030", heroStart: "2A1C0C", heroMid: "6B4A12", heroEnd: "161208", income: "3DDC97", expense: "FF7A70", warning: "FFE08A")
        case .harbor:
            return make(primary: "7EB0F2", background: "0A1018", backgroundEnd: "122033", card: "162433", cardEnd: "101A28", secondary: "EAF1F8", slate: "A8B8C8", border: "2C3C50", heroStart: "101828", heroMid: "1E4E8C", heroEnd: "0A1018", income: "3DDC97", expense: "FF7A80", warning: "FFD166")
        case .graphite:
            return make(primary: "7AA2FF", background: "101114", backgroundEnd: "1C1E24", card: "22242A", cardEnd: "181A1E", secondary: "F2F3F5", slate: "B0B4BA", border: "3A3D44", heroStart: "16181C", heroMid: "2C3038", heroEnd: "101114", income: "3DDC97", expense: "FF7A80", warning: "FFD166")
        case .cedar:
            return make(primary: "F09A72", background: "140E0C", backgroundEnd: "2A1812", card: "261C16", cardEnd: "1C1410", secondary: "F6EEE8", slate: "C4B0A6", border: "4A3830", heroStart: "2A1610", heroMid: "8C4428", heroEnd: "140E0C", income: "3DDC97", expense: "FF7A70", warning: "FFD166")
        case .sage:
            return make(primary: "8FCBAA", background: "0C1410", backgroundEnd: "16281E", card: "1A2820", cardEnd: "121E18", secondary: "EAF4EE", slate: "A8C4B4", border: "344840", heroStart: "122018", heroMid: "2E5A42", heroEnd: "0C1410", income: "5BE7A0", expense: "FF7A80", warning: "FFD166")
        case .tide:
            return make(primary: "5EC8E4", background: "081418", backgroundEnd: "0E2830", card: "142830", cardEnd: "0E1E24", secondary: "E8F4F8", slate: "A8C4CC", border: "2C444C", heroStart: "0C2028", heroMid: "145868", heroEnd: "081418", income: "3DDC97", expense: "FF7A80", warning: "FFD166")
        case .plum:
            return make(primary: "E89AB4", background: "160C12", backgroundEnd: "2C1822", card: "2A1822", cardEnd: "1E1218", secondary: "F8EEF2", slate: "C4B0B8", border: "4A343C", heroStart: "2A1420", heroMid: "6E3048", heroEnd: "160C12", income: "3DDC97", expense: "FF7A9A", warning: "FFD166")
        case .dune:
            return make(primary: "D4B48A", background: "14110C", backgroundEnd: "282014", card: "262016", cardEnd: "1C1812", secondary: "F6F0E8", slate: "C4B8A8", border: "484034", heroStart: "241C12", heroMid: "5C4630", heroEnd: "14110C", income: "3DDC97", expense: "FF7A70", warning: "FFE08A")
        case .citrus:
            return make(primary: "C6E86A", background: "101408", backgroundEnd: "1E2810", card: "1E2614", cardEnd: "161C0E", secondary: "F2F6E8", slate: "B8C4A0", border: "3C4830", heroStart: "141C0C", heroMid: "3E5614", heroEnd: "101408", income: "8BE06A", expense: "FF7A80", warning: "FFD166")
        case .azure:
            return make(primary: "6EC4F5", background: "08141C", backgroundEnd: "102838", card: "142838", cardEnd: "0E1E2C", secondary: "EAF4FC", slate: "A8C0D0", border: "2C4458", heroStart: "0C1C2C", heroMid: "165888", heroEnd: "08141C", income: "3DDC97", expense: "FF7A80", warning: "FFD166")
        case .ruby:
            return make(primary: "FF8A96", background: "160C0E", backgroundEnd: "2E1418", card: "2A161A", cardEnd: "1E1014", secondary: "F8EEEF", slate: "C4B0B2", border: "4A3436", heroStart: "2A1216", heroMid: "7A2834", heroEnd: "160C0E", income: "3DDC97", expense: "FF6B78", warning: "FFD166")
        case .copper:
            return make(primary: "E8B07A", background: "14100C", backgroundEnd: "2A1C12", card: "261C14", cardEnd: "1C140E", secondary: "F6F0EA", slate: "C4B4A6", border: "4A3C32", heroStart: "24180E", heroMid: "6E4420", heroEnd: "14100C", income: "3DDC97", expense: "FF7A70", warning: "FFE08A")
        case .iris:
            return make(primary: "A8B4FF", background: "0E1018", backgroundEnd: "1A1E32", card: "1C2034", cardEnd: "141828", secondary: "EEEFF8", slate: "B4B8CC", border: "383C54", heroStart: "14182C", heroMid: "323C78", heroEnd: "0E1018", income: "3DDC97", expense: "FF7A90", warning: "FFD166")
        }
    }

    private func make(
        primary: String,
        background: String,
        backgroundEnd: String,
        card: String,
        cardEnd: String,
        secondary: String,
        slate: String,
        border: String,
        heroStart: String,
        heroMid: String,
        heroEnd: String,
        income: String = "1B7F45",
        expense: String = "FA383E",
        warning: String = "F7B928",
        onHero: String = "FFFFFF"
    ) -> ThemePalette {
        ThemePalette(
            primary: Color(moneyStalkerHex: primary),
            background: Color(moneyStalkerHex: background),
            backgroundEnd: Color(moneyStalkerHex: backgroundEnd),
            card: Color(moneyStalkerHex: card),
            cardEnd: Color(moneyStalkerHex: cardEnd),
            secondary: Color(moneyStalkerHex: secondary),
            income: Color(moneyStalkerHex: income),
            expense: Color(moneyStalkerHex: expense),
            slate: Color(moneyStalkerHex: slate),
            border: Color(moneyStalkerHex: border),
            warning: Color(moneyStalkerHex: warning),
            heroStart: Color(moneyStalkerHex: heroStart),
            heroMid: Color(moneyStalkerHex: heroMid),
            heroEnd: Color(moneyStalkerHex: heroEnd),
            onHero: Color(moneyStalkerHex: onHero)
        )
    }
}
