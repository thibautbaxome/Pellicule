import PelliculeCore
import SwiftUI

/// Saisie d'une vue.
///
/// C'est l'écran le plus utilisé de l'application, et le seul qu'on manipule
/// debout, l'appareil dans l'autre main. D'où le parti pris : l'essentiel —
/// vitesse et ouverture — d'abord et en grand, le reste replié.
struct FrameSheet: View {
    @Bindable var carnet: Carnet
    @State var frame: Model.Frame

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var showsDetails = false
    @State private var isPickingLens = false
    @State private var isConfirmingDeletion = false

    private var roll: Model.Roll? { carnet.roll(id: frame.rollId) }
    private var camera: Model.Camera? { roll.flatMap { carnet.camera(id: $0.cameraId) } }
    private var isExisting: Bool { carnet.frames.contains { $0.id == frame.id } }

    /// Les vitesses proposées sont celles du boîtier déclaré, pas la graduation
    /// complète : proposer un 1/4000 sur un boîtier qui plafonne à 1/1000 est
    /// la meilleure façon de noter un réglage qui n'a jamais existé.
    private var shutters: [String] {
        let available = camera?.availableShutters ?? []
        // De la plus rapide à la plus lente : c'est l'ordre de la molette.
        return Array((available.isEmpty ? Exposure.fullShutters : available).reversed())
    }

    /// De même pour les ouvertures, bornées par l'objectif employé.
    private var apertures: [Double] {
        let lens = frame.lensId.flatMap { carnet.lens(id: $0) }
        let widest = lens?.maxAperture ?? camera?.fixedLens?.maxAperture
        let narrowest = lens?.minAperture ?? camera?.fixedLens?.minAperture
        return Exposure.fullApertures.filter { value in
            if let widest, value < widest - 0.01 { return false }
            if let narrowest, value > narrowest + 0.01 { return false }
            return true
        }
    }

    private var mountableLenses: [Model.Lens] {
        camera.map { carnet.lenses(forCamera: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    exposureSummary
                    FieldRow(label: "Vitesse") {
                        ScaleDial(values: shutters, label: { $0 }, selection: $frame.shutter)
                    }
                    FieldRow(label: "Ouverture") {
                        ScaleDial(
                            values: apertures, label: { "f/\(trimmed($0))" },
                            selection: $frame.aperture)
                    }
                    if !mountableLenses.isEmpty {
                        lensField
                    }
                    FieldRow(label: "Sujet") {
                        TextField("Le phare dans la brume…", text: subjectBinding)
                            .textInputAutocapitalization(.sentences)
                            .fieldStyle(palette)
                    }

                    DisclosureGroup(isExpanded: $showsDetails) {
                        VStack(alignment: .leading, spacing: 18) {
                            focalField
                            compensationField
                            FieldRow(label: "Notes") {
                                TextField("Mesure, lumière, intention…", text: notesBinding, axis: .vertical)
                                    .lineLimit(2...5)
                                    .fieldStyle(palette)
                            }
                            statusField
                        }
                        .padding(.top, 14)
                    } label: {
                        MicroLabel("Plus de détails", colour: palette.accent)
                    }
                    .tint(palette.accent)

                    if isExisting {
                        Button("Supprimer cette vue", role: .destructive) {
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
            .navigationTitle("Vue \(frame.number)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    frame.updatedAt = Carnet.timestamp(Date())
                    carnet.save(frame)
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
            .sheet(isPresented: $isPickingLens) {
                LensPickerSheet(mount: camera?.mount) { entry in
                    let lens = carnet.makeLens(from: entry)
                    carnet.save(lens)
                    frame.lensId = lens.id
                }
            }
            .confirmationDialog(
                "Supprimer la vue \(frame.number) ?",
                isPresented: $isConfirmingDeletion, titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    carnet.delete(frameId: frame.id)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    /// Le couple lu à bout de bras, épinglé en haut : c'est la seule chose
    /// qu'on vérifie avant de déclencher.
    private var exposureSummary: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                ValueText(
                    text: frame.shutter ?? "—", size: 32, weight: .bold,
                    colour: frame.shutter == nil ? palette.textFaint : palette.text)
                Text("·")
                    .font(Typo.hero)
                    .foregroundStyle(palette.line)
                ValueText(
                    text: frame.aperture.map { "f/\(trimmed($0))" } ?? "—", size: 32, weight: .bold,
                    colour: frame.aperture == nil ? palette.textFaint : palette.text)
                Spacer()
            }
        }
    }

    private var lensField: some View {
        FieldRow(label: "Objectif") {
            VStack(spacing: 8) {
                ForEach(mountableLenses) { lens in
                    SelectableRow(
                        title: lens.name,
                        detail: lens.isPrime
                            ? "\(Int(lens.focalMin)) mm"
                            : "\(Int(lens.focalMin))–\(Int(lens.focalMax)) mm",
                        isSelected: lens.id == frame.lensId
                    ) {
                        frame.lensId = frame.lensId == lens.id ? nil : lens.id
                    }
                }
                Button("Ajouter un objectif") { isPickingLens = true }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))
            }
        }
    }

    /// La focale n'est demandée que pour un zoom : sur une focale fixe elle se
    /// déduit de l'objectif, et la saisir serait du bruit.
    @ViewBuilder
    private var focalField: some View {
        if let lens = frame.lensId.flatMap({ carnet.lens(id: $0) }), !lens.isPrime {
            FieldRow(label: "Focale employée") {
                ScaleDial(
                    values: focalChoices(from: lens),
                    label: { "\(Int($0)) mm" },
                    selection: $frame.focal)
            }
        }
    }

    private func focalChoices(from lens: Model.Lens) -> [Double] {
        // Les graduations gravées sur une bague de zoom, ni plus ni moins.
        let marks: [Double] = [24, 28, 35, 50, 70, 85, 105, 135, 200, 300]
        let inRange = marks.filter { $0 >= lens.focalMin && $0 <= lens.focalMax }
        return inRange.isEmpty ? [lens.focalMin, lens.focalMax] : inRange
    }

    private var compensationField: some View {
        FieldRow(label: "Correction d’exposition") {
            ScaleDial(
                values: [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2] as [Double],
                label: { $0 > 0 ? "+\(trimmed($0))" : trimmed($0) },
                selection: $frame.exposureComp)
        }
    }

    private var statusField: some View {
        FieldRow(label: "Sort de la vue") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Model.FrameStatus.allCases, id: \.self) { status in
                        Button {
                            frame.status = status
                        } label: {
                            Text(status.label)
                                .font(Typo.caption)
                                .foregroundStyle(
                                    status == frame.status ? palette.accentInk : palette.textDim)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    status == frame.status ? palette.accent : palette.sunken)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Liaisons

    /// Un champ de texte vide vaut « rien noté », pas une chaîne vide : c'est
    /// ce que l'export attend pour ne pas écrire de balise creuse.
    private var subjectBinding: Binding<String> {
        Binding(
            get: { frame.subject ?? "" },
            set: { frame.subject = $0.isEmpty ? nil : $0 })
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { frame.notes ?? "" },
            set: { frame.notes = $0.isEmpty ? nil : $0 })
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
