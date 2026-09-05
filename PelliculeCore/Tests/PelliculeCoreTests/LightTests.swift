import XCTest
@testable import PelliculeCore

/// La règle du f/16 est le seul posemètre dont dispose la plupart des boîtiers
/// mécaniques. Un décalage d'un diaphragme y passe encore sur du négatif, deux
/// non — et sur de la diapositive, un seul suffit à perdre la vue.
final class LightTests: XCTestCase {

    private func condition(_ id: String) throws -> Light.Condition {
        try XCTUnwrap(Light.condition(id: id))
    }

    /// L'énoncé mnémotechnique et l'indice de lumination ne coïncident pas
    /// exactement : « 1/ISO à f/16 » arrondit d'environ un tiers de diaphragme
    /// dans le sens de la surexposition. L'écart est voulu — un négatif
    /// l'encaisse volontiers — mais il doit rester petit et de ce signe-là,
    /// sinon la table livrée ne décrit plus la règle qu'elle invoque.
    func testTheMnemonicStaysCloseToTheExposureValue() throws {
        let described = Light.conditions.filter { $0.aperture != nil }
        XCTAssertEqual(described.count, 6, "la règle du f/16 décrit la lumière du jour")

        for condition in described {
            let drift = try XCTUnwrap(Light.mnemonicDrift(condition))
            XCTAssertLessThan(
                abs(drift), 0.5,
                "\(condition.label) : \(drift) diaphragme d'écart avec son indice")
            XCTAssertLessThan(
                drift, 0,
                "\(condition.label) : la règle doit arrondir vers la surexposition")
        }
    }

    /// En plein soleil à f/16, la règle donne 1/ISO et l'indice un tiers de
    /// diaphragme de moins. C'est l'indice qui est affiché.
    func testSunnySixteenIsComputedFromTheExposureValue() throws {
        let sunny = try condition("sunny")
        XCTAssertEqual(sunny.aperture, 16)

        let pairing = try XCTUnwrap(
            Light.pairings(iso: 100, condition: sunny).first { $0.aperture == 16 })
        XCTAssertEqual(pairing.seconds, 1.0 / 128, accuracy: 1e-9)
        XCTAssertEqual(pairing.shutter, "1/128")
    }

    /// Toutes les lignes d'une même condition exposent identiquement : c'est
    /// exactement ce qui autorise à choisir la sienne.
    func testEveryPairingOfAConditionGivesTheSameExposure() throws {
        let overcast = try condition("overcast")
        let pairings = Light.pairings(iso: 400, condition: overcast)
        XCTAssertGreaterThan(pairings.count, 5)

        // L'indice de lumination vaut av − log2(t) : il doit être constant
        // d'un couple à l'autre, c'est la définition même de l'équivalence.
        let exposures = pairings.map { pairing in
            Exposure.av(aperture: pairing.aperture) - log2(pairing.seconds)
        }
        let reference = try XCTUnwrap(exposures.first)
        for value in exposures {
            XCTAssertEqual(value, reference, accuracy: 1e-9)
        }
    }

    /// Chaque condition vaut un diaphragme de moins que la précédente, en IL
    /// comme en ouverture de référence. C'est ce qui rend l'échelle lisible.
    func testConditionsDescendOneStopAtATime() throws {
        let bright = Light.conditions.prefix(6)
        for (previous, next) in zip(bright, bright.dropFirst()) {
            XCTAssertEqual(
                previous.ev100 - next.ev100, 1, accuracy: 1e-9,
                "\(previous.label) → \(next.label) : l'écart doit être d'un IL")
            let before = try XCTUnwrap(previous.aperture)
            let after = try XCTUnwrap(next.aperture)
            XCTAssertEqual(
                Exposure.av(aperture: before) - Exposure.av(aperture: after),
                1, accuracy: 0.1,
                "\(previous.label) → \(next.label) : un diaphragme d'écart")
        }
    }

    func testConditionsAreOrderedFromBrightestToDarkest() {
        let evs = Light.conditions.map(\.ev100)
        XCTAssertEqual(evs, evs.sorted(by: >))
        XCTAssertEqual(Set(Light.conditions.map(\.id)).count, Light.conditions.count)
    }

    /// La sensibilité déplace l'indice de lumination, pas la condition.
    func testSensitivityShiftsTheExposureValue() throws {
        let sunny = try condition("sunny")
        XCTAssertEqual(Light.ev(for: sunny, iso: 100), 15, accuracy: 1e-9)
        XCTAssertEqual(Light.ev(for: sunny, iso: 400), 17, accuracy: 1e-9)
        XCTAssertEqual(Light.ev(for: sunny, iso: 25), 13, accuracy: 1e-9)
    }

    /// Une correction d'exposition allonge la pose du nombre de diaphragmes
    /// demandé, sans rien changer d'autre.
    func testExposureCompensationShiftsEveryPairing() throws {
        let sunny = try condition("sunny")
        let plain = Light.pairings(iso: 100, condition: sunny)
        let opened = Light.pairings(iso: 100, condition: sunny, exposureCompStops: 1)

        for (a, b) in zip(plain, opened) {
            XCTAssertEqual(b.seconds, a.seconds * 2, accuracy: 1e-9)
        }
    }

    /// La règle doit s'accorder avec l'arithmétique de l'exposition employée
    /// partout ailleurs : deux chemins, un seul résultat.
    func testAgreesWithTheExposureArithmetic() throws {
        for condition in Light.conditions {
            for iso in [100.0, 400.0] {
                let pairing = try XCTUnwrap(
                    Light.pairings(iso: iso, condition: condition)
                        .first { $0.aperture == 8 })
                let computed = Exposure.shutterSeconds(
                    ev100: condition.ev100, iso: iso, aperture: 8)
                XCTAssertEqual(
                    pairing.seconds, computed, accuracy: computed * 1e-9,
                    "\(condition.label) à \(Int(iso)) ISO")
            }
        }
    }

    func testRejectsAbsurdSensitivity() throws {
        XCTAssertTrue(Light.pairings(iso: 0, condition: try condition("sunny")).isEmpty)
        XCTAssertTrue(Light.pairings(iso: -400, condition: try condition("sunny")).isEmpty)
    }
}
