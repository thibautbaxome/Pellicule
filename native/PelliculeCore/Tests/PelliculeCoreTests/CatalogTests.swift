import XCTest
@testable import PelliculeCore

/// Ces tests vérifient surtout que la projection JSON engendrée depuis la
/// version web se décode sans perte : un champ renommé d'un côté casserait
/// silencieusement l'autre sans eux.
final class CatalogTests: XCTestCase {

    func testCatalogsAreLoaded() {
        XCTAssertGreaterThan(Catalog.films.count, 40)
        XCTAssertGreaterThan(Catalog.cameras.count, 150)
        XCTAssertGreaterThan(Catalog.lenses.count, 70)
    }

    func testIdentifiersAreUnique() {
        XCTAssertEqual(Set(Catalog.films.map(\.id)).count, Catalog.films.count)
        XCTAssertEqual(Set(Catalog.cameras.map(\.id)).count, Catalog.cameras.count)
        XCTAssertEqual(Set(Catalog.lenses.map(\.id)).count, Catalog.lenses.count)
    }

    /// Le boîtier de référence du projet, avec ses caractéristiques.
    func testMinoltaX300IsPresentAndComplete() throws {
        let x300 = try XCTUnwrap(Catalog.cameras.first { $0.id == "minolta-x-300" })
        XCTAssertEqual(x300.displayName, "Minolta X-300")
        XCTAssertEqual(x300.mount, "Minolta SR")
        XCTAssertEqual(x300.shutterFastest, "1/1000")
        XCTAssertEqual(x300.shutterSlowest, "1s")
        XCTAssertEqual(x300.type, .slr)
        XCTAssertTrue(x300.hasInterchangeableLens)
    }

    /// La réciprocité doit survivre au passage par le JSON : c'est elle qui
    /// détermine les poses longues.
    func testTriXReciprocitySurvivesTheRoundTrip() throws {
        let triX = try XCTUnwrap(Catalog.films.first { $0.id == "kodak-tri-x-400" })
        XCTAssertEqual(triX.iso, 400)
        XCTAssertEqual(triX.type, .blackAndWhite)
        XCTAssertEqual(triX.reciprocityModel.exponent, 1.28, accuracy: 1e-9)
        XCTAssertEqual(triX.reciprocityModel.corrected(measured: 8), 14.32, accuracy: 0.01)
        XCTAssertFalse(triX.devTimes?.isEmpty ?? true)
    }

    /// Un compact porte un objectif solidaire, pas une monture.
    func testFixedLensCameraIsDecoded() throws {
        let trip = try XCTUnwrap(Catalog.cameras.first { $0.id == "olympus-trip-35" })
        XCTAssertFalse(trip.hasInterchangeableLens)
        XCTAssertEqual(trip.fixedLens?.focal, 40)
        XCTAssertEqual(trip.fixedLens?.maxAperture, 2.8)
    }

    // MARK: - Recherche

    func testSearchIsAccentAndOrderInsensitive() {
        XCTAssertFalse(Catalog.searchCameras("minolta 300").isEmpty)
        XCTAssertFalse(Catalog.searchCameras("300 MINOLTA").isEmpty)
        XCTAssertFalse(Catalog.searchCameras("voigtlander").isEmpty,
                       "« voigtlander » doit trouver « Voigtländer »")
    }

    func testLensSearchFiltersByMount() {
        let srLenses = Catalog.searchLenses("", mount: "Minolta SR")
        XCTAssertFalse(srLenses.isEmpty)
        XCTAssertTrue(srLenses.allSatisfy { $0.mount == "Minolta SR" })
    }

    func testSearchWithoutQueryOrMountReturnsNothing() {
        XCTAssertTrue(Catalog.searchLenses("").isEmpty)
        XCTAssertTrue(Catalog.searchCameras("").isEmpty)
    }

    /// Le cas qui a motivé la banque : l'objectif livré avec le X-300.
    func testStandardMinoltaLensIsPresent() throws {
        let lens = try XCTUnwrap(
            Catalog.searchLenses("50mm f/1.7", mount: "Minolta SR").first)
        XCTAssertEqual(lens.focalMin, 50)
        XCTAssertTrue(lens.isPrime)
        XCTAssertEqual(lens.maxAperture, 1.7)
        XCTAssertEqual(lens.focalLabel, "50 mm")
    }

    /// Les montures servent à filtrer : elles ne doivent pas contenir « Fixe ».
    func testMountsExcludeFixedLenses() {
        XCTAssertFalse(Catalog.mounts.contains(Catalog.fixedMountName))
        XCTAssertTrue(Catalog.mounts.contains("Minolta SR"))
        XCTAssertTrue(Catalog.mounts.contains("Nikon F"))
    }
}
