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
        // En encart, pas en superposition : la bannière pousse l'écran au lieu
        // de recouvrir sa barre de titre et ses boutons.
        .safeAreaInset(edge: .top) {
            if let error = carnet.lastWriteError {
                WriteErrorBanner(message: error, palette: palette) { carnet.persist() }
            }
        }
    }
}

/// L'écriture a échoué : la saisie est toujours là, mais elle n'est pas encore
/// sur le disque. Le dire tout de suite, plutôt que de le découvrir au
/// redémarrage suivant — et offrir de réessayer.
private struct WriteErrorBanner: View {
    let message: String
    let palette: Palette
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                MicroLabel("Enregistrement impossible", colour: palette.accentInk)
                Text("La saisie est conservée à l’écran mais n’a pas pu être écrite.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.accentInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Réessayer", action: retry)
                .font(Typo.ui(14, .semibold))
                .foregroundStyle(palette.accentInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Capsule().strokeBorder(palette.accentInk, lineWidth: 1))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.danger)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Enregistrement impossible. \(message)")
    }
}
