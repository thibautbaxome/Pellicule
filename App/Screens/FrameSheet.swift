import PelliculeCore
import PhotosUI
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
    @State private var locator = Locator()
    @State private var isPickingFilter = false
    @State private var isTakingPhoto = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var referencePhoto: UIImage?
    @State private var didSave = false
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

    /// De même pour les ouvertures, bornées par l'objectif employé — ou, à
    /// défaut, par ce qu'un objectif courant permet à coup sûr.
    private var apertureRange: Carnet.ApertureRange {
        carnet.apertureRange(forCamera: camera, lensId: frame.lensId)
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
                        VStack(alignment: .leading, spacing: 6) {
                            ScaleDial(
                                values: apertureRange.values,
                                label: { "f/\(trimmed($0))" },
                                selection: $frame.aperture)
                            if apertureRange.isAssumed {
                                Text("Aucun objectif déclaré : la graduation s’arrête à ce qu’un objectif courant permet.")
                                    .font(Typo.caption)
                                    .foregroundStyle(palette.textFaint)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if !mountableLenses.isEmpty {
                        lensField
                    }
                    FieldRow(label: "Sujet") {
                        TextField("Le phare dans la brume…", text: subjectBinding)
                            .textInputAutocapitalization(.sentences)
                            .fieldStyle(palette)
                    }

                    photoField

                    DisclosureGroup(isExpanded: $showsDetails) {
                        VStack(alignment: .leading, spacing: 18) {
                            focalField
                            compensationField
                            filterField
                            flashAndDistance
                            locationField
                            meteringField
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
                    didSave = true
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .padding(16)
                .background(palette.bg)
                // Le retour haptique confirme l'enregistrement sans qu'on ait
                // à regarder l'écran : sur le terrain, on a déjà l'œil ailleurs.
                .sensoryFeedback(.success, trigger: didSave)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            // Relever la position à l'ouverture d'une vue neuve, quand le
            // réglage le demande : sur le terrain, personne ne pense à appuyer
            // sur un bouton de plus avant de passer à la photo suivante.
            .task {
                guard !isExisting, frame.location == nil,
                      carnet.settings.autoGeolocate
                else { return }
                locator.request()
            }
            .onChange(of: locator.location) { _, relevé in
                if let relevé, frame.location == nil { frame.location = relevé }
            }
            .onAppear {
                if let id = frame.refPhotoId { referencePhoto = PhotoStore.load(id) }
            }
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        attach(image)
                    }
                    pickedPhoto = nil
                }
            }
            .fullScreenCover(isPresented: $isTakingPhoto) {
                CameraCapture { image in attach(image) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $isPickingFilter) {
                FilterPickerSheet { preset in
                    frame.filter = preset.map {
                        Model.Frame.Filter(name: $0.name, factorStops: $0.stops)
                    }
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
            // Deux tirets isolés au milieu d'une carte vide se lisent comme un
            // défaut d'affichage, pas comme une invitation. Tant que rien n'est
            // choisi, la carte dit ce qu'elle attend.
            Group {
                if frame.shutter == nil && frame.aperture == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        MicroLabel("Réglages employés")
                        Text("Choisissez la vitesse et l’ouverture avec lesquelles vous avez déclenché.")
                            .font(Typo.body)
                            .foregroundStyle(palette.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        ValueText(
                            text: frame.shutter ?? "?", size: 32, weight: .bold,
                            colour: frame.shutter == nil ? palette.textFaint : palette.text)
                        Text("·")
                            .font(Typo.hero)
                            .foregroundStyle(palette.line)
                        ValueText(
                            text: frame.aperture.map { "f/\(trimmed($0))" } ?? "?",
                            size: 32, weight: .bold,
                            colour: frame.aperture == nil ? palette.textFaint : palette.text)
                        Spacer()
                    }
                }
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

    /// Où la vue a été prise. C'est ce qui permettra, des mois plus tard, de
    /// retrouver l'endroit — et de l'inscrire dans les métadonnées du scan.
    private var locationField: some View {
        FieldRow(label: "Position") {
            VStack(alignment: .leading, spacing: 8) {
                if let location = frame.location {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.accent)
                        ValueText(text: location.readable, size: 13)
                        Spacer()
                    }
                    if let accuracy = location.accuracy {
                        Text("À \(Int(accuracy)) m près.")
                            .font(Typo.caption)
                            .foregroundStyle(palette.textFaint)
                    }
                    Button("Oublier la position") {
                        frame.location = nil
                        locator.forget()
                    }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))
                } else {
                    locationPrompt
                }
            }
        }
    }

    @ViewBuilder
    private var locationPrompt: some View {
        switch locator.status {
        case .locating:
            HStack(spacing: 8) {
                ProgressView().tint(palette.accent)
                Text("Relevé en cours…")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)
            }
        case .permissionDenied:
            Text("Accès refusé. Autorisez la position dans Réglages → Pellicule pour l’inscrire dans les métadonnées du scan.")
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        case .servicesOff:
            Text("La localisation est désactivée sur cet appareil.")
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
        case .failed(let reason):
            Text("Position introuvable : \(reason)")
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        case .idle, .located:
            Button("Relever la position") { locator.request() }
                .buttonStyle(SecondaryButtonStyle(palette: palette))
        }
    }

    /// La photo de repérage : le cadrage tel qu'on l'a vu, pour reconnaître
    /// la vue trois semaines plus tard quand le rouleau revient du laboratoire.
    private var photoField: some View {
        FieldRow(label: "Photo de repérage") {
            VStack(alignment: .leading, spacing: 10) {
                if let referencePhoto {
                    Image(uiImage: referencePhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.line, lineWidth: 1))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    Button("Retirer la photo") { detachPhoto() }
                        .buttonStyle(SecondaryButtonStyle(palette: palette))
                } else {
                    HStack(spacing: 10) {
                        if CameraCapture.isAvailable {
                            Button {
                                isTakingPhoto = true
                            } label: {
                                Label("Prendre", systemImage: "camera")
                            }
                            .buttonStyle(SecondaryButtonStyle(palette: palette))
                        }
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            Label("Choisir", systemImage: "photo.on.rectangle")
                                .font(Typo.ui(16, .medium))
                                .foregroundStyle(palette.text)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(palette.lineStrong, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            }
            .animation(.snappy, value: referencePhoto == nil)
        }
    }

    private func attach(_ image: UIImage) {
        if let previous = frame.refPhotoId { PhotoStore.delete(previous) }
        guard let id = PhotoStore.save(image) else { return }
        frame.refPhotoId = id
        referencePhoto = PhotoStore.load(id)
    }

    private func detachPhoto() {
        if let id = frame.refPhotoId { PhotoStore.delete(id) }
        frame.refPhotoId = nil
        referencePhoto = nil
    }

    /// Un filtre coûte de la lumière : le noter, c'est pouvoir expliquer plus
    /// tard pourquoi une vue est plus sombre que sa voisine.
    private var filterField: some View {
        FieldRow(label: "Filtre") {
            Button {
                isPickingFilter = true
            } label: {
                HStack {
                    if let filter = frame.filter {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(filter.name)
                                .font(Typo.body)
                                .foregroundStyle(palette.text)
                            Text(filterCost(filter))
                                .font(Typo.caption)
                                .foregroundStyle(palette.accent)
                        }
                    } else {
                        Text("Aucun")
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

    private func filterCost(_ filter: Model.Frame.Filter) -> String {
        guard filter.factorStops >= 0.05 else { return "Sans coût en lumière" }
        let stops = String(format: "%.1f", filter.factorStops)
        return "Coûte \(stops) diaphragme\(filter.factorStops >= 2 ? "s" : "")"
    }

    private var flashAndDistance: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: Binding(
                get: { frame.flash ?? false },
                set: { frame.flash = $0 ? true : nil })
            ) {
                Text("Flash employé")
                    .font(Typo.body)
                    .foregroundStyle(palette.text)
            }
            .tint(palette.accent)

            FieldRow(label: "Distance de mise au point") {
                ScaleDial(
                    values: [0.5, 0.7, 1, 1.5, 2, 3, 5, 10, 20] as [Double],
                    label: { $0 < 1 ? "\(Int($0 * 100)) cm" : "\(trimmed($0)) m" },
                    selection: $frame.focusDistance)
            }
        }
    }

    /// Comment la mesure a été faite. C'est ce qui permet, en relisant un
    /// rouleau raté, de comprendre d'où venait l'erreur — et de savoir à quoi
    /// se fier la fois suivante.
    private var meteringField: some View {
        FieldRow(label: "Mesure") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(
                        ["Posemètre du boîtier", "Cellule à main", "Application", "À l’œil"],
                        id: \.self
                    ) { method in
                        let selected = frame.meteringNote == method
                        Button {
                            frame.meteringNote = selected ? nil : method
                        } label: {
                            Text(method)
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
        }
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
