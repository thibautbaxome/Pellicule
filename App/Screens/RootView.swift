import PelliculeCore
import SwiftUI

struct RootView: View {
    @Bindable var carnet: Carnet

    @Environment(\.colorScheme) private var systemScheme

    private var theme: Theme {
        Theme(rawValue: carnet.settings.theme) ?? .dark
    }

    private var palette: Palette {
        theme.palette(system: systemScheme)
    }

    var body: some View {
        TabView {
            RollsScreen(carnet: carnet)
                .tabItem { Label("Rouleaux", systemImage: "film") }

            AssistantScreen(carnet: carnet)
                .tabItem { Label("Assistant", systemImage: "sun.max") }

            GearScreen(carnet: carnet)
                .tabItem { Label("Matériel", systemImage: "camera") }

            SettingsScreen(carnet: carnet)
                .tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
        }
        .tint(palette.accent)
        .environment(\.palette, palette)
        // Le thème pilote aussi l'apparence des éléments système — barre
        // d'onglets, clavier, indicateurs de défilement. Sauf « Système » :
        // forcer l'apparence réécrirait la valeur qu'on lit justement pour la
        // suivre, et le thème resterait figé sur son premier état.
        .preferredColorScheme(theme == .system ? nil : palette.scheme)
        .overlay(alignment: .top) {
            if let error = carnet.lastWriteError {
                WriteErrorBanner(message: error, palette: palette)
            }
        }
    }
}

/// L'écriture a échoué : la saisie est toujours là, mais elle n'est pas encore
/// sur le disque. Le dire tout de suite, plutôt que de le découvrir au
/// redémarrage suivant.
private struct WriteErrorBanner: View {
    let message: String
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MicroLabel("Enregistrement impossible", colour: palette.accentInk)
            Text("La saisie est conservée à l’écran mais n’a pas pu être écrite.")
                .font(Typo.caption)
                .foregroundStyle(palette.accentInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.danger)
        .padding(.horizontal, 12)
        .accessibilityLabel("Enregistrement impossible. \(message)")
    }
}
