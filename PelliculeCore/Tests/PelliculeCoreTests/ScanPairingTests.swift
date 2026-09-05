import XCTest
@testable import PelliculeCore

/// Le rapprochement des scans avec les vues.
///
/// Le laboratoire numérote à partir de la première image exploitable ; le
/// carnet, à partir de la première vue déclenchée. Les deux ou trois poses
/// gâchées à l'amorce creusent un décalage que rien ne permet de deviner — et
/// se tromper d'un rang attribue à chaque photo les réglages de la précédente.
final class ScanPairingTests: XCTestCase {

    private let carnet = Carnet(fileURL: nil)

    private func roll(frames count: Int) -> (Model.Roll, [Model.Frame]) {
        let camera = carnet.makeCamera(named: "Boîtier")
        carnet.save(camera)
        let film = Catalog.films.first { $0.id == "kodak-tri-x-400" }!
        let roll = carnet.loadRoll(film: film, camera: camera, label: "Essai")
        carnet.save(roll)
        for index in 1...count {
            var frame = carnet.makeFrame(inRoll: roll.id)
            frame.subject = "Vue \(index)"
            carnet.save(frame)
        }
        return (roll, carnet.frames(ofRoll: roll.id))
    }

    private func files(_ count: Int) -> [String] {
        (1...count).map { String(format: "scan-%03d.jpg", $0) }
    }

    /// Sans amorce gâchée, le premier fichier est la première vue.
    func testWithoutOffsetTheFirstFileIsTheFirstFrame() {
        let (_, frames) = roll(frames: 5)
        let pairs = ExifExport.pair(files: files(5), with: frames, offset: 0)

        XCTAssertEqual(pairs.count, 5)
        XCTAssertEqual(pairs[0].frame?.number, 1)
        XCTAssertEqual(pairs[4].frame?.number, 5)
        XCTAssertFalse(pairs.contains(where: \.isOrphan))
    }

    /// Le cas réel : trois vues perdues à l'amorce, le laboratoire n'en rend
    /// que les suivantes.
    func testAWastedLeaderShiftsEverything() {
        let (_, frames) = roll(frames: 10)
        let pairs = ExifExport.pair(files: files(7), with: frames, offset: 3)

        XCTAssertEqual(pairs[0].frame?.number, 4, "le premier scan est la quatrième vue")
        XCTAssertEqual(pairs[0].frame?.subject, "Vue 4")
        XCTAssertEqual(pairs[6].frame?.number, 10)
        XCTAssertFalse(pairs.contains(where: \.isOrphan))
    }

    /// Plus de fichiers que de vues restantes : les derniers n'ont pas de vue,
    /// et cela doit se voir plutôt que de s'attribuer n'importe quoi.
    func testExtraFilesAreLeftOrphanRatherThanMisassigned() {
        let (_, frames) = roll(frames: 4)
        let pairs = ExifExport.pair(files: files(6), with: frames, offset: 2)

        XCTAssertEqual(pairs[0].frame?.number, 3)
        XCTAssertEqual(pairs[1].frame?.number, 4)
        XCTAssertTrue(pairs[2].isOrphan)
        XCTAssertTrue(pairs[3].isOrphan)
        XCTAssertEqual(pairs.filter(\.isOrphan).count, 4)
    }

    /// L'ordre des fichiers est celui du laboratoire, quel que soit celui dans
    /// lequel ils arrivent : c'est l'appelant qui trie, mais le rapprochement
    /// doit respecter la position, pas le nom.
    func testPairingFollowsPositionNotName() {
        let (_, frames) = roll(frames: 3)
        let pairs = ExifExport.pair(
            files: ["b.jpg", "a.jpg", "c.jpg"], with: frames, offset: 0)
        XCTAssertEqual(pairs.map(\.fileName), ["b.jpg", "a.jpg", "c.jpg"])
        XCTAssertEqual(pairs.map { $0.frame?.number }, [1, 2, 3])
    }

    /// Les vues sont rapprochées dans l'ordre de leur numéro, même si le carnet
    /// les rend dans un autre.
    func testFramesAreOrderedByNumber() {
        let (_, frames) = roll(frames: 4)
        let shuffled = frames.reversed().map { $0 }
        let pairs = ExifExport.pair(files: files(4), with: shuffled, offset: 0)
        XCTAssertEqual(pairs.map { $0.frame?.number }, [1, 2, 3, 4])
    }

    func testOffsetsOfferedStayReasonable() {
        XCTAssertEqual(ExifExport.plausibleOffsets(fileCount: 30, frameCount: 36), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(ExifExport.plausibleOffsets(fileCount: 3, frameCount: 2), [0, 1])
        XCTAssertEqual(ExifExport.plausibleOffsets(fileCount: 0, frameCount: 0), [0])
    }

    // MARK: - Script exiftool

    func testScriptQuotesEverythingItPasses() {
        let rows = [[
            "SourceFile": "l'été.jpg",
            "ImageDescription": "Un sujet avec une apostrophe : l'aube",
            "FNumber": "8",
        ]]
        let script = ExifExport.script(rows: rows)

        XCTAssertTrue(script.hasPrefix("#!/bin/sh"))
        XCTAssertTrue(script.contains("exiftool "))
        // Une apostrophe doit sortir de la chaîne puis y rentrer, sans quoi le
        // shell coupe la commande au milieu d'un nom de fichier.
        XCTAssertTrue(script.contains("'l'\\''été.jpg'"), script)
        XCTAssertFalse(script.contains("-SourceFile="), "le fichier est l'argument, pas une balise")
    }

    func testScriptSkipsEmptyValuesAndFilelessRows() {
        let script = ExifExport.script(rows: [
            ["SourceFile": "a.jpg", "FNumber": "8", "LensModel": ""],
            ["SourceFile": "", "FNumber": "11"],
        ])
        XCTAssertTrue(script.contains("-FNumber='8'"))
        XCTAssertFalse(script.contains("LensModel"), "une balise vide ne doit pas être écrite")
        // On compte les commandes, pas les occurrences du mot : l'en-tête
        // explicatif le contient lui aussi.
        let commands = script.split(separator: "\n").filter { $0.hasPrefix("exiftool ") }
        XCTAssertEqual(commands.count, 1, "une ligne sans fichier n’a rien à écrire")
    }
}
