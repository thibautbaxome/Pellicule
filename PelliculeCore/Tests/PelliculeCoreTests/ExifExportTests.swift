import XCTest
@testable import PelliculeCore

/// Les métadonnées écrites dans un scan sont vérifiées contre un CSV de
/// référence réellement produit par le bouton d'export de la première
/// implémentation, sur les mêmes données. Un négatif traité avant la bascule et
/// un négatif traité après doivent porter exactement les mêmes balises : c'est
/// ce qui permet de mélanger dans une même photothèque des scans des deux
/// époques sans qu'on les distingue.
final class ExifExportTests: XCTestCase {

    private func loadBackup() throws -> Backup {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "backup-reference", withExtension: "json",
                              subdirectory: "Fixtures"))
        return try Backup.decode(from: Data(contentsOf: url))
    }

    private func loadReferenceCSV() throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "export-reference", withExtension: "csv",
                              subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func context(from backup: Backup) throws -> ExifExport.Context {
        let roll = try XCTUnwrap(backup.data.rolls.first)
        return ExifExport.Context(
            roll: roll,
            frames: backup.frames(ofRoll: roll.id),
            film: backup.film(id: roll.filmStockId),
            camera: backup.camera(id: roll.cameraId),
            lenses: Dictionary(uniqueKeysWithValues: backup.data.lenses.map { ($0.id, $0) }))
    }

    /// Le test qui compte : la sortie doit coïncider ligne à ligne.
    func testMatchesTheReferenceExportExactly() throws {
        let produced = ExifExport.csv(ExifExport.rows(for: try context(from: loadBackup())))
        let reference = try loadReferenceCSV().trimmingCharacters(in: .whitespacesAndNewlines)

        let producedLines = produced.split(separator: "\n").map(String.init)
        let referenceLines = reference.split(separator: "\n").map(String.init)

        XCTAssertEqual(producedLines.count, referenceLines.count)
        for index in 0..<min(producedLines.count, referenceLines.count) {
            XCTAssertEqual(
                producedLines[index], referenceLines[index],
                "ligne \(index) divergente de la référence")
        }
    }

    func testColumnOrderIsPreserved() throws {
        let header = try XCTUnwrap(
            loadReferenceCSV().split(separator: "\n").map(String.init).first)
        XCTAssertEqual(header, ExifExport.columns.joined(separator: ","))
        XCTAssertEqual(ExifExport.columns.first, "SourceFile",
                       "exiftool retrouve le fichier par cette colonne")
    }

    // MARK: - Noms de fichiers

    func testFilenamePatternTokens() throws {
        let backup = try loadBackup()
        let roll = try XCTUnwrap(backup.data.rolls.first)
        let frame = try XCTUnwrap(backup.frames(ofRoll: roll.id).first)

        XCTAssertEqual(
            ExifExport.filename(pattern: "{roll}-{nn}.jpg", roll: roll, frame: frame),
            "pointe-du-raz-01.jpg")
        XCTAssertEqual(
            ExifExport.filename(pattern: "{nnn}.tif", roll: roll, frame: frame),
            "001.tif")
        XCTAssertEqual(
            ExifExport.filename(pattern: "img{n}.jpg", roll: roll, frame: frame),
            "img1.jpg")
    }

    /// Les accents et les espaces d'un libellé doivent donner un nom de
    /// fichier utilisable partout.
    func testFilenameSlugIsSafe() throws {
        let carnet = Carnet(fileURL: nil)
        let camera = carnet.makeCamera(named: "Un boîtier")
        carnet.save(camera)

        let film = try XCTUnwrap(Catalog.films.first { $0.id == "kodak-tri-x-400" })
        let roll = carnet.loadRoll(film: film, camera: camera, label: "Été à l’Île d’Yeu")
        carnet.save(roll)

        var frame = carnet.makeFrame(inRoll: roll.id)
        frame.number = 7

        XCTAssertEqual(
            ExifExport.filename(pattern: "{roll}-{nn}.jpg", roll: roll, frame: frame),
            "ete-a-l-ile-d-yeu-07.jpg")
    }

    // MARK: - Détails de conversion

    /// La longitude ouest doit sortir en valeur absolue avec sa référence.
    func testWesternLongitudeIsSplitIntoValueAndReference() throws {
        let rows = ExifExport.rows(for: try context(from: loadBackup()))
        XCTAssertEqual(rows[0]["GPSLongitude"], "4.3719")
        XCTAssertEqual(rows[0]["GPSLongitudeRef"], "W")
        XCTAssertEqual(rows[0]["GPSLatitudeRef"], "N")
    }

    /// La sensibilité employée prime sur l'ISO de la boîte : c'est elle qui
    /// décrit l'exposition réelle du négatif.
    func testShotIsoWinsOverBoxIso() throws {
        let rows = ExifExport.rows(for: try context(from: loadBackup()))
        XCTAssertEqual(rows[0]["ISO"], "1600")
        XCTAssertTrue(rows[0]["UserComment"]?.contains("Exposée à 1600 ISO") ?? false)
    }

    func testExifDateFormat() {
        XCTAssertEqual(
            ExifExport.exifDate("2026-04-18T17:32:04.000Z").count,
            "2026:04:18 17:32:04".count)
        XCTAssertEqual(ExifExport.exifDate("pas une date"), "")
    }
}
