import PelliculeCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importOutcome: ImportOutcome?

    private var theme: Theme { Theme(rawValue: carnet.settings.theme) ?? .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    themeField
                    backupSection
                    aboutSection
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Réglages")
            .fileExporter(
                isPresented: $isExporting,
                document: CarnetDocument(carnet: carnet),
                contentType: .json,
                defaultFilename: "pellicule-\(dateStamp()).json"
            ) { _ in }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                importOutcome = restore(from: result)
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

                Button("Exporter le carnet") { isExporting = true }
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

    private func restore(from result: Result<URL, Error>) -> ImportOutcome {
        do {
            let url = try result.get()
            // Un fichier choisi hors du bac à sable de l'application n'est
            // lisible qu'après cette demande explicite.
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let backup = try Backup.decode(from: Data(contentsOf: url))
            carnet.restore(backup, mode: .merge)
            let summary = backup.summary
            return ImportOutcome(
                title: "Carnet importé",
                message: "\(summary.rolls) rouleau\(summary.rolls > 1 ? "x" : ""), "
                    + "\(summary.frames) vue\(summary.frames > 1 ? "s" : ""), "
                    + "\(summary.cameras) boîtier\(summary.cameras > 1 ? "s" : "").")
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

    init(carnet: Carnet) {
        data = (try? carnet.backup(includingPhotos: false).encoded()) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
