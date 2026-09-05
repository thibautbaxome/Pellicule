import PelliculeCore
import SwiftUI

/// Boîtiers et objectifs.
///
/// Tout part de la banque livrée : on cherche son appareil, on le sélectionne,
/// les caractéristiques se remplissent. Rien n'est imposé — un modèle absent se
/// déclare à la main, et la contribution la plus utile au projet consiste
/// justement à l'ajouter ensuite à la banque.
struct GearScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette
    @State private var isPickingCamera = false
    @State private var isPickingLens = false
    @State private var manualName = ""
    @State private var isNamingCamera = false
    @State private var isNamingLens = false
    @State private var manualLensName = ""
    @State private var manualLensFocal = ""
    @State private var manualLensAperture = ""
    @State private var editedCamera: Model.Camera?
    @State private var editedLens: Model.Lens?

    /// La monture à proposer d'emblée pour un objectif : celle des boîtiers
    /// déclarés, quand ils n'en ont qu'une. Avec plusieurs montures, on ne
    /// choisit pas à la place du photographe.
    private var suggestedMount: String? {
        let mounts = Set(carnet.cameras.compactMap(\.mount)).subtracting([Catalog.fixedMountName])
        return mounts.count == 1 ? mounts.first : nil
    }

    private var manualLensIsValid: Bool {
        !manualLensName.trimmingCharacters(in: .whitespaces).isEmpty
            && parsed(manualLensFocal).map { $0 > 0 } == true
            && parsed(manualLensAperture).map { $0 > 0 } == true
    }

    var body: some View {
        NavigationStack {
            Group {
                if carnet.cameras.isEmpty && carnet.lenses.isEmpty {
                    EmptyState(
                        title: "Aucun matériel",
                        message: "Déclarez le boîtier avec lequel vous photographiez. Sa plage de vitesses servira ensuite à ne vous proposer que des réglages qu’il sait tenir.",
                        actionTitle: "Chercher mon boîtier",
                        action: { isPickingCamera = true })
                } else {
                    list
                }
            }
            .carnetBackground(palette)
            .navigationTitle("Matériel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Boîtier de la banque") { isPickingCamera = true }
                        Button("Objectif de la banque") { isPickingLens = true }
                        Divider()
                        Button("Boîtier à la main") {
                            manualName = ""
                            isNamingCamera = true
                        }
                        Button("Objectif à la main") { startNamingLens() }
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPickingCamera) {
                CameraPickerSheet { entry in
                    carnet.save(carnet.makeCamera(from: entry))
                }
            }
            .sheet(isPresented: $isPickingLens) {
                LensPickerSheet(mount: suggestedMount, onManual: { startNamingLens() }) { entry in
                    carnet.save(carnet.makeLens(from: entry))
                }
            }
            .sheet(item: $editedCamera) { camera in
                CameraEditSheet(carnet: carnet, camera: camera)
            }
            .sheet(item: $editedLens) { lens in
                LensEditSheet(carnet: carnet, lens: lens)
            }
            .alert("Nouveau boîtier", isPresented: $isNamingCamera) {
                TextField("Nom du boîtier", text: $manualName)
                Button("Ajouter") {
                    let name = manualName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    carnet.save(carnet.makeCamera(named: name))
                    manualName = ""
                }
                .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Annuler", role: .cancel) { manualName = "" }
            } message: {
                Text("Vous pourrez compléter ensuite sa monture, sa plage de vitesses — ou son objectif solidaire, pour un compact.")
            }
            .alert("Nouvel objectif", isPresented: $isNamingLens) {
                TextField("Nom (Helios 44-2 58mm f/2)", text: $manualLensName)
                TextField("Focale en mm", text: $manualLensFocal)
                    .keyboardType(.decimalPad)
                TextField("Ouverture la plus grande (1.7)", text: $manualLensAperture)
                    .keyboardType(.decimalPad)
                Button("Ajouter") { addManualLens() }
                    .disabled(!manualLensIsValid)
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Pour un zoom, indiquez la focale la plus courte : la fiche permettra ensuite d’ajouter l’autre borne, la monture et le diamètre de filtre.")
            }
        }
    }

    private func startNamingLens() {
        manualLensName = ""
        manualLensFocal = ""
        manualLensAperture = ""
        isNamingLens = true
    }

    private func addManualLens() {
        guard let focal = parsed(manualLensFocal), let aperture = parsed(manualLensAperture)
        else { return }
        var lens = carnet.makeLens(
            named: manualLensName.trimmingCharacters(in: .whitespaces),
            focal: focal, maxAperture: aperture)
        lens.mount = suggestedMount
        carnet.save(lens)
        // La fiche s'ouvre aussitôt : c'est là que se complètent monture,
        // ouverture minimale et diamètre de filtre.
        editedLens = lens
    }

    /// Un nombre tapé avec une virgule, comme sur un clavier français.
    private func parsed(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !carnet.cameras.isEmpty {
                    MicroLabel("Boîtiers").padding(.top, 6)
                    ForEach(carnet.cameras) { camera in
                        Button { editedCamera = camera } label: {
                            CameraCard(camera: camera)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel(camera.name)
                        .accessibilityHint("Modifier ce boîtier")
                    }
                }
                if !carnet.lenses.isEmpty {
                    MicroLabel("Objectifs").padding(.top, 14)
                    ForEach(carnet.lenses) { lens in
                        Button { editedLens = lens } label: {
                            LensCard(lens: lens)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel(lens.name)
                        .accessibilityHint("Modifier cet objectif")
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct CameraCard: View {
    let camera: Model.Camera

    @Environment(\.palette) private var palette

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(camera.name)
                        .font(Typo.heading)
                        .foregroundStyle(palette.text)
                    Spacer()
                    if camera.archived {
                        MicroLabel("Archivé")
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textFaint)
                }

                HStack(spacing: 10) {
                    if let mount = camera.mount {
                        MicroLabel(mount, colour: palette.accent)
                    }
                    if let fixed = camera.fixedLens {
                        ValueText(
                            text: "\(Int(fixed.focal)) mm f/\(trimmed(fixed.maxAperture))",
                            size: 13, colour: palette.textDim)
                    }
                }

                shutterLine
            }
        }
    }

    /// La plage n'est affichée que telle qu'elle a été déclarée : compléter
    /// une borne manquante par le bout de la graduation ferait dire au boîtier
    /// « 30s » ou « 1/8000 » avec l'assurance des vraies valeurs.
    @ViewBuilder
    private var shutterLine: some View {
        switch (camera.shutterSlowest, camera.shutterFastest) {
        case let (slowest?, fastest?):
            HStack(spacing: 6) {
                MicroLabel("Vitesses")
                ValueText(text: "\(slowest) – \(fastest)", size: 13, colour: palette.textDim)
            }
        case let (nil, fastest?):
            HStack(spacing: 6) {
                MicroLabel("Vitesses")
                ValueText(text: "jusqu’au \(fastest)", size: 13, colour: palette.textDim)
            }
        case let (slowest?, nil):
            HStack(spacing: 6) {
                MicroLabel("Vitesses")
                ValueText(text: "à partir de \(slowest)", size: 13, colour: palette.textDim)
            }
        case (nil, nil):
            if camera.fixedLens != nil {
                // Un compact automatique ne laisse pas choisir la vitesse : il
                // n'y a rien à compléter, et le dire évite une fausse tâche.
                Text("Plage de vitesses non déclarée — normal pour un compact automatique.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Sans plage déclarée, l'assistant ne peut pas dire qu'un
                // réglage sort des capacités du boîtier. Autant le dire.
                Text("Plage de vitesses inconnue : les réglages proposés ne seront pas bornés. Touchez pour la compléter.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

private struct LensCard: View {
    let lens: Model.Lens

    @Environment(\.palette) private var palette

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lens.name)
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                    Spacer()
                    if lens.archived {
                        MicroLabel("Archivé")
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textFaint)
                }
                HStack(spacing: 10) {
                    ValueText(
                        text: lens.isPrime
                            ? "\(Int(lens.focalMin)) mm"
                            : "\(Int(lens.focalMin))–\(Int(lens.focalMax)) mm",
                        size: 13, colour: palette.accent)
                    if let maxAperture = lens.maxAperture {
                        ValueText(
                            text: "f/\(trimmed(maxAperture))", size: 13, colour: palette.textDim)
                    }
                    if let mount = lens.mount {
                        MicroLabel(mount)
                    }
                    if let thread = lens.filterThread {
                        MicroLabel("⌀ \(trimmed(thread))")
                    }
                }
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
