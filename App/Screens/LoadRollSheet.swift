import PelliculeCore
import SwiftUI

/// Chargement d'une pellicule dans un boîtier.
///
/// L'ordre des questions suit le geste réel : on prend un boîtier, on y met une
/// pellicule, et c'est seulement si on décide de la pousser qu'on touche à la
/// sensibilité.
struct LoadRollSheet: View {
    @Bindable var carnet: Carnet

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var cameraId: String?
    @State private var film: Catalog.Film?
    @State private var label = ""
    @State private var shotIso: Double?
    @State private var exposures: Int?
    @State private var isPickingFilm = false
    @State private var isPickingCamera = false

    private var availableCameras: [Model.Camera] {
        carnet.cameras.filter { !$0.archived }
    }

    /// Parmi les boîtiers proposés seulement : un boîtier archivé ne doit pas
    /// recevoir de rouleau, même s'il était le boîtier par défaut.
    private var selectedCamera: Model.Camera? {
        availableCameras.first { $0.id == cameraId }
    }

    private var canLoad: Bool { selectedCamera != nil && film != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    cameraField
                    filmField
                    if let film {
                        sensitivityField(film: film)
                        exposuresField(film: film)
                    }
                    labelField
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Charger une pellicule")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Charger", action: load)
                    .buttonStyle(PrimaryButtonStyle(palette: palette))
                    .disabled(!canLoad)
                    .opacity(canLoad ? 1 : 0.4)
                    .padding(16)
                    .background(palette.bg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .sheet(isPresented: $isPickingFilm) {
                FilmPickerSheet { chosen in
                    film = chosen
                    shotIso = chosen.iso
                    exposures = chosen.defaultExposures
                }
            }
            .sheet(isPresented: $isPickingCamera) {
                CameraPickerSheet { entry in
                    let camera = carnet.makeCamera(from: entry)
                    carnet.save(camera)
                    cameraId = camera.id
                }
            }
            .onAppear {
                if selectedCamera == nil {
                    let preferred = carnet.settings.defaultCameraId.flatMap { id in
                        availableCameras.first { $0.id == id }
                    }
                    cameraId = (preferred ?? availableCameras.first)?.id
                }
            }
        }
    }

    private var cameraField: some View {
        FieldRow(label: "Boîtier") {
            VStack(spacing: 8) {
                ForEach(availableCameras) { camera in
                    SelectableRow(
                        title: camera.name,
                        detail: cameraDetail(camera),
                        isSelected: camera.id == cameraId
                    ) {
                        cameraId = camera.id
                    }
                }
                if availableCameras.isEmpty {
                    Text("Aucun boîtier disponible : les vôtres sont archivés, ou aucun n’est déclaré.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Chercher mon boîtier") { isPickingCamera = true }
                        .buttonStyle(SecondaryButtonStyle(palette: palette))
                }
            }
        }
    }

    /// La plage telle qu'elle est déclarée, jamais complétée par la graduation :
    /// un boîtier saisi à la main n'a pas « 30s – 1/8000 ».
    private func cameraDetail(_ camera: Model.Camera) -> String? {
        switch (camera.shutterSlowest, camera.shutterFastest) {
        case let (slowest?, fastest?): return "\(slowest) – \(fastest)"
        case let (nil, fastest?): return "jusqu’au \(fastest)"
        case let (slowest?, nil): return "à partir de \(slowest)"
        case (nil, nil): return camera.mount
        }
    }

    private var filmField: some View {
        FieldRow(label: "Pellicule") {
            Button {
                isPickingFilm = true
            } label: {
                HStack {
                    if let film {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(film.displayName)
                                .font(Typo.body)
                                .foregroundStyle(palette.text)
                            Text("\(Int(film.iso)) ISO · \(film.type.label)")
                                .font(Typo.caption)
                                .foregroundStyle(palette.textDim)
                        }
                    } else {
                        Text("Choisir dans la banque")
                            .font(Typo.body)
                            .foregroundStyle(palette.textDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(palette.textFaint)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(palette.sunken)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// Exposer à une sensibilité différente de celle de la boîte, c'est pousser
    /// ou retenir le film — et cela se répercute au développement. L'écart est
    /// donc annoncé ici, pas découvert au labo.
    private func sensitivityField(film: Catalog.Film) -> some View {
        let choices = isoChoices(around: film.iso)
        return FieldRow(label: "Exposée à") {
            VStack(alignment: .leading, spacing: 8) {
                ScaleDial(
                    values: choices,
                    label: { "\(Int($0))" },
                    selection: Binding<Double?>(
                        get: { shotIso ?? film.iso },
                        set: { shotIso = $0 ?? film.iso }))
                if let shotIso, abs(shotIso - film.iso) > 0.01 {
                    let stops = Exposure.pushPullStops(shotIso: shotIso, boxIso: film.iso)
                    Text(pushPullExplanation(stops: stops))
                        .font(Typo.caption)
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    private func pushPullExplanation(stops: Double) -> String {
        // Au demi-diaphragme : un ISO 50 exposé à 12 fait bien deux
        // diaphragmes, pas « 2,1 » à cause de l'arrondi des sensibilités.
        let magnitude = (abs(stops) * 2).rounded() / 2
        let plural = magnitude >= 2 ? "s" : ""
        return stops > 0
            ? "Poussée de \(Fmt.stops(magnitude)) diaphragme\(plural) : le développement devra être allongé."
            : "Retenue de \(Fmt.stops(magnitude)) diaphragme\(plural) : le développement devra être raccourci."
    }

    /// L'échelle normalisée des sensibilités, au tiers de diaphragme.
    private static let isoScale: [Double] = [
        6, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
        800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800,
    ]

    /// La graduation des sensibilités, bornée à deux diaphragmes de part et
    /// d'autre de la boîte : au-delà, on ne pousse plus, on abîme. Les valeurs
    /// sont celles de l'échelle normalisée — 12, 32, 64 — et non un calcul
    /// arrondi qui donnerait 13, 31 ou 63.
    private func isoChoices(around boxIso: Double) -> [Double] {
        let raw = (-2...2).map { boxIso * pow(2, Double($0)) }
        let snapped = raw.map { target in
            Self.isoScale.min { abs($0 - target) < abs($1 - target) } ?? target
        }
        return Array(Set(snapped + [boxIso])).sorted()
    }

    private func exposuresField(film: Catalog.Film) -> some View {
        FieldRow(label: "Nombre de poses") {
            ScaleDial(
                values: Array(Set([12, 24, 36, film.defaultExposures, carnet.settings.defaultExposures])).sorted(),
                label: { "\($0)" },
                selection: Binding<Int?>(
                    get: { exposures ?? film.defaultExposures },
                    set: { exposures = $0 ?? film.defaultExposures }))
        }
    }

    private var labelField: some View {
        FieldRow(label: "Nom du rouleau (facultatif)") {
            TextField("Pointe du Raz, Sortie du dimanche…", text: $label)
                .textInputAutocapitalization(.sentences)
                .fieldStyle(palette)
        }
    }

    private func load() {
        guard let camera = selectedCamera, let film else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let roll = carnet.loadRoll(
            film: film,
            camera: camera,
            shotIso: shotIso,
            exposures: exposures,
            label: trimmed.isEmpty ? nil : trimmed)
        carnet.save(roll)
        dismiss()
    }
}

/// Ligne sélectionnable, à la place d'un menu déroulant : sur le terrain, une
/// cible large vaut mieux qu'un choix compact.
struct SelectableRow: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                    if let detail {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(palette.textDim)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? palette.accentSoft : palette.sunken)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(isSelected ? palette.accent : palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Sans cela, une ligne portant une explication s'annonce en récitant
        // les deux textes d'affilée : le nom du choix se perd dans la phrase.
        .accessibilityLabel(title)
        .accessibilityHint(detail ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
