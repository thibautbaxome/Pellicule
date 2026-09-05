import PelliculeCore
import SwiftUI

/// Corriger et compléter un boîtier.
///
/// La banque livrée donne un point de départ, pas une vérité : un même modèle
/// se décline, un obturateur se dérègle, un numéro de série n'appartient qu'à
/// l'exemplaire qu'on a en main. Sans cet écran, une entrée fausse restait
/// fausse pour toujours — et c'est la plage de vitesses qui compte le plus,
/// puisque tout ce que l'assistant propose en dépend.
struct CameraEditSheet: View {
    @Bindable var carnet: Carnet
    @State var camera: Model.Camera

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var isConfirmingDeletion = false

    private var isUsed: Bool { carnet.isUsed(cameraId: camera.id) }
    private var trimmedName: String { camera.name.trimmingCharacters(in: .whitespaces) }

    /// La plage est inversée quand la plus rapide dure plus longtemps que la
    /// plus lente : enregistrée telle quelle, elle viderait la graduation.
    private var rangeIsInverted: Bool {
        guard let fastest = camera.shutterFastest, let slowest = camera.shutterSlowest,
              let f = Exposure.seconds(from: fastest), let s = Exposure.seconds(from: slowest)
        else { return false }
        return f >= s
    }

    private var canSave: Bool { !trimmedName.isEmpty && !rangeIsInverted }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    FieldRow(label: "Nom") {
                        TextField("Minolta X-300", text: $camera.name)
                            .textInputAutocapitalization(.words)
                            .fieldStyle(palette)
                    }

                    fixedLensField

                    if camera.fixedLens == nil {
                        mountField
                    }

                    shutterRange

                    FieldRow(label: "Numéro de série") {
                        TextField("Pour l’assurance et les petites annonces",
                                  text: optional($camera.serial))
                            .fieldStyle(palette)
                    }

                    meterBias

                    FieldRow(label: "Notes") {
                        TextField("Particularités, révisions, défauts…",
                                  text: optional($camera.notes), axis: .vertical)
                            .lineLimit(2...5)
                            .fieldStyle(palette)
                    }

                    retirement
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Boîtier")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    camera.name = trimmedName
                    camera.mount = camera.mount?.trimmingCharacters(in: .whitespaces)
                    if camera.mount?.isEmpty == true { camera.mount = nil }
                    camera.updatedAt = Carnet.timestamp(Date())
                    carnet.save(camera)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
                .padding(16)
                .background(palette.bg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .confirmationDialog(
                "Supprimer « \(camera.name) » ?", isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    carnet.delete(cameraId: camera.id)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    /// Un compact a son objectif dans le boîtier : le déclarer ici, c'est
    /// donner à l'assistant ses vraies ouvertures, et ne plus jamais proposer
    /// d'objectif à monter dessus.
    private var fixedLensField: some View {
        FieldRow(label: "Objectif") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { camera.fixedLens != nil },
                    set: { fixed in
                        if fixed {
                            camera.fixedLens = camera.fixedLens
                                ?? Model.Camera.FixedLens(focal: 35, maxAperture: 2.8)
                            camera.mount = Catalog.fixedMountName
                        } else {
                            camera.fixedLens = nil
                            if camera.mount == Catalog.fixedMountName { camera.mount = nil }
                        }
                    })
                ) {
                    Text("Objectif solidaire du boîtier")
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)

                if camera.fixedLens != nil {
                    MicroLabel("Focale")
                    ScaleDial(
                        values: Fmt.including(camera.fixedLens?.focal, in: [24, 28, 35, 38, 40, 45, 50] as [Double]),
                        label: { "\(Int($0)) mm" },
                        selection: Binding<Double?>(
                            get: { camera.fixedLens?.focal },
                            set: { if let value = $0 { camera.fixedLens?.focal = value } }))
                    MicroLabel("Ouverture la plus grande")
                    ScaleDial(
                        values: Fmt.including(
                            camera.fixedLens?.maxAperture,
                            in: [1.7, 1.8, 2, 2.8, 3.5, 4, 5.6] as [Double]),
                        label: { "f/\(trimmed($0))" },
                        selection: Binding<Double?>(
                            get: { camera.fixedLens?.maxAperture },
                            set: { if let value = $0 { camera.fixedLens?.maxAperture = value } }))
                } else {
                    Text("Laissez décoché pour un boîtier à objectifs interchangeables.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                }
            }
        }
    }

    /// La monture décide des objectifs proposés, en égalité stricte : on la
    /// choisit dans la liste plutôt que de la taper avec une variante qui ne
    /// trouverait plus rien.
    private var mountField: some View {
        FieldRow(label: "Monture") {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Catalog.mounts, id: \.self) { mount in
                            let selected = camera.mount == mount
                            Button {
                                camera.mount = selected ? nil : mount
                            } label: {
                                Text(mount)
                                    .font(Typo.caption)
                                    .foregroundStyle(selected ? palette.accentInk : palette.textDim)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(selected ? palette.accent : palette.sunken)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                TextField("Ou une autre monture", text: optional($camera.mount))
                    .textInputAutocapitalization(.words)
                    .fieldStyle(palette)
            }
        }
    }

    /// Le champ dont dépend tout l'assistant : c'est lui qui lui permet de dire
    /// « ce réglage sort de ce que ton boîtier sait faire ».
    private var shutterRange: some View {
        FieldRow(label: "Plage de vitesses") {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel("La plus lente")
                ScaleDial(
                    values: shutterScale(including: camera.shutterSlowest),
                    label: { $0 }, selection: $camera.shutterSlowest)
                MicroLabel("La plus rapide")
                // De la plus rapide à la plus lente : sans valeur, le barillet
                // s'ouvre du côté où l'on va la chercher.
                ScaleDial(
                    values: Array(shutterScale(including: camera.shutterFastest).reversed()),
                    label: { $0 }, selection: $camera.shutterFastest)

                if rangeIsInverted {
                    Text("La plus rapide doit être plus courte que la plus lente : les deux sont probablement inversées.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                } else if camera.shutterFastest == nil && camera.shutterSlowest == nil {
                    Text("Sans plage déclarée, l’assistant ne peut pas dire qu’un réglage dépasse ce que ce boîtier sait faire. Dans le doute, laissez vide plutôt que de deviner.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// La graduation entière, plus la valeur déclarée quand elle n'y figure
    /// pas — un 1/750 ou un 1/12000 venu de la banque doit rester visible et
    /// re-sélectionnable, pas s'effacer au premier tap.
    private func shutterScale(including current: String?) -> [String] {
        guard let current, !Exposure.fullShutters.contains(current) else {
            return Exposure.fullShutters
        }
        return (Exposure.fullShutters + [current]).sorted {
            (Exposure.seconds(from: $0) ?? 0) > (Exposure.seconds(from: $1) ?? 0)
        }
    }

    /// Un posemètre intégré peut dériver avec l'âge, et l'écart est constant :
    /// on le mesure une fois contre une cellule, et on le note ici.
    private var meterBias: some View {
        FieldRow(label: "Écart du posemètre intégré") {
            VStack(alignment: .leading, spacing: 6) {
                ScaleDial(
                    values: [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2] as [Double],
                    label: { Fmt.signedStops($0) },
                    selection: $camera.meterBiasStops)
                Text("En diaphragmes, par rapport à une cellule dont vous êtes sûr. Une cellule au sélénium perd avec les années. C’est un mémo pour vous : l’assistant ne l’applique pas de lui-même.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Un boîtier qui a servi ne se supprime pas — ses rouleaux le citent. Il
    /// s'archive : il reste dans l'historique et disparaît des choix.
    @ViewBuilder
    private var retirement: some View {
        if isUsed {
            FieldRow(label: "Retrait") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $camera.archived) {
                        Text("Ne plus proposer ce boîtier")
                            .font(Typo.body)
                            .foregroundStyle(palette.text)
                    }
                    .tint(palette.accent)
                    Text("Des rouleaux ont été chargés dedans : il ne peut pas être supprimé, mais archivé il ne sera plus proposé au chargement.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Button("Supprimer ce boîtier", role: .destructive) {
                isConfirmingDeletion = true
            }
            .buttonStyle(SecondaryButtonStyle(palette: palette, tint: palette.danger))
            .padding(.top, 16)
        }
    }

    /// Un champ vide vaut « rien noté », pas une chaîne vide : c'est ce que
    /// l'export attend pour ne pas écrire de balise creuse.
    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

struct LensEditSheet: View {
    @Bindable var carnet: Carnet
    @State var lens: Model.Lens

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var isConfirmingDeletion = false

    private var trimmedName: String { lens.name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && lens.focalMin <= lens.focalMax }

    /// Les focales gravées sur les objectifs courants.
    private let focals: [Double] = [
        14, 18, 20, 21, 24, 28, 35, 40, 43, 45, 50, 55, 58, 70, 80, 85, 90, 100, 105, 135, 150, 180, 200, 210, 300,
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    FieldRow(label: "Nom") {
                        TextField("Minolta MD 50 mm f/1.7", text: $lens.name)
                            .fieldStyle(palette)
                    }

                    FieldRow(label: "Monture") {
                        TextField("Minolta SR", text: optional($lens.mount))
                            .textInputAutocapitalization(.words)
                            .fieldStyle(palette)
                    }

                    focalField

                    FieldRow(label: "Ouverture la plus grande") {
                        ScaleDial(
                            values: Fmt.including(
                                lens.maxAperture,
                                in: [1.2, 1.4, 1.7, 1.8, 2, 2.5, 2.8, 3.5, 4, 5.6] as [Double]),
                            label: { "f/\(trimmed($0))" },
                            selection: $lens.maxAperture)
                    }

                    FieldRow(label: "Ouverture la plus petite") {
                        ScaleDial(
                            values: Fmt.including(lens.minAperture, in: [11, 16, 22, 32] as [Double]),
                            label: { "f/\(trimmed($0))" },
                            selection: $lens.minAperture)
                    }

                    FieldRow(label: "Diamètre de filtre") {
                        VStack(alignment: .leading, spacing: 6) {
                            ScaleDial(
                                values: Fmt.including(
                                    lens.filterThread,
                                    in: [37, 39, 40.5, 43, 46, 49, 52, 55, 58, 62, 67, 72, 77] as [Double]),
                                label: { "⌀ \(trimmed($0))" },
                                selection: $lens.filterThread)
                            Text("Gravé sur la bague avant, après le symbole ⌀.")
                                .font(Typo.caption)
                                .foregroundStyle(palette.textFaint)
                        }
                    }

                    FieldRow(label: "Numéro de série") {
                        TextField("", text: optional($lens.serial))
                            .fieldStyle(palette)
                    }

                    FieldRow(label: "Notes") {
                        TextField("Défauts, rendu, particularités…",
                                  text: optional($lens.notes), axis: .vertical)
                            .lineLimit(2...5)
                            .fieldStyle(palette)
                    }

                    retirement
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Objectif")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    lens.name = trimmedName
                    lens.mount = lens.mount?.trimmingCharacters(in: .whitespaces)
                    if lens.mount?.isEmpty == true { lens.mount = nil }
                    lens.updatedAt = Carnet.timestamp(Date())
                    carnet.save(lens)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
                .padding(16)
                .background(palette.bg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .confirmationDialog(
                carnet.isUsed(lensId: lens.id)
                    ? "Supprimer « \(lens.name) » ? Les vues prises avec lui seront conservées, sans objectif."
                    : "Supprimer « \(lens.name) » ?",
                isPresented: $isConfirmingDeletion, titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    carnet.delete(lensId: lens.id)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    /// La focale, ou les deux bornes d'un zoom : c'est elle qui pilote la
    /// profondeur de champ et le barillet de focale à la saisie d'une vue.
    private var focalField: some View {
        FieldRow(label: lens.isPrime ? "Focale" : "Focales") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { !lens.isPrime },
                    set: { zoom in
                        lens.focalMax = zoom ? max(lens.focalMax, lens.focalMin * 2) : lens.focalMin
                    })
                ) {
                    Text("Zoom")
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)

                if !lens.isPrime { MicroLabel("La plus courte") }
                ScaleDial(
                    values: Fmt.including(lens.focalMin, in: focals),
                    label: { "\(Int($0)) mm" },
                    selection: Binding<Double?>(
                        get: { lens.focalMin },
                        set: { value in
                            guard let value else { return }
                            lens.focalMin = value
                            if lens.focalMax < value || lens.isPrime { lens.focalMax = value }
                        }))
                if !lens.isPrime {
                    MicroLabel("La plus longue")
                    ScaleDial(
                        values: Fmt.including(lens.focalMax, in: focals),
                        label: { "\(Int($0)) mm" },
                        selection: Binding<Double?>(
                            get: { lens.focalMax },
                            set: { if let value = $0, value >= lens.focalMin { lens.focalMax = value } }))
                }
            }
        }
    }

    @ViewBuilder
    private var retirement: some View {
        FieldRow(label: "Retrait") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $lens.archived) {
                    Text("Ne plus proposer cet objectif")
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)
                Text("Archivé, il reste sur les vues déjà notées mais n’est plus proposé.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
            }
        }

        Button("Supprimer cet objectif", role: .destructive) {
            isConfirmingDeletion = true
        }
        .buttonStyle(SecondaryButtonStyle(palette: palette, tint: palette.danger))
        .padding(.top, 8)
    }

    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
