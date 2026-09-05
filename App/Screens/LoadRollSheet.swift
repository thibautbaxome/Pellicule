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

    private var availableCameras: [Model.Camera] {
        carnet.cameras.filter { !$0.archived }
    }

    private var selectedCamera: Model.Camera? {
        cameraId.flatMap { carnet.camera(id: $0) }
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
            .onAppear {
                if cameraId == nil {
                    cameraId = carnet.settings.defaultCameraId ?? availableCameras.first?.id
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
                        detail: camera.availableShutters.isEmpty
                            ? camera.mount
                            : "\(camera.availableShutters.last ?? "") – \(camera.availableShutters.first ?? "")",
                        isSelected: camera.id == cameraId
                    ) {
                        cameraId = camera.id
                    }
                }
            }
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
                    selection: Binding(
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
        let magnitude = abs(stops) == abs(stops).rounded()
            ? String(Int(abs(stops)))
            : String((abs(stops) * 10).rounded() / 10)
        return stops > 0
            ? "Poussée de \(magnitude) diaph : le développement devra être allongé."
            : "Retenue de \(magnitude) diaph : le développement devra être raccourci."
    }

    /// La graduation des sensibilités, bornée à deux diaphragmes de part et
    /// d'autre de la boîte : au-delà, on ne pousse plus, on abîme.
    private func isoChoices(around boxIso: Double) -> [Double] {
        (-2...2).map { (boxIso * pow(2, Double($0))).rounded() }
    }

    private func exposuresField(film: Catalog.Film) -> some View {
        FieldRow(label: "Nombre de poses") {
            ScaleDial(
                values: [12, 24, 36],
                label: { "\($0)" },
                selection: Binding(
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
        let roll = carnet.loadRoll(
            film: film,
            camera: camera,
            shotIso: shotIso,
            exposures: exposures,
            label: label.trimmingCharacters(in: .whitespaces).isEmpty ? nil : label)
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
    }
}
