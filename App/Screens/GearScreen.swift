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
    @State private var editedCamera: Model.Camera?
    @State private var editedLens: Model.Lens?

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
                        Button("Boîtier à la main") { isNamingCamera = true }
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
                LensPickerSheet(mount: nil) { entry in
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
                Button("Annuler", role: .cancel) { manualName = "" }
            } message: {
                Text("Vous pourrez compléter sa monture et sa plage de vitesses ensuite.")
            }
        }
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
                        .buttonStyle(.plain)
                    }
                }
                if !carnet.lenses.isEmpty {
                    MicroLabel("Objectifs").padding(.top, 14)
                    ForEach(carnet.lenses) { lens in
                        Button { editedLens = lens } label: {
                            LensCard(lens: lens)
                        }
                        .buttonStyle(.plain)
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

                let shutters = camera.availableShutters
                if let slowest = shutters.first, let fastest = shutters.last {
                    HStack(spacing: 6) {
                        MicroLabel("Vitesses")
                        ValueText(text: "\(slowest) – \(fastest)", size: 13, colour: palette.textDim)
                    }
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
                        MicroLabel("⌀ \(Int(thread))")
                    }
                }
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
