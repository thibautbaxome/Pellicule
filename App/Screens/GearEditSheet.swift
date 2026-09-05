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

    private var shutters: [String] { Exposure.fullShutters }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    FieldRow(label: "Nom") {
                        TextField("Minolta X-300", text: $camera.name)
                            .textInputAutocapitalization(.words)
                            .fieldStyle(palette)
                    }

                    FieldRow(label: "Monture") {
                        TextField(
                            "Minolta SR", text: optional($camera.mount))
                            .textInputAutocapitalization(.words)
                            .fieldStyle(palette)
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

                    if !carnet.isUsed(cameraId: camera.id) {
                        Button("Supprimer ce boîtier", role: .destructive) {
                            isConfirmingDeletion = true
                        }
                        .buttonStyle(SecondaryButtonStyle(palette: palette))
                        .foregroundStyle(palette.danger)
                        .padding(.top, 16)
                    }
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Boîtier")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    camera.updatedAt = Carnet.timestamp(Date())
                    carnet.save(camera)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
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

    /// Le champ dont dépend tout l'assistant : c'est lui qui lui permet de dire
    /// « ce réglage sort de ce que ton boîtier sait faire ».
    private var shutterRange: some View {
        FieldRow(label: "Plage de vitesses") {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel("La plus lente")
                ScaleDial(
                    values: shutters, label: { $0 }, selection: $camera.shutterSlowest)
                MicroLabel("La plus rapide")
                ScaleDial(
                    values: shutters, label: { $0 },
                    selection: $camera.shutterFastest)

                if let fastest = camera.shutterFastest, let slowest = camera.shutterSlowest,
                   let f = Exposure.seconds(from: fastest), let s = Exposure.seconds(from: slowest),
                   f >= s {
                    Text("La plus rapide doit être plus courte que la plus lente : les deux sont probablement inversées.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                } else if camera.availableShutters.isEmpty {
                    Text("Sans plage déclarée, l’assistant ne peut pas dire qu’un réglage dépasse ce que ce boîtier sait faire. Dans le doute, laissez vide plutôt que de deviner.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Un posemètre intégré peut dériver avec l'âge, et l'écart est constant :
    /// on le mesure une fois contre une cellule, et on le note ici.
    private var meterBias: some View {
        FieldRow(label: "Écart du posemètre intégré") {
            VStack(alignment: .leading, spacing: 6) {
                ScaleDial(
                    values: [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2] as [Double],
                    label: { $0 == 0 ? "0" : ($0 > 0 ? "+\($0)" : "\($0)") },
                    selection: $camera.meterBiasStops)
                Text("En diaphragmes, par rapport à une cellule dont vous êtes sûr. Une cellule au sélénium perd avec les années.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Un champ vide vaut « rien noté », pas une chaîne vide : c'est ce que
    /// l'export attend pour ne pas écrire de balise creuse.
    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

struct LensEditSheet: View {
    @Bindable var carnet: Carnet
    @State var lens: Model.Lens

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    FieldRow(label: "Nom") {
                        TextField("Minolta MD 50mm f/1.7", text: $lens.name)
                            .fieldStyle(palette)
                    }

                    FieldRow(label: "Monture") {
                        TextField("Minolta SR", text: optional($lens.mount))
                            .textInputAutocapitalization(.words)
                            .fieldStyle(palette)
                    }

                    FieldRow(label: "Ouverture la plus grande") {
                        ScaleDial(
                            values: [1.2, 1.4, 1.7, 1.8, 2, 2.5, 2.8, 3.5, 4, 5.6] as [Double],
                            label: { "f/\(trimmed($0))" },
                            selection: $lens.maxAperture)
                    }

                    FieldRow(label: "Ouverture la plus petite") {
                        ScaleDial(
                            values: [11, 16, 22, 32] as [Double],
                            label: { "f/\(trimmed($0))" },
                            selection: $lens.minAperture)
                    }

                    FieldRow(label: "Diamètre de filtre") {
                        VStack(alignment: .leading, spacing: 6) {
                            ScaleDial(
                                values: [37, 40.5, 43, 46, 49, 52, 55, 58, 62, 67, 72, 77] as [Double],
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

                    Button("Supprimer cet objectif", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))
                    .foregroundStyle(palette.danger)
                    .padding(.top, 16)
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Objectif")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    lens.updatedAt = Carnet.timestamp(Date())
                    carnet.save(lens)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
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
                    ? "Supprimer « \(lens.name) » ? Les vues prises avec seront conservées, sans objectif."
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

    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
