import PelliculeCore
import SwiftUI
import UniformTypeIdentifiers

/// Rendre aux scans ce que le laboratoire leur a retiré.
///
/// Un scan arrive nu : aucune date de prise de vue, aucun boîtier, aucun
/// réglage — le fichier est daté du jour de la numérisation, ce qui range vos
/// photos d'été au mois de novembre. Cet écran leur restitue le carnet.
///
/// Le seul point délicat est le rapprochement : le laboratoire numérote à
/// partir de la première image exploitable, le carnet à partir de la première
/// vue déclenchée, et les deux ou trois poses gâchées à l'amorce creusent un
/// décalage que rien ne permet de deviner. On le règle à la main, et l'écran
/// montre aussitôt à quoi il aboutit — c'est le sujet qui tranche, pas un
/// algorithme.
struct ExportSheet: View {
    @Bindable var carnet: Carnet
    let rollId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var files: [URL] = []
    @State private var offset = 0
    @State private var pattern = ExifExport.defaultFilenamePattern
    @State private var isPicking = false
    @State private var tagged: [URL] = []
    @State private var problems: [String] = []
    @State private var isWorking = false
    @State private var isSavingCopies = false
    /// Chaque écriture repart d'un dossier neuf ; le précédent est effacé, sans
    /// quoi trente TIFF de scanner par essai de décalage s'empileraient.
    @State private var outputDirectory: URL?

    private var roll: Model.Roll? { carnet.roll(id: rollId) }
    private var frames: [Model.Frame] { carnet.frames(ofRoll: rollId) }

    private var context: ExifExport.Context? {
        guard let roll else { return nil }
        return ExifExport.Context(
            roll: roll,
            frames: frames,
            film: carnet.film(id: roll.filmStockId),
            camera: carnet.camera(id: roll.cameraId),
            lenses: Dictionary(uniqueKeysWithValues: carnet.lenses.map { ($0.id, $0) }))
    }

    private var pairings: [ExifExport.Pairing] {
        ExifExport.pair(
            files: files.map(\.lastPathComponent), with: frames, offset: offset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if frames.isEmpty {
                        EmptyState(
                            title: "Aucune vue notée",
                            message: "Il n’y a rien à inscrire dans les scans tant que le rouleau est vide.")
                    } else {
                        intro
                        filePicker
                        if !files.isEmpty {
                            offsetPicker
                            preview
                            actions
                        }
                        if !tagged.isEmpty { results }
                        if !problems.isEmpty { failures }
                        fallback
                    }
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Vers les scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPicking,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                // L'ordre du laboratoire est celui des noms de fichiers : c'est
                // la seule chose sur laquelle on puisse s'appuyer. Tri
                // numérique, comme le Finder : « IMG_2 » avant « IMG_10 »,
                // même quand le laboratoire n'a pas complété par des zéros.
                files = ((try? result.get()) ?? [])
                    .sorted {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                            == .orderedAscending
                    }
                discardOutput()
            }
            // Directement dans Fichiers, à côté des originaux : une feuille de
            // partage ferait deviner « Enregistrer dans Fichiers » à un débutant.
            .fileExporter(
                isPresented: $isSavingCopies,
                items: tagged,
                contentTypes: [.image]
            ) { _ in }
            .onDisappear { discardOutput() }
        }
    }

    /// Les copies déjà écrites ne valent plus rien dès que la sélection ou le
    /// décalage change : l'aperçu montrerait un rapprochement, le bouton en
    /// livrerait un autre.
    private func discardOutput() {
        tagged = []
        problems = []
        if let outputDirectory {
            try? FileManager.default.removeItem(at: outputDirectory)
        }
        outputDirectory = nil
    }

    private var intro: some View {
        Text("Un scan de laboratoire n’a ni date de prise de vue, ni boîtier, ni réglages : il porte la date de sa numérisation, ce qui range vos photos d’été au mois de novembre. L’application y inscrit le carnet.")
            .font(Typo.caption)
            .foregroundStyle(palette.textDim)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var filePicker: some View {
        FieldRow(label: "Les scans") {
            VStack(alignment: .leading, spacing: 8) {
                Button(files.isEmpty ? "Choisir les fichiers" : "Choisir d’autres fichiers") {
                    isPicking = true
                }
                .buttonStyle(SecondaryButtonStyle(palette: palette))
                .disabled(isWorking)

                if !files.isEmpty {
                    ValueText(
                        text: "\(files.count) fichier\(files.count > 1 ? "s" : "")",
                        size: 13, colour: palette.textDim)
                }
            }
        }
    }

    /// Le décalage entre la numérotation du laboratoire et celle du carnet.
    private var offsetPicker: some View {
        FieldRow(label: "Poses perdues à l’amorce") {
            VStack(alignment: .leading, spacing: 8) {
                ScaleDial(
                    values: ExifExport.plausibleOffsets(
                        fileCount: files.count, frameCount: frames.count),
                    label: { $0 == 0 ? "aucune" : "\($0)" },
                    selection: Binding<Int?>(
                        get: { offset },
                        set: { value in
                            guard let value, value != offset else { return }
                            offset = value
                            discardOutput()
                        }))
                .disabled(isWorking)
                Text("Les premières poses d’un rouleau sont souvent voilées, et le laboratoire ne les numérise pas. Réglez jusqu’à ce que les sujets ci-dessous correspondent à vos images. Si ce sont les premiers scans qui n’ont pas de vue, ne les sélectionnez pas.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// L'aperçu du rapprochement : c'est en le lisant que le photographe
    /// reconnaît, ou non, ses propres photos.
    private var preview: some View {
        FieldRow(label: "Ce qui sera inscrit") {
            VStack(spacing: 6) {
                ForEach(Array(pairings.enumerated()), id: \.offset) { _, pairing in
                    HStack(alignment: .top, spacing: 10) {
                        ValueText(
                            text: pairing.fileName, size: 12,
                            colour: pairing.isOrphan ? palette.textFaint : palette.text)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let frame = pairing.frame {
                            VStack(alignment: .trailing, spacing: 2) {
                                ValueText(
                                    text: "vue \(frame.number)", size: 12, colour: palette.accent)
                                if let subject = frame.subject, !subject.isEmpty {
                                    Text(subject)
                                        .font(Typo.caption)
                                        .foregroundStyle(palette.textDim)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            MicroLabel("sans vue", colour: palette.danger)
                        }
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(isWorking ? "Écriture…" : "Écrire dans des copies") { tagFiles() }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .disabled(isWorking || pairings.allSatisfy(\.isOrphan))

            Text("Vos fichiers d’origine ne sont jamais modifiés : l’application en produit des copies annotées, nommées « \(reference)-01 », « \(reference)-02 »…, que vous enregistrez où vous voulez.")
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var results: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel("Prêt", colour: palette.ok)
                Text("\(tagged.count) scan\(tagged.count > 1 ? "s" : "") annoté\(tagged.count > 1 ? "s" : ""). Choisissez le dossier de vos scans : les copies s’y rangeront à côté des originaux.")
                    .font(Typo.body)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Enregistrer dans Fichiers") { isSavingCopies = true }
                    .buttonStyle(PrimaryButtonStyle(palette: palette))
                ShareLink(items: tagged) {
                    Text("Ou partager autrement")
                        .font(Typo.ui(16, .medium))
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.lineStrong, lineWidth: 1))
                }
            }
        }
    }

    private var failures: some View {
        AdviceCard(advice: Assistant.Advice(
            level: .warning,
            title: "Certains fichiers ont résisté",
            detail: problems.joined(separator: " ")))
    }

    /// Pour les formats que l'application ne sait pas annoter — TIFF de
    /// scanner, DNG — et pour qui préfère voir ce qui sera écrit avant que ça
    /// le soit.
    @ViewBuilder
    private var fallback: some View {
        if let context {
            let rows = ExifExport.rows(for: context, pattern: pattern)
            FieldRow(label: "Autrement") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Un tableau et un script pour exiftool, à employer sur un ordinateur — pour les fichiers bruts (DNG, RAW) que l’application ne sait pas annoter, ou pour vérifier avant d’écrire.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    ShareLink(
                        item: TextFile(
                            name: "pellicule-\(reference).csv",
                            contents: ExifExport.csv(rows)),
                        preview: SharePreview("Tableau des métadonnées")
                    ) {
                        Text("Le tableau")
                            .font(Typo.ui(16, .medium))
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette.lineStrong, lineWidth: 1))
                    }
                    ShareLink(
                        item: TextFile(
                            name: "pellicule-\(reference).sh",
                            contents: ExifExport.script(rows: rows)),
                        preview: SharePreview("Script exiftool")
                    ) {
                        Text("Le script")
                            .font(Typo.ui(16, .medium))
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette.lineStrong, lineWidth: 1))
                    }
                }
            }
        }
    }

    /// La référence d'archive, rendue sûre pour un nom de fichier : elle est
    /// saisie librement, et « 2026/014 » ne peut pas nommer un fichier.
    private var reference: String {
        ExifExport.fileToken(roll?.archiveRef ?? roll?.label ?? "rouleau")
    }

    // MARK: - Écriture

    private func tagFiles() {
        guard let context else { return }
        discardOutput()
        isWorking = true

        let pairings = pairings
        let pattern = pattern
        // Deux fichiers du même nom, venus de deux dossiers : le premier
        // l'emporte. Une clé en double planterait l'application.
        let sources = Dictionary(
            files.map { ($0.lastPathComponent, $0) },
            uniquingKeysWith: { first, _ in first })
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("scans-\(UUID().uuidString)")
        outputDirectory = directory

        // Ré-encoder trente scans n'a rien à faire sur le fil de l'interface :
        // le bouton dit « Écriture… », il faut qu'on ait le temps de le lire.
        Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let outcome = ScanTagger.tag(
                pairings: pairings, sources: sources, context: context,
                pattern: pattern, into: directory)
            await MainActor.run {
                // La sélection a changé pendant l'écriture : ce résultat ne
                // décrit plus ce que l'écran montre.
                guard outputDirectory == directory else {
                    try? FileManager.default.removeItem(at: directory)
                    isWorking = false
                    return
                }
                tagged = outcome.written
                problems = outcome.failures
                isWorking = false
            }
        }
    }
}

/// Un fichier texte à partager sans passer par le disque de l'utilisateur.
struct TextFile: Transferable {
    let name: String
    let contents: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(file.name)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
