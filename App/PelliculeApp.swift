import PelliculeCore
import SwiftUI

@main
struct PelliculeApp: App {

    @State private var carnet: Carnet
    /// Message d'échec de la relecture, s'il y en a eu une.
    @State private var loadFailure: String?

    init() {
        let carnet = Carnet(fileURL: URL.documentsDirectory.appendingPathComponent("carnet.json"))
        var failure: String?
        do {
            try carnet.load()
        } catch {
            // Le carnet se verrouille de lui-même : rien ne sera écrit tant que
            // le fichier n'aura pas été relu correctement.
            failure = (error as? Backup.ImportError)?.description ?? String(describing: error)
        }
        _carnet = State(initialValue: carnet)
        _loadFailure = State(initialValue: failure)
    }

    var body: some Scene {
        WindowGroup {
            if let loadFailure {
                UnreadableCarnetView(message: loadFailure)
            } else {
                RootView(carnet: carnet)
            }
        }
    }
}

/// Écran d'arrêt : le fichier existe mais n'a pas pu être lu.
///
/// Il vaut mieux bloquer l'application que la laisser repartir d'un carnet
/// vide : la première saisie écraserait alors des années de prises de vue. Le
/// fichier reste en place, récupérable par l'application Fichiers.
private struct UnreadableCarnetView: View {
    let message: String

    private let palette = Palette.night

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MicroLabel("Carnet illisible", colour: palette.danger)
            Text("Le carnet n’a pas pu être ouvert")
                .font(Typo.title)
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Typo.body)
                .foregroundStyle(palette.textDim)
                .multilineTextAlignment(.center)
            SprocketRule(holes: 10).frame(width: 130)
            Text("""
                Rien n’a été modifié. Le fichier est intact dans l’application \
                Fichiers, sous « Sur mon iPhone », dossier Pellicule — vous \
                pouvez le copier avant toute autre manipulation.
                """)
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
        .environment(\.palette, palette)
    }
}
