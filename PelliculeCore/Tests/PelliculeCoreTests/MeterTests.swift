import XCTest
@testable import PelliculeCore

/// Un posemètre faux d'un diaphragme est pire qu'un posemètre absent : on lui
/// fait confiance. Ces tests partent donc de valeurs qu'on peut vérifier de
/// tête, et non de ce que le code produit.
final class MeterTests: XCTestCase {

    /// L'ancrage de toute la photographie : f/16 au 1/125 à 100 ISO, c'est le
    /// plein soleil, IL 15.
    func testSunnySixteenReadsAsFifteen() throws {
        let ev = try XCTUnwrap(
            Meter.exposureValue(aperture: 16, durationSeconds: 1.0 / 125, iso: 100))
        XCTAssertEqual(ev, 15, accuracy: 0.05)
    }

    /// Un iPhone en plein soleil : ouverture fixe f/1,78, sensibilité au
    /// plancher, vitesse très courte. On doit retomber sur le plein soleil —
    /// c'est le seul contrôle possible d'un posemètre sans banc d'essai.
    func testATypicalPhoneInFullSunReadsFullSun() throws {
        let ev = try XCTUnwrap(
            Meter.exposureValue(aperture: 1.78, durationSeconds: 1.0 / 3520, iso: 34))
        XCTAssertEqual(ev, 15, accuracy: 0.1)
        XCTAssertEqual(Meter.nearestCondition(toEV100: ev)?.id, "sunny")
    }

    // MARK: - Les trois leviers, un diaphragme chacun

    func testHalvingTheDurationAddsOneStop() throws {
        let slow = try XCTUnwrap(
            Meter.exposureValue(aperture: 2, durationSeconds: 1.0 / 60, iso: 100))
        let fast = try XCTUnwrap(
            Meter.exposureValue(aperture: 2, durationSeconds: 1.0 / 120, iso: 100))
        XCTAssertEqual(fast - slow, 1, accuracy: 1e-9)
    }

    func testDoublingTheSensitivityRemovesOneStop() throws {
        let low = try XCTUnwrap(
            Meter.exposureValue(aperture: 2, durationSeconds: 1.0 / 60, iso: 100))
        let high = try XCTUnwrap(
            Meter.exposureValue(aperture: 2, durationSeconds: 1.0 / 60, iso: 200))
        XCTAssertEqual(low - high, 1, accuracy: 1e-9)
    }

    func testClosingOneStopAddsOneStop() throws {
        let open = try XCTUnwrap(
            Meter.exposureValue(aperture: 2, durationSeconds: 1.0 / 60, iso: 100))
        let closed = try XCTUnwrap(
            Meter.exposureValue(aperture: 2.828, durationSeconds: 1.0 / 60, iso: 100))
        XCTAssertEqual(closed - open, 1, accuracy: 0.01)
    }

    /// La mesure doit s'accorder avec l'arithmétique employée partout ailleurs :
    /// deux chemins vers le même nombre.
    func testAgreesWithTheExposureArithmetic() throws {
        for ev100 in stride(from: 3.0, through: 16.0, by: 1) {
            for iso in [100.0, 400.0, 3200.0] {
                let duration = Exposure.shutterSeconds(ev100: ev100, iso: iso, aperture: 2.8)
                let measured = try XCTUnwrap(
                    Meter.exposureValue(aperture: 2.8, durationSeconds: duration, iso: iso))
                XCTAssertEqual(measured, ev100, accuracy: 1e-9, "IL \(ev100) à \(Int(iso)) ISO")
            }
        }
    }

    func testRejectsImpossibleSettings() {
        XCTAssertNil(Meter.exposureValue(aperture: 0, durationSeconds: 0.01, iso: 100))
        XCTAssertNil(Meter.exposureValue(aperture: 2, durationSeconds: 0, iso: 100))
        XCTAssertNil(Meter.exposureValue(aperture: 2, durationSeconds: 0.01, iso: 0))
        XCTAssertNil(Meter.exposureValue(aperture: 2, durationSeconds: .infinity, iso: 100))
        XCTAssertNil(Meter.exposureValue(aperture: .nan, durationSeconds: 0.01, iso: 100))
    }

    // MARK: - Quand l'appareil est au bout de ce qu'il sait faire

    private let iphone = Meter.DeviceLimits(
        shortestDuration: 1.0 / 16_000, longestDuration: 1.0 / 3,
        lowestISO: 34, highestISO: 4032)

    /// Dans le noir, la caméra ouvre le temps et monte la sensibilité au
    /// maximum : ce qu'elle rapporte n'est plus une mesure mais une borne.
    /// L'afficher comme un chiffre ferait sous-exposer sans le savoir.
    func testDarknessBeyondTheSensorIsFlaggedAsALimit() throws {
        let reading = try XCTUnwrap(Meter.reading(
            aperture: 1.78, durationSeconds: 1.0 / 3, iso: 4032, limits: iphone))
        XCTAssertTrue(reading.isAtLimit)
    }

    /// Symétriquement, une scène éblouissante peut saturer par le haut.
    func testBlindingLightIsFlaggedAsALimit() throws {
        let reading = try XCTUnwrap(Meter.reading(
            aperture: 1.78, durationSeconds: 1.0 / 16_000, iso: 34, limits: iphone))
        XCTAssertTrue(reading.isAtLimit)
    }

    /// Une scène ordinaire ne touche aucune borne : l'avertissement doit se
    /// taire, sans quoi il ne se lira plus.
    func testAnOrdinarySceneIsNotFlagged() throws {
        let reading = try XCTUnwrap(Meter.reading(
            aperture: 1.78, durationSeconds: 1.0 / 120, iso: 200, limits: iphone))
        XCTAssertFalse(reading.isAtLimit)
        // f/1,78 au 1/120 à 200 ISO : un intérieur bien éclairé.
        XCTAssertEqual(reading.ev100, 7.57, accuracy: 0.05)
    }

    /// Une seule borne atteinte ne suffit pas : la caméra peut très bien être
    /// à sa sensibilité plancher en pleine journée sans être saturée.
    func testOneLimitAloneIsNotSaturation() throws {
        let reading = try XCTUnwrap(Meter.reading(
            aperture: 1.78, durationSeconds: 1.0 / 500, iso: 34, limits: iphone))
        XCTAssertFalse(reading.isAtLimit)
    }

    // MARK: - Calibrage

    /// Les capteurs ne mesurent pas tous pareil. Le réglage se compte en
    /// diaphragmes et s'applique tel quel.
    func testCalibrationShiftsTheReading() throws {
        let plain = try XCTUnwrap(Meter.reading(
            aperture: 2, durationSeconds: 1.0 / 60, iso: 100, limits: nil))
        let shifted = try XCTUnwrap(Meter.reading(
            aperture: 2, durationSeconds: 1.0 / 60, iso: 100, limits: nil,
            calibrationStops: -0.5))
        XCTAssertEqual(shifted.ev100, plain.ev100 - 0.5, accuracy: 1e-9)
    }

    // MARK: - Traduire un chiffre en quelque chose qu'on reconnaît

    func testEachConditionReadsBackAsItself() {
        for condition in Light.conditions {
            XCTAssertEqual(
                Meter.nearestCondition(toEV100: condition.ev100)?.id, condition.id,
                condition.label)
        }
    }

    /// Une mesure entre deux conditions tombe sur la plus proche.
    func testAReadingBetweenTwoConditionsPicksTheCloser() {
        XCTAssertEqual(Meter.nearestCondition(toEV100: 14.8)?.id, "sunny")
        XCTAssertEqual(Meter.nearestCondition(toEV100: 13.7)?.id, "slight-overcast")
        XCTAssertEqual(Meter.nearestCondition(toEV100: 13.4)?.id, "overcast")
        XCTAssertEqual(Meter.nearestCondition(toEV100: 100)?.id, "snow-sand")
        XCTAssertEqual(Meter.nearestCondition(toEV100: -100)?.id, "street-night")
    }

    /// L'écart entre ce qu'on croyait voir et ce qui est : c'est ce chiffre-là
    /// qui apprend à se passer d'un posemètre.
    func testDriftBetweenGuessAndMeasurement() throws {
        let sunny = try XCTUnwrap(Light.condition(id: "sunny"))
        XCTAssertEqual(Meter.drift(estimated: sunny, measured: 13), 2, accuracy: 1e-9)
        XCTAssertEqual(Meter.drift(estimated: sunny, measured: 15), 0, accuracy: 1e-9)
        XCTAssertEqual(Meter.drift(estimated: sunny, measured: 16), -1, accuracy: 1e-9)
    }
}
