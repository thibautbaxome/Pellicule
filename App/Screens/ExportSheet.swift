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
                // la seule chose sur laquelle on puisse s'appuyer.
                files = ((try? result.get()) ?? [])
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                tagged = []
                problems = []
            }
        }
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
        FieldRow(label: "Vues perdues à l’amorce") {
            VStack(alignment: .leading, spacing: 8) {
                ScaleDial(
                    values: ExifExport.plausibleOffsets(
                        fileCount: files.count, frameCount: frames.count),
                    label: { $0 == 0 ? "aucune" : "\($0)" },
                    selection: Binding<Int?>(
                        get: { offset },
                        set: { offset = $0 ?? 0 }))
                Text("Les premières poses d’un rouleau sont souvent voilées, et le laboratoire ne les numérise pas. Réglez jusqu’à ce que les sujets ci-dessous correspondent à vos images.")
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
                ForEach(pairings) { pairing in
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

            Text("Vos fichiers d’origine ne sont jamais modifiés : l’application en produit des copies annotées, que vous enregistrez où vous voulez.")
                .font(Typo.caption)
                .foregroundStyle(palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var results: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel("Prêt", colour: palette.ok)
                Text("\(tagged.count) scan\(tagged.count > 1 ? "s" : "") annoté\(tagged.count > 1 ? "s" : ""). Enregistrez-les à côté de vos originaux.")
                    .font(Typo.body)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                ShareLink(items: tagged) {
                    Text("Enregistrer les fichiers")
                        .font(Typo.ui(16, .semibold))
                        .foregroundStyle(palette.accentInk)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
                    Text("Un tableau et un script pour exiftool, à employer sur un ordinateur — pour les formats que l’application ne sait pas annoter, ou pour vérifier avant d’écrire.")
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

    private var reference: String {
        roll?.archiveRef ?? roll?.label ?? "rouleau"
    }

    // MARK: - Écriture

    private func tagFiles() {
        guard let context else { return }
        isWorking = true
        problems = []

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("scans-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let sources = Dictionary(
            uniqueKeysWithValues: files.map { ($0.lastPathComponent, $0) })
        let outcome = ScanTagger.tag(
            pairings: pairings, sources: sources, context: context,
            pattern: pattern, into: directory)

        tagged = outcome.written
        problems = outcome.failures
        isWorking = false
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
