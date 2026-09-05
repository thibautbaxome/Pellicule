import XCTest
@testable import PelliculeCore

/// Le carnet est la seule partie de l'application qui puisse perdre des
/// données. Ces tests écrivent réellement sur disque et relisent avec une autre
/// instance : c'est le seul moyen de vérifier qu'un rouleau saisi survit à la
/// fermeture de l'application.
final class CarnetTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("carnet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var fileURL: URL { directory.appendingPathComponent("carnet.json") }

    /// Horloge et identifiants déterministes : sans cela les tests
    /// compareraient des valeurs qui changent à chaque exécution.
    private func makeCarnet(startingAt instant: Double = 0) -> Carnet {
        var tick = instant
        var counter = 0
        return Carnet(
            fileURL: fileURL,
            now: {
                tick += 1
                return Date(timeIntervalSince1970: tick)
            },
            makeID: {
                counter += 1
                return "id-\(counter)"
            })
    }

    private var triX: Catalog.Film {
        Catalog.films.first { $0.id == "kodak-tri-x-400" }!
    }

    private var x300: Catalog.Camera {
        Catalog.cameras.first { $0.id == "minolta-x-300" }!
    }

    // MARK: - Persistance

    func testNewCarnetIsEmptyAndWritesNothingUntilAsked() throws {
        let carnet = makeCarnet()
        try carnet.load()

        XCTAssertTrue(carnet.cameras.isEmpty)
        XCTAssertTrue(carnet.rolls.isEmpty)
        XCTAssertEqual(carnet.settings.defaultExposures, 36)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fileURL.path),
            "un carnet neuf ne doit pas créer de fichier avant la première saisie")
    }

    /// Le test qui compte : ce qui est saisi doit se retrouver après
    /// redémarrage. Une seconde instance relit le fichier sans rien partager
    /// avec la première.
    func testEverythingSurvivesARestart() throws {
        let carnet = makeCarnet()
        try carnet.load()

        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let roll = carnet.loadRoll(film: triX, camera: camera, shotIso: 1600, label: "Pointe du Raz")
        carnet.save(roll)

        var frame = carnet.makeFrame(inRoll: roll.id)
        frame.shutter = "1/250"
        frame.aperture = 8
        frame.subject = "Le phare dans la brume"
        carnet.save(frame)

        let reopened = makeCarnet()
        try reopened.load()

        XCTAssertEqual(reopened.cameras.map(\.name), ["Minolta X-300"])
        XCTAssertEqual(reopened.rolls.map(\.label), ["Pointe du Raz"])
        XCTAssertEqual(reopened.rolls.first?.shotIso, 1600)

        let frames = reopened.frames(ofRoll: roll.id)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames.first?.shutter, "1/250")
        XCTAssertEqual(frames.first?.aperture, 8)
        XCTAssertEqual(frames.first?.subject, "Le phare dans la brume")
        XCTAssertNil(reopened.lastWriteError)
    }

    /// Le fichier du carnet est une sauvegarde valide : c'est ce qui permet de
    /// l'exporter par simple copie, et de le relire avec le même code que celui
    /// qui reprend un carnet venu d'ailleurs.
    func testTheStoredFileIsAValidBackup() throws {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        carnet.save(carnet.loadRoll(film: triX, camera: camera))

        let decoded = try Backup.decode(from: Data(contentsOf: fileURL))
        XCTAssertEqual(decoded.format, Backup.formatName)
        XCTAssertEqual(decoded.summary.rolls, 1)
        XCTAssertEqual(
            decoded.danglingReferences(), [],
            "une sauvegarde doit se suffire à elle-même")
    }

    /// Charger un rouleau matérialise sa pellicule dans le carnet : sans cela
    /// la sauvegarde renverrait à une émulsion absente du fichier.
    func testLoadingARollMaterialisesItsFilm() throws {
        let carnet = makeCarnet()
        XCTAssertTrue(carnet.films.isEmpty)

        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        carnet.save(carnet.loadRoll(film: triX, camera: camera))

        XCTAssertEqual(carnet.films.map(\.id), ["kodak-tri-x-400"])
        XCTAssertEqual(carnet.films.first?.reciprocity.exponent, 1.28)

        // Un second rouleau sur la même émulsion ne doit pas la dupliquer.
        carnet.save(carnet.loadRoll(film: triX, camera: camera))
        XCTAssertEqual(carnet.films.count, 1)
    }

    /// Une émulsion pas encore employée reste consultable : la banque livrée
    /// prend le relais du carnet.
    func testFilmLookupFallsBackToTheCatalog() {
        let carnet = makeCarnet()
        XCTAssertEqual(carnet.film(id: "kodak-tri-x-400")?.displayName, "Kodak Tri-X 400")
        XCTAssertNil(carnet.film(id: "pellicule-inexistante"))
    }

    // MARK: - Rouleaux et vues

    /// Poser la première vue fait passer le rouleau de « chargé » à « en cours ».
    /// Personne ne pense à changer cet état à la main.
    func testFirstFrameStartsTheRoll() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let roll = carnet.loadRoll(film: triX, camera: camera)
        carnet.save(roll)
        XCTAssertEqual(carnet.roll(id: roll.id)?.status, .loaded)

        carnet.save(carnet.makeFrame(inRoll: roll.id))
        XCTAssertEqual(carnet.roll(id: roll.id)?.status, .shooting)
        XCTAssertTrue(carnet.openRolls.contains { $0.id == roll.id })
    }

    func testFrameNumbersFollowTheRoll() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let roll = carnet.loadRoll(film: triX, camera: camera)
        carnet.save(roll)

        XCTAssertEqual(carnet.nextFrameNumber(inRoll: roll.id), 1)
        for _ in 1...3 { carnet.save(carnet.makeFrame(inRoll: roll.id)) }

        XCTAssertEqual(carnet.frames(ofRoll: roll.id).map(\.number), [1, 2, 3])
        XCTAssertEqual(carnet.nextFrameNumber(inRoll: roll.id), 4)
    }

    /// D'une vue à l'autre la lumière change rarement du tout au tout : les
    /// réglages précédents sont repris, ce qui rend la saisie tenable.
    func testNextFrameInheritsThePreviousSettings() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let lens = carnet.makeLens(from: Catalog.lenses.first { $0.id == "minolta-md-50mm-f-1-7" }!)
        carnet.save(lens)
        let roll = carnet.loadRoll(film: triX, camera: camera)
        carnet.save(roll)

        var first = carnet.makeFrame(inRoll: roll.id)
        first.shutter = "1/125"
        first.aperture = 5.6
        first.lensId = lens.id
        first.filter = Model.Frame.Filter(name: "Jaune", factorStops: 1)
        first.subject = "Un sujet qui ne doit pas être repris"
        carnet.save(first)

        let second = carnet.makeFrame(inRoll: roll.id)
        XCTAssertEqual(second.shutter, "1/125")
        XCTAssertEqual(second.aperture, 5.6)
        XCTAssertEqual(second.lensId, lens.id)
        XCTAssertEqual(second.filter?.name, "Jaune")
        XCTAssertNil(second.subject, "le sujet est propre à chaque vue")
        XCTAssertEqual(second.number, 2)
    }

    // MARK: - Suppressions

    /// Supprimer un rouleau emporte ses vues : une vue sans rouleau resterait
    /// dans le fichier sans jamais s'afficher.
    func testDeletingARollTakesItsFramesAlong() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let kept = carnet.loadRoll(film: triX, camera: camera)
        let removed = carnet.loadRoll(film: triX, camera: camera)
        carnet.save(kept)
        carnet.save(removed)
        carnet.save(carnet.makeFrame(inRoll: kept.id))
        carnet.save(carnet.makeFrame(inRoll: removed.id))

        carnet.delete(rollId: removed.id)

        XCTAssertEqual(carnet.rolls.map(\.id), [kept.id])
        XCTAssertEqual(carnet.frames.map(\.rollId), [kept.id])
    }

    /// Supprimer un objectif ne supprime pas les vues prises avec : elles
    /// perdent l'objectif, elles ne perdent pas la prise de vue.
    func testDeletingALensKeepsTheFrames() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let lens = carnet.makeLens(named: "Un cinquante", focal: 50, maxAperture: 1.7)
        carnet.save(lens)
        let roll = carnet.loadRoll(film: triX, camera: camera)
        carnet.save(roll)

        var frame = carnet.makeFrame(inRoll: roll.id)
        frame.lensId = lens.id
        frame.subject = "Une vraie photo"
        carnet.save(frame)
        XCTAssertTrue(carnet.isUsed(lensId: lens.id))

        carnet.delete(lensId: lens.id)

        XCTAssertTrue(carnet.lenses.isEmpty)
        XCTAssertEqual(carnet.frames.count, 1)
        XCTAssertEqual(carnet.frames.first?.subject, "Une vraie photo")
        XCTAssertNil(carnet.frames.first?.lensId)
    }

    // MARK: - Monture

    func testLensesAreFilteredByMount() {
        let carnet = makeCarnet()
        let minolta = carnet.makeCamera(from: x300)
        carnet.save(minolta)

        let md50 = carnet.makeLens(from: Catalog.lenses.first { $0.mount == "Minolta SR" }!)
        let nikkor = carnet.makeLens(from: Catalog.lenses.first { $0.mount == "Nikon F" }!)
        carnet.save(md50)
        carnet.save(nikkor)

        let mountable = carnet.lenses(forCamera: minolta)
        XCTAssertEqual(mountable.map(\.id), [md50.id])
    }

    /// Un compact à objectif solidaire n'accepte aucun objectif : lui en
    /// proposer serait un contresens.
    func testFixedLensCameraAcceptsNoLens() {
        let carnet = makeCarnet()
        let trip = carnet.makeCamera(from: Catalog.cameras.first { $0.id == "olympus-trip-35" }!)
        carnet.save(trip)
        carnet.save(carnet.makeLens(named: "Un objectif", focal: 50, maxAperture: 2))

        XCTAssertEqual(trip.fixedLens?.focal, 40)
        XCTAssertTrue(carnet.lenses(forCamera: trip).isEmpty)
    }

    // MARK: - Restauration

    func testReplaceDiscardsTheCurrentCarnet() throws {
        let carnet = makeCarnet()
        carnet.save(carnet.makeCamera(named: "Boîtier à remplacer"))

        let incoming = try loadReferenceBackup()
        carnet.restore(incoming, mode: .replace)

        XCTAssertEqual(carnet.cameras.map(\.name), ["Minolta X-300"])
        XCTAssertEqual(carnet.rolls.count, 1)
        XCTAssertEqual(carnet.frames.count, 2)
    }

    func testMergeKeepsBothAndPrefersTheMostRecent() throws {
        let carnet = makeCarnet()
        let own = carnet.makeCamera(named: "Boîtier personnel")
        carnet.save(own)

        let incoming = try loadReferenceBackup()
        carnet.restore(incoming, mode: .merge)

        XCTAssertEqual(carnet.cameras.count, 2, "la fusion garde les deux boîtiers")
        XCTAssertTrue(carnet.cameras.contains { $0.id == own.id })
        XCTAssertEqual(carnet.rolls.count, 1)
    }

    /// À identifiant égal, c'est la fiche modifiée le plus récemment qui gagne.
    func testMergeResolvesConflictsByModificationDate() throws {
        let carnet = makeCarnet()
        let incoming = try loadReferenceBackup()
        carnet.restore(incoming, mode: .replace)

        var edited = try XCTUnwrap(carnet.cameras.first)
        edited.name = "Nom corrigé sur ce téléphone"
        edited.updatedAt = "2099-01-01T00:00:00.000Z"
        carnet.save(edited)

        // La même fiche, plus ancienne, ne doit pas écraser la correction.
        carnet.restore(incoming, mode: .merge)
        XCTAssertEqual(carnet.cameras.first?.name, "Nom corrigé sur ce téléphone")
    }

    private func loadReferenceBackup() throws -> Backup {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "backup-reference", withExtension: "json",
                              subdirectory: "Fixtures"))
        return try Backup.decode(from: Data(contentsOf: url))
    }

    // MARK: - Robustesse

    /// Une écriture impossible ne doit pas faire perdre la saisie : la
    /// modification reste en mémoire et l'erreur est signalée.
    func testAFailedWriteIsReportedWithoutLosingTheEdit() throws {
        let unwritable = directory
            .appendingPathComponent("dossier-inexistant")
            .appendingPathComponent("carnet.json")
        let carnet = Carnet(fileURL: unwritable)

        carnet.save(carnet.makeCamera(named: "Saisie à conserver"))

        XCTAssertEqual(carnet.cameras.map(\.name), ["Saisie à conserver"])
        XCTAssertNotNil(carnet.lastWriteError)
    }

    /// Un carnet sans fichier sert aux aperçus d'interface : il doit
    /// fonctionner entièrement, sans jamais toucher au disque.
    func testInMemoryCarnetWorksWithoutAFile() {
        let carnet = Carnet(fileURL: nil)
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        carnet.save(carnet.loadRoll(film: triX, camera: camera))

        XCTAssertEqual(carnet.rolls.count, 1)
        XCTAssertNil(carnet.lastWriteError)
    }

    /// Les dates doivent rester ordonnables comme des chaînes : c'est ce dont
    /// dépendent le tri des rouleaux et l'arbitrage de la fusion.
    func testTimestampsSortLexicographically() {
        let early = Carnet.timestamp(Date(timeIntervalSince1970: 1_000))
        let late = Carnet.timestamp(Date(timeIntervalSince1970: 2_000))
        XCTAssertLessThan(early, late)
        XCTAssertTrue(early.hasSuffix("Z"), "l'horodatage doit être en temps universel")
    }
}

// MARK: - Protection du fichier

extension CarnetTests {

    /// La précaution la plus importante du carnet : un fichier illisible peut
    /// contenir des années de prises de vue. L'application doit refuser
    /// d'écrire par-dessus, quitte à être inutilisable.
    func testAnUnreadableCarnetIsNeverOverwritten() throws {
        let corrupt = Data(#"{"format":"pellicule-backup","version":99,"exportedAt":"","includesPhotos":false,"data":{"cameras":[],"lenses":[],"filmStocks":[],"rolls":[],"frames":[],"settings":[],"attachments":[]}}"#.utf8)
        try corrupt.write(to: fileURL)

        let carnet = makeCarnet()
        XCTAssertThrowsError(try carnet.load())
        XCTAssertTrue(carnet.isSealed)

        carnet.save(carnet.makeCamera(named: "Une saisie qui ne doit rien écraser"))

        XCTAssertEqual(
            try Data(contentsOf: fileURL), corrupt,
            "le fichier d'origine doit être intact")
    }

    /// Un fichier qui n'est même pas du JSON est refusé de la même façon.
    func testGarbageFileSealsTheCarnet() throws {
        try Data("ceci n'est pas un carnet".utf8).write(to: fileURL)

        let carnet = makeCarnet()
        XCTAssertThrowsError(try carnet.load())
        XCTAssertTrue(carnet.isSealed)
        carnet.save(carnet.makeCamera(named: "Rien ne doit sortir"))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "ceci n'est pas un carnet")
    }
}

// MARK: - Graduation des ouvertures

extension CarnetTests {

    /// Sans objectif déclaré, la graduation complète descendrait à f/1 : une
    /// ouverture que trois objectifs au monde atteignent, et que l'application
    /// proposerait avec la même assurance que les autres.
    func testUndeclaredLensDoesNotOfferImpossibleApertures() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)

        let range = carnet.apertureRange(forCamera: camera, lensId: nil)
        XCTAssertTrue(range.isAssumed, "l’absence d’objectif doit être signalée comme telle")
        XCTAssertEqual(range.values.first, 2.8)
        XCTAssertFalse(range.values.contains(1), "f/1 ne doit jamais être proposé par défaut")
        XCTAssertEqual(range.values.last, 22)
    }

    /// Un objectif déclaré borne réellement la graduation.
    func testDeclaredLensBoundsTheScale() {
        let carnet = makeCarnet()
        let camera = carnet.makeCamera(from: x300)
        carnet.save(camera)
        let lens = carnet.makeLens(from: Catalog.lenses.first { $0.id == "minolta-md-50mm-f-1-7" }!)
        carnet.save(lens)

        let range = carnet.apertureRange(forCamera: camera, lensId: lens.id)
        XCTAssertFalse(range.isAssumed)
        // f/1,7 n'est pas sur la graduation normalisée mais est gravé sur la
        // bague : la taire coûterait un tiers de diaphragme.
        XCTAssertEqual(range.values.first, 1.7)
        XCTAssertTrue(range.values.contains(2))
        XCTAssertEqual(range.values.last, 16, "le MD 50 mm ferme à f/16")
    }

    /// Un compact à objectif solidaire porte ses bornes sur le boîtier.
    func testFixedLensCameraBoundsTheScale() {
        let carnet = makeCarnet()
        let trip = carnet.makeCamera(from: Catalog.cameras.first { $0.id == "olympus-trip-35" }!)
        carnet.save(trip)

        let range = carnet.apertureRange(forCamera: trip, lensId: nil)
        XCTAssertFalse(range.isAssumed, "l’objectif solidaire est une déclaration")
        XCTAssertEqual(range.values.first, 2.8)
    }
}
