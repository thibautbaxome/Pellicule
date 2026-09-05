import XCTest
@testable import PelliculeCore

/// L'import est le chemin de reprise d'un carnet existant. Ces tests
/// s'exécutent sur une sauvegarde réellement produite par le bouton d'export de
/// la première implémentation, pas sur un JSON écrit pour l'occasion : c'est ce
/// qui garantit qu'un carnet tenu avant la bascule se relit sans perte.
final class BackupTests: XCTestCase {

    private func loadFixture() throws -> Backup {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "backup-reference", withExtension: "json",
                              subdirectory: "Fixtures"),
            "la sauvegarde de référence doit être empaquetée avec les tests")
        return try Backup.decode(from: Data(contentsOf: url))
    }

    func testDecodesRealBackup() throws {
        let backup = try loadFixture()
        XCTAssertEqual(backup.format, Backup.formatName)
        XCTAssertEqual(backup.version, 1)
        XCTAssertFalse(backup.includesPhotos)
    }

    func testSummaryMatchesTheSeededCarnet() throws {
        let summary = try loadFixture().summary
        XCTAssertEqual(summary.cameras, 1)
        XCTAssertEqual(summary.lenses, 1)
        XCTAssertEqual(summary.rolls, 1)
        XCTAssertEqual(summary.frames, 2)
        XCTAssertGreaterThan(summary.films, 40, "le catalogue livré part avec la sauvegarde")
    }

    /// Le rouleau poussé de deux diaphragmes doit être reconnu comme tel.
    func testPushedRollIsUnderstood() throws {
        let backup = try loadFixture()
        let roll = try XCTUnwrap(backup.data.rolls.first)
        XCTAssertEqual(roll.label, "Pointe du Raz")
        XCTAssertEqual(roll.shotIso, 1600)
        XCTAssertEqual(roll.status, .shooting)
        XCTAssertTrue(roll.status.isOpen)

        let film = try XCTUnwrap(backup.film(id: roll.filmStockId))
        XCTAssertEqual(film.displayName, "Kodak Tri-X 400")
        XCTAssertEqual(roll.pushPullStops(boxIso: film.iso), 2, accuracy: 1e-9)
    }

    /// Les vues gardent leur ordre, leurs réglages et leur position.
    func testFramesKeepTheirSettings() throws {
        let backup = try loadFixture()
        let roll = try XCTUnwrap(backup.data.rolls.first)
        let frames = backup.frames(ofRoll: roll.id)

        XCTAssertEqual(frames.map(\.number), [1, 2])
        XCTAssertEqual(frames[0].shutter, "1/250")
        XCTAssertEqual(frames[0].aperture, 8)
        XCTAssertEqual(frames[0].subject, "Le phare dans la brume")

        // La pose longue, avec sa géolocalisation.
        XCTAssertEqual(frames[1].shutter, "8s")
        XCTAssertEqual(frames[1].shutterSeconds, 8)
        let location = try XCTUnwrap(frames[1].location)
        XCTAssertEqual(location.lat, 47.7986, accuracy: 1e-4)
        XCTAssertEqual(location.lon, -4.3719, accuracy: 1e-4)
    }

    /// Le boîtier importé porte sa plage de vitesses, donc l'assistant
    /// fonctionnera immédiatement après la reprise.
    func testImportedCameraDrivesTheAssistant() throws {
        let backup = try loadFixture()
        let camera = try XCTUnwrap(backup.data.cameras.first)
        XCTAssertEqual(camera.name, "Minolta X-300")
        XCTAssertEqual(camera.availableShutters.first, "1s")
        XCTAssertEqual(camera.availableShutters.last, "1/1000")
    }

    /// La pose longue du rouleau doit déclencher la correction de réciprocité.
    func testReciprocityAppliesToTheImportedRoll() throws {
        let backup = try loadFixture()
        let roll = try XCTUnwrap(backup.data.rolls.first)
        let film = try XCTUnwrap(backup.film(id: roll.filmStockId))
        let frame = try XCTUnwrap(backup.frames(ofRoll: roll.id).last)
        let seconds = try XCTUnwrap(frame.shutterSeconds)

        XCTAssertEqual(film.model.corrected(measured: seconds), 14.32, accuracy: 0.01)
    }

    func testSaneBackupHasNoDanglingReferences() throws {
        XCTAssertEqual(try loadFixture().danglingReferences(), [])
    }

    // MARK: - Refus

    func testRejectsForeignFile() {
        let json = Data(#"{"format":"autre-chose","version":1,"exportedAt":"","includesPhotos":false,"data":{"cameras":[],"lenses":[],"filmStocks":[],"rolls":[],"frames":[],"settings":[],"attachments":[]}}"#.utf8)
        XCTAssertThrowsError(try Backup.decode(from: json)) { error in
            XCTAssertEqual(error as? Backup.ImportError, .notABackup("autre-chose"))
        }
    }

    func testRejectsNewerFormat() {
        let json = Data(#"{"format":"pellicule-backup","version":99,"exportedAt":"","includesPhotos":false,"data":{"cameras":[],"lenses":[],"filmStocks":[],"rolls":[],"frames":[],"settings":[],"attachments":[]}}"#.utf8)
        XCTAssertThrowsError(try Backup.decode(from: json)) { error in
            XCTAssertEqual(error as? Backup.ImportError, .tooRecent(found: 99, supported: 1))
        }
    }

    /// Réencoder puis relire ne doit rien perdre : c'est ce qui rend la
    /// sauvegarde utilisable comme archive, et pas seulement comme export.
    func testRoundTripPreservesEverything() throws {
        let original = try loadFixture()
        let reread = try Backup.decode(from: original.encoded())
        XCTAssertEqual(reread.summary, original.summary)
        XCTAssertEqual(reread.data.frames.map(\.shutter), original.data.frames.map(\.shutter))
        XCTAssertEqual(reread.data.rolls.map(\.shotIso), original.data.rolls.map(\.shotIso))
    }
}
