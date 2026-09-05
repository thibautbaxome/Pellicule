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
    @State private var isImporting = false
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
            ) { _ in
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                Task { importOutcome = await restore(from: result) }
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

                Button("Exporter le carnet") {
                    exportDocument = CarnetDocument(carnet: carnet, includePhotos: includePhotos)
                    isExporting = true
                }
                .buttonStyle(SecondaryButtonStyle(palette: palette))

                Button("Importer un carnet") { isImporting = true }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))

                Text("L’import complète le carnet existant sans rien effacer : à fiche identique, la version modifiée le plus récemment l’emporte.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
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

    // MARK: - Import

    /// La lecture et le décodage se font hors du fil de l'interface : une
    /// sauvegarde avec photos pèse des dizaines de mégaoctets, et l'écran ne
    /// doit pas se figer le temps de la relire. Seule la fusion dans le carnet
    /// revient sur le fil principal.
    @MainActor
    private func restore(from result: Result<URL, Error>) async -> ImportOutcome {
        do {
            let url = try result.get()
            let backup = try await Task.detached(priority: .userInitiated) {
                // Un fichier choisi hors du bac à sable de l'application n'est
                // lisible qu'après cette demande explicite.
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                return try Backup.decode(from: Data(contentsOf: url))
            }.value
            carnet.restore(backup, mode: .merge)
            let attachments = backup.data.attachments
            let photos = await Task.detached(priority: .userInitiated) {
                PhotoStore.restore(attachments)
            }.value
            let summary = backup.summary
            return ImportOutcome(
                title: "Carnet importé",
                message: "\(summary.rolls) rouleau\(summary.rolls > 1 ? "x" : ""), "
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

    init(carnet: Carnet, includePhotos: Bool) {
        let attachments = includePhotos ? PhotoStore.attachments(for: carnet.frames) : []
        data = (try? carnet.backup(
            includingPhotos: includePhotos, attachments: attachments).encoded()) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
