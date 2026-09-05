import CoreText
import os
import SwiftUI

/// Deux règles typographiques tiennent tout le système.
///
/// Les valeurs chiffrées — vitesses, ouvertures, sensibilités, coordonnées —
/// sont en Space Mono, à chiffres tabulaires : elles se lisent d'un coup d'œil
/// au soleil, et une colonne de valeurs s'aligne comme une graduation gravée.
/// Ses formes de machine à écrire donnent aux valeurs l'air d'être gravées sur
/// une bague d'objectif.
///
/// L'interface est en Space Grotesk, un grotesque aux formes techniques, sans
/// la neutralité fade des polices système. Les micro-libellés sont en
/// capitales largement interlettrées, à la manière des mentions imprimées sur
/// une boîte de film — « 135 · 36 POSES · ISO 400 ».
///
/// Les deux polices sont embarquées et enregistrées au lancement plutôt que
/// déclarées dans l'Info.plist : une déclaration oubliée ferait retomber en
/// silence sur la police système, alors qu'un enregistrement raté se voit dans
/// le journal.
enum Typo {

    /// À appeler une fois, au démarrage, avant la première vue.
    static func registerFonts() {
        let log = Logger(subsystem: "app.pellicule.carnet", category: "typographie")
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil),
              !urls.isEmpty
        else {
            log.error("Aucune police embarquée : l’interface retombe sur la police système.")
            return
        }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let reason = error.map { CFErrorCopyDescription($0.takeRetainedValue()) as String }
                    ?? "raison inconnue"
                log.error("Police non enregistrée : \(url.lastPathComponent, privacy: .public) — \(reason, privacy: .public)")
            }
        }
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .bold, .heavy, .black: face = "SpaceGrotesk-Bold"
        case .semibold: face = "SpaceGrotesk-SemiBold"
        case .medium: face = "SpaceGrotesk-Medium"
        default: face = "SpaceGrotesk-Regular"
        }
        return .custom(face, size: size)
    }

    static func value(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        // Space Mono n'existe qu'en deux graisses ; le medium tombe sur la
        // régulière, dont le trait est déjà ferme.
        switch weight {
        case .semibold, .bold, .heavy, .black: .custom("SpaceMono-Bold", size: size)
        default: .custom("SpaceMono-Regular", size: size)
        }
    }

    static let title = ui(26, .semibold)
    static let heading = ui(19, .semibold)
    static let body = ui(16)
    static let caption = ui(13)

    /// Le chiffre héroïque : le couple vitesse/ouverture qu'on lit à bout de bras.
    static let hero = value(38, .bold)
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
            .font(Typo.ui(10.5, .semibold))
            .tracking(1.4)
            .foregroundStyle(colour ?? palette.textFaint)
            // Les capitales sont un parti pris typographique, pas le texte :
            // une synthèse vocale qui lit « EXPOSÉE À » l'épelle ou la crie.
            .accessibilityLabel(text)
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
