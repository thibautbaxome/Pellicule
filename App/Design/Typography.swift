import SwiftUI

/// Deux règles typographiques tiennent tout le système.
///
/// Les valeurs chiffrées — vitesses, ouvertures, sensibilités, coordonnées —
/// sont en chasse fixe à chiffres tabulaires : elles se lisent d'un coup d'œil
/// au soleil, et une colonne de valeurs s'aligne comme une graduation gravée.
///
/// Les micro-libellés sont en capitales largement interlettrées, à la manière
/// des mentions imprimées sur une boîte de film — « 135 · 36 POSES · ISO 400 ».
///
/// Les polices dessinées pour le projet, Space Grotesk et Space Mono, ne sont
/// pas encore empaquetées : `ui` et `value` désignent les rôles, pas les
/// fichiers. Le jour où elles arrivent, ce fichier est le seul à changer.
enum Typo {

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func value(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let title = ui(26, .semibold)
    static let heading = ui(19, .semibold)
    static let body = ui(16)
    static let caption = ui(13)

    /// Le chiffre héroïque : le couple vitesse/ouverture qu'on lit à bout de bras.
    static let hero = value(38, .semibold)
    static let reading = value(17)
    static let smallReading = value(13)
}

/// Micro-libellé : capitales interlettrées, comme sur une boîte de film.
struct MicroLabel: View {
    let text: String
    var colour: Color?

    @Environment(\.palette) private var palette

    init(_ text: String, colour: Color? = nil) {
        self.text = text
        self.colour = colour
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(colour ?? palette.textFaint)
    }
}

/// Valeur chiffrée, en chasse fixe.
struct ValueText: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.Weight = .medium
    var colour: Color?

    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Typo.value(size, weight))
            .monospacedDigit()
            .foregroundStyle(colour ?? palette.text)
    }
}
