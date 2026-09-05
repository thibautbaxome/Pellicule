import XCTest
@testable import PelliculeCore

/// Un filtre mal compté, c'est un négatif sous-exposé du nombre de
/// diaphragmes qu'on a oublié de compenser.
final class FiltersTests: XCTestCase {

    func testFactorConvertsToStops() {
        XCTAssertEqual(Filters.stops(fromFactor: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(Filters.stops(fromFactor: 2), 1, accuracy: 1e-9)
        XCTAssertEqual(Filters.stops(fromFactor: 8), 3, accuracy: 1e-9)
        XCTAssertEqual(Filters.stops(fromFactor: 1000), 9.97, accuracy: 0.01)
    }

    func testAbsurdFactorsCostNothing() {
        XCTAssertEqual(Filters.stops(fromFactor: 0), 0)
        XCTAssertEqual(Filters.stops(fromFactor: -4), 0)
        XCTAssertEqual(Filters.stops(fromFactor: .infinity), 0)
    }

    /// L'erreur classique : deux ND4 empilés donnent quatre diaphragmes et non
    /// huit. Ce sont les diaphragmes qui s'additionnent, pas les facteurs.
    func testStackedFiltersAddStopsNotFactors() {
        XCTAssertEqual(Filters.combinedStops(factors: [4, 4]), 4, accuracy: 1e-9)
        XCTAssertEqual(Filters.combinedStops(factors: [2, 8]), 4, accuracy: 1e-9)
        XCTAssertEqual(Filters.combinedStops(factors: []), 0)
    }

    func testStopsAndFactorsAreInverse() {
        for stops in stride(from: 0.0, through: 10.0, by: 0.5) {
            XCTAssertEqual(
                Filters.stops(fromFactor: Filters.factor(fromStops: stops)),
                stops, accuracy: 1e-9)
        }
    }

    /// Les densités neutres portent leur force dans leur nom : un ND8 doit
    /// coûter trois diaphragmes, sans quoi le nom ment.
    func testNeutralDensityNamesMatchTheirStrength() throws {
        let expected: [String: Double] = [
            "ND2": 1, "ND4": 2, "ND8": 3, "ND16": 4, "ND64": 6, "ND1000": 10,
        ]
        for preset in Filters.presets(in: .neutralDensity) {
            let stops = try XCTUnwrap(expected[preset.name], "ND inconnu : \(preset.name)")
            XCTAssertEqual(
                preset.stops, stops, accuracy: 0.05,
                "\(preset.name) devrait coûter \(stops) diaphragmes")
        }
    }

    func testPresetsAreCoherent() {
        XCTAssertEqual(Set(Filters.presets.map(\.id)).count, Filters.presets.count)
        for preset in Filters.presets {
            XCTAssertFalse(preset.name.isEmpty)
            XCTAssertFalse(preset.effect.isEmpty, "\(preset.name) : un filtre sans effet décrit")
            XCTAssertGreaterThanOrEqual(preset.factor, 1, "\(preset.name)")
        }
    }

    /// Un filtre sans coût existe — l'UV ne sert qu'à protéger la lentille.
    func testProtectiveFilterCostsNothing() throws {
        let uv = try XCTUnwrap(Filters.presets.first { $0.id == "uv" })
        XCTAssertEqual(uv.stops, 0, accuracy: 1e-9)
    }

    /// Le nom enregistré dans une vue doit permettre de retrouver la fiche.
    func testAPresetIsFoundBackByItsName() throws {
        let red = try XCTUnwrap(Filters.preset(named: "Rouge n°25"))
        XCTAssertEqual(red.stops, 3, accuracy: 1e-9)
        XCTAssertNil(Filters.preset(named: "Filtre imaginaire"))
    }
}
