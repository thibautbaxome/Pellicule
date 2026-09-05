import PelliculeCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette
    @State private var isExporting = false
    /// Construit au moment d'exporter, jamais dans `body` : encoder le carnet
    /// — et ses photos — à chaque frappe dans un champ serait absurde.
    @State private var exportDocument: CarnetDocument?
    @State private var isPreparingExport = false
    @State private var isImporting = false
    /// Le fichier choisi, en attente du choix « compléter » ou « remplacer ».
    @State private var pendingImport: URL?
    @State private var importOutcome: ImportOutcome?
    @State private var includePhotos = false

    private var theme: Theme { Theme(rawValue: carnet.settings.theme) ?? .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    statsLink
                    themeField
                    locationField
                    labField
                    backupSection
                    aboutSection
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Réglages")
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "pellicule-\(dateStamp()).json"
            ) { result in
                exportDocument = nil
                if case .failure = result {
                    importOutcome = ImportOutcome(
                        title: "Export impossible",
                        message: "Le fichier n’a pas pu être enregistré à cet endroit.")
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                guard let url = try? result.get() else { return }
                // Un carnet vide n'a rien à fusionner : on prend le fichier tel
                // quel, sans poser de question.
                if carnet.rolls.isEmpty && carnet.cameras.isEmpty && carnet.frames.isEmpty {
                    Task { importOutcome = await restore(from: url, mode: .replace) }
                } else {
                    pendingImport = url
                }
            }
            .confirmationDialog(
                "Comment reprendre cette sauvegarde ?",
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible
            ) {
                Button("Compléter le carnet") {
                    if let url = pendingImport {
                        Task { importOutcome = await restore(from: url, mode: .merge) }
                    }
                    pendingImport = nil
                }
                Button("Remplacer tout le carnet", role: .destructive) {
                    if let url = pendingImport {
                        Task { importOutcome = await restore(from: url, mode: .replace) }
                    }
                    pendingImport = nil
                }
                Button("Annuler", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Compléter ajoute ce qui manque et garde la version la plus récente de chaque fiche. Remplacer revient à la sauvegarde telle qu’elle est — exportez d’abord le carnet actuel si vous voulez pouvoir y revenir.")
            }
            .alert(
                importOutcome?.title ?? "",
                isPresented: Binding(
                    get: { importOutcome != nil },
                    set: { if !$0 { importOutcome = nil } }),
                presenting: importOutcome
            ) { _ in
                Button("Entendu", role: .cancel) {}
            } message: { outcome in
                Text(outcome.message)
            }
        }
    }

    private var statsLink: some View {
        NavigationLink {
            StatsScreen(carnet: carnet)
        } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Statistiques")
                            .font(Typo.heading)
                            .foregroundStyle(palette.text)
                        Text("\(carnet.rolls.count) rouleau\(carnet.rolls.count > 1 ? "x" : ""), \(carnet.frames.count) vue\(carnet.frames.count > 1 ? "s" : "")")
                            .font(Typo.caption)
                            .foregroundStyle(palette.textDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textFaint)
                }
            }
        }
        .buttonStyle(PressableCardStyle())
        // Une carte à deux lignes s'annonce sinon en récitant les deux : le nom
        // du choix se perd dans le résumé.
        .accessibilityLabel("Statistiques")
        .accessibilityHint("\(carnet.rolls.count) rouleau\(carnet.rolls.count > 1 ? "x" : ""), \(carnet.frames.count) vue\(carnet.frames.count > 1 ? "s" : "")")
    }

    private var themeField: some View {
        FieldRow(label: "Apparence") {
            VStack(spacing: 8) {
                ForEach(Theme.allCases) { candidate in
                    SelectableRow(
                        title: candidate.label,
                        detail: candidate == .darkroom
                            ? "Tout en rouge sombre, pour ne pas voiler de papier ni casser la vision nocturne"
                            : nil,
                        isSelected: candidate == theme
                    ) {
                        var updated = carnet.settings
                        updated.theme = candidate.rawValue
                        carnet.save(updated)
                    }
                }
            }
        }
    }

    /// Le relevé automatique se coupe : une autorisation qu'on ne peut pas
    /// refuser sans désactiver la fonction n'en est pas une.
    private var locationField: some View {
        FieldRow(label: "Position") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { carnet.settings.autoGeolocate },
                    set: { value in
                        var updated = carnet.settings
                        updated.autoGeolocate = value
                        carnet.save(updated)
                    })
                ) {
                    Text("Relever la position à chaque vue")
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)

                Text("La position sert à retrouver un lieu des mois plus tard, et s’inscrit dans les métadonnées du scan. Elle ne quitte pas le téléphone. Décoché, elle reste relevable à la main sur chaque vue.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Le laboratoire habituel, repris à chaque nouveau rouleau : on en change
    /// rarement, et le ressaisir à chaque fois finit par ne plus être saisi.
    private var labField: some View {
        FieldRow(label: "Laboratoire habituel") {
            TextField("Proposé à chaque nouveau rouleau", text: Binding(
                get: { carnet.settings.defaultLab ?? "" },
                set: { value in
                    var updated = carnet.settings
                    updated.defaultLab = value.isEmpty ? nil : value
                    carnet.save(updated)
                }))
                .fieldStyle(palette)
        }
    }

    private var backupSection: some View {
        FieldRow(label: "Sauvegarde") {
            VStack(alignment: .leading, spacing: 10) {
                Text("""
                    Le carnet est un simple fichier, qui vous appartient. L’exporter \
                    en produit une copie à déposer où bon vous semble — iCloud Drive, \
                    un courriel à vous-même, une clé.
                    """)
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)

                Toggle(isOn: $includePhotos) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avec les photos de repérage")
                            .font(Typo.body)
                            .foregroundStyle(palette.text)
                        Text("Le fichier devient beaucoup plus gros. Sans elles, il reste minuscule et se relit en un instant.")
                            .font(Typo.caption)
                            .foregroundStyle(palette.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(palette.accent)

                Button(isPreparingExport ? "Préparation…" : "Exporter le carnet") {
                    prepareExport()
                }
                .buttonStyle(SecondaryButtonStyle(palette: palette))
                .disabled(isPreparingExport)

                Button("Importer un carnet") { isImporting = true }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))

                Text("L’import propose de compléter le carnet — à fiche identique, la version modifiée le plus récemment l’emporte — ou de le remplacer entièrement par la sauvegarde.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aboutSection: some View {
        FieldRow(label: "À propos") {
            VStack(alignment: .leading, spacing: 10) {
                SprocketRule(holes: 12).frame(width: 150)
                summaryLine("Boîtiers", carnet.cameras.count)
                summaryLine("Objectifs", carnet.lenses.count)
                summaryLine("Rouleaux", carnet.rolls.count)
                summaryLine("Vues", carnet.frames.count)
                summaryLine("Banque de boîtiers", Catalog.cameras.count)
                summaryLine("Banque de pellicules", Catalog.films.count)

                Text("""
                    Aucun compte, aucun serveur, aucune donnée transmise. \
                    Pellicule est un logiciel libre sous licence MIT.
                    """)
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, 6)
            }
        }
    }

    private func summaryLine(_ label: String, _ count: Int) -> some View {
        HStack {
            MicroLabel(label)
            Spacer()
            ValueText(text: "\(count)", size: 14, colour: palette.textDim)
        }
    }

    // MARK: - Export

    /// Le document se construit hors du fil de l'interface : avec les photos,
    /// c'est des dizaines de mégaoctets à lire et à encoder, et l'écran ne
    /// doit pas se figer pendant ce temps.
    private func prepareExport() {
        isPreparingExport = true
        let frames = carnet.frames
        let include = includePhotos
        Task {
            let attachments = await Task.detached(priority: .userInitiated) {
                include ? PhotoStore.attachments(for: frames) : []
            }.value
            let data = try? carnet.backup(includingPhotos: include, attachments: attachments).encoded()
            isPreparingExport = false
            guard let data else {
                importOutcome = ImportOutcome(
                    title: "Export impossible",
                    message: "Le carnet n’a pas pu être encodé. Vérifiez qu’aucun montant saisi n’est aberrant.")
                return
            }
            exportDocument = CarnetDocument(data: data)
            isExporting = true
        }
    }

    // MARK: - Import

    /// La lecture et le décodage se font hors du fil de l'interface : une
    /// sauvegarde avec photos pèse des dizaines de mégaoctets, et l'écran ne
    /// doit pas se figer le temps de la relire. Seule la fusion dans le carnet
    /// revient sur le fil principal.
    @MainActor
    private func restore(from url: URL, mode: Carnet.RestoreMode) async -> ImportOutcome {
        do {
            let backup = try await Task.detached(priority: .userInitiated) {
                // Un fichier choisi hors du bac à sable de l'application n'est
                // lisible qu'après cette demande explicite.
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                return try Backup.decode(from: Data(contentsOf: url))
            }.value
            carnet.restore(backup, mode: mode)
            // Seules les photos que le carnet désigne encore : une vue écartée
            // par la fusion ne doit pas laisser sa photo orpheline sur le disque.
            let referenced = Set(carnet.frames.compactMap(\.refPhotoId))
            let attachments = backup.data.attachments.filter { referenced.contains($0.id) }
            let photos = await Task.detached(priority: .userInitiated) {
                PhotoStore.restore(attachments)
            }.value
            let summary = backup.summary
            return ImportOutcome(
                title: mode == .replace ? "Carnet remplacé" : "Carnet complété",
                message: "La sauvegarde contenait \(summary.rolls) rouleau\(summary.rolls > 1 ? "x" : ""), "
                    + "\(summary.frames) vue\(summary.frames > 1 ? "s" : ""), "
                    + "\(summary.cameras) boîtier\(summary.cameras > 1 ? "s" : "")"
                    + (photos > 0 ? ", \(photos) photo\(photos > 1 ? "s" : "")." : "."))
        } catch let error as Backup.ImportError {
            return ImportOutcome(title: "Import impossible", message: error.description)
        } catch {
            return ImportOutcome(
                title: "Import impossible",
                message: "Le fichier n’a pas pu être lu.")
        }
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct ImportOutcome: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Le carnet exporté : c'est le fichier de stockage lui-même, pas une
/// conversion. Les deux formats sont le même.
struct CarnetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private let data: Data

    /// Le contenu est encodé par l'appelant, hors du fil de l'interface.
    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
