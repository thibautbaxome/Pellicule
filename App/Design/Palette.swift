import SwiftUI

/// Système visuel : néo-rétro argentique.
///
/// Le vocabulaire vient du matériel lui-même — noir chaud des boîtiers en
/// peinture martelée, blanc cassé du papier baryté, ambre de la lampe
/// inactinique, chiffres gravés des bagues d'objectif.
///
/// Toutes les couleurs de l'application passent par ici. Aucune vue ne doit
/// écrire une teinte en dur : c'est ce qui permet à la chambre noire de rester
/// entièrement rouge sans retoucher chaque écran.
struct Palette: Equatable {

    let bg: Color
    let surface: Color
    let raised: Color
    let sunken: Color
    let line: Color
    let lineStrong: Color

    let text: Color
    let textDim: Color
    let textFaint: Color

    let accent: Color
    let accentSoft: Color
    let accentInk: Color

    let danger: Color
    let ok: Color

    let scheme: ColorScheme

    /// La palette de référence, celle dans laquelle l'application a été dessinée.
    static let night = Palette(
        bg: Color(hex: 0x0C0B0A),
        surface: Color(hex: 0x151310),
        raised: Color(hex: 0x1E1A16),
        sunken: Color(hex: 0x080706),
        line: Color(hex: 0x322C25),
        lineStrong: Color(hex: 0x4A4137),
        text: Color(hex: 0xEFE9DE),
        textDim: Color(hex: 0xA49A8B),
        textFaint: Color(hex: 0x6B6357),
        accent: Color(hex: 0xE9A13B),
        accentSoft: Color(hex: 0x3A2A12),
        accentInk: Color(hex: 0x17120A),
        danger: Color(hex: 0xF0603F),
        ok: Color(hex: 0x7EC4A8),
        scheme: .dark)

    /// Planche contact sur papier crème, et non page blanche : un carnet de
    /// prise de vue n'est pas un tableur.
    static let paper = Palette(
        bg: Color(hex: 0xE8E2D5),
        surface: Color(hex: 0xF4EFE5),
        raised: Color(hex: 0xFBF8F1),
        sunken: Color(hex: 0xDCD5C6),
        line: Color(hex: 0xC9C0AC),
        lineStrong: Color(hex: 0xA89D85),
        text: Color(hex: 0x1A1712),
        textDim: Color(hex: 0x5C5445),
        textFaint: Color(hex: 0x8B8171),
        accent: Color(hex: 0x9A5F0D),
        accentSoft: Color(hex: 0xEFDFC2),
        accentInk: Color(hex: 0xFDF9F2),
        danger: Color(hex: 0xA83218),
        ok: Color(hex: 0x2C6D54),
        scheme: .light)

    /// Chambre noire : rien que du rouge sombre. Une pastille bleue suffit à
    /// voiler du papier et à casser la vision nocturne.
    static let darkroom = Palette(
        bg: Color(hex: 0x000000),
        surface: Color(hex: 0x120303),
        raised: Color(hex: 0x1D0605),
        sunken: Color(hex: 0x000000),
        line: Color(hex: 0x3D0F0C),
        lineStrong: Color(hex: 0x5C1713),
        text: Color(hex: 0xFF5340),
        textDim: Color(hex: 0xB73525),
        textFaint: Color(hex: 0x77231A),
        accent: Color(hex: 0xFF6F4A),
        accentSoft: Color(hex: 0x310A06),
        accentInk: Color(hex: 0x000000),
        danger: Color(hex: 0xFF9078),
        ok: Color(hex: 0xFF6F4A),
        scheme: .dark)
}

/// Thème choisi dans les réglages. Sa valeur brute est celle enregistrée dans
/// le carnet : la renommer ferait perdre le réglage à la mise à jour.
enum Theme: String, CaseIterable, Identifiable {
    case dark
    case light
    case system
    case darkroom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: "Sombre"
        case .light: "Papier"
        case .system: "Système"
        case .darkroom: "Chambre noire"
        }
    }

    func palette(system: ColorScheme) -> Palette {
        switch self {
        case .dark: .night
        case .light: .paper
        case .darkroom: .darkroom
        case .system: system == .dark ? .night : .paper
        }
    }
}

// MARK: - Diffusion dans les vues

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.night
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    /// Couleur depuis un code hexadécimal RVB, pour transcrire la palette telle
    /// qu'elle a été dessinée.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}
