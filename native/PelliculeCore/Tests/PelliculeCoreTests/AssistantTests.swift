import XCTest
@testable import PelliculeCore

/// Ces tests rejouent des scénarios déjà validés à l'écran dans la version web,
/// sur le matériel de référence : Minolta X-300 (1/1000 à 1 s) et MD 50 mm
/// f/1.7. Ils garantissent que le portage Swift conseille la même chose.
final class AssistantTests: XCTestCase {

    /// Vitesses du Minolta X-300.
    private let x300 = Assistant.shutters(
        in: Exposure.fullShutters, fastest: "1/1000", slowest: "1s")

    /// Ouvertures du MD 50 mm f/1.7, arrondi à f/2 sur la graduation pleine.
    private let md50 = Exposure.fullApertures.filter { $0 >= 1.9 && $0 <= 16.1 }

    private func input(
        aperture: Double, ev100: Double = 15, iso: Double = 400,
        distance: Double = 8, focal: Double = 50, handheld: Bool = true,
        desired: Double? = nil
    ) -> Assistant.Input {
        Assistant.Input(
            ev100: ev100, iso: iso, aperture: aperture, focal: focal, distance: distance,
            handheld: handheld, availableShutters: x300, availableApertures: md50,
            desiredShutterSeconds: desired)
    }

    // MARK: - Le couple vitesse / ouverture

    /// Paysage, plein soleil, Tri-X à 400 ISO, f/11 → 1/1000, net à l'infini.
    func testLandscapeInFullSun() {
        let result = Assistant.advise(input(aperture: 11))
        XCTAssertEqual(result.shutter, "1/1000")
        XCTAssertFalse(result.tooBright)
        XCTAssertEqual(result.depthOfField?.near ?? 0, 3.904, accuracy: 0.01)
        XCTAssertTrue(result.depthOfField?.isFarInfinite ?? false)
        XCTAssertTrue(result.advice.contains { $0.title == "Net jusqu’à l’infini" })
    }

    /// Portrait à pleine ouverture en plein soleil : hors plage, et l'assistant
    /// doit proposer f/11 — pas f/16, grâce à la tolérance d'un tiers.
    func testPortraitInFullSunSuggestsF11() {
        let result = Assistant.advise(input(aperture: 2, distance: 2))
        XCTAssertTrue(result.tooBright)
        XCTAssertEqual(result.suggestedAperture, 11)
        XCTAssertTrue(result.advice.contains { $0.level == .danger })
    }

    /// Une fois la correction appliquée, on retombe dans la plage.
    func testCorrectionResolvesTheProblem() {
        let result = Assistant.advise(input(aperture: 11, distance: 2))
        XCTAssertFalse(result.tooBright)
        XCTAssertNil(result.suggestedAperture)
    }

    // MARK: - Les intentions

    /// L'intention « Pose longue » vise 4 s : en plein jour c'est impossible,
    /// l'ouverture se cale au plus fermé et l'assistant explique pourquoi.
    func testLongExposureInDaylightIsImpossible() {
        let spec = Assistant.spec(for: .night)
        let aperture = Assistant.startingAperture(
            for: spec, available: md50, ev100: 15, iso: 400)
        XCTAssertEqual(aperture, 16, "doit se caler sur l’ouverture la plus fermée")

        let result = Assistant.advise(
            input(aperture: aperture, handheld: false, desired: 4))
        XCTAssertTrue(result.advice.contains {
            $0.title == "Trop de lumière pour poser aussi longtemps"
        })
    }

    /// Au crépuscule, le X-300 plafonne à la seconde : la pose de 4 s reste
    /// hors de portée, mais pour une autre raison. L'assistant doit renvoyer
    /// vers la pose B — et surtout ne pas afficher en même temps « pas assez
    /// de lumière » et « trop de lumière », ce qu'il faisait avant correction.
    func testLongExposureAtDuskHitsTheCameraFloorNotTheLight() {
        let result = Assistant.advise(
            input(aperture: 16, ev100: 3, handheld: false, desired: 4))
        XCTAssertTrue(result.tooDark)
        XCTAssertTrue(result.advice.contains { $0.title == "Pas assez de lumière" })
        XCTAssertFalse(
            result.advice.contains { $0.title == "Trop de lumière pour poser aussi longtemps" },
            "les deux messages ne doivent jamais coexister : ils se contredisent")
    }

    /// Avec un boîtier qui descend à 30 s, la même scène devient réalisable.
    func testLongExposureAtDuskWorksOnACapableCamera() {
        let capable = Assistant.shutters(
            in: Exposure.fullShutters, fastest: "1/2000", slowest: "30s")
        let result = Assistant.advise(Assistant.Input(
            ev100: 3, iso: 400, aperture: 16, focal: 50, distance: 8,
            handheld: false, availableShutters: capable, availableApertures: md50,
            desiredShutterSeconds: 4))
        XCTAssertFalse(result.tooDark)
        XCTAssertFalse(result.advice.contains { $0.level == .danger })
    }

    /// « Mouvement » vise le 1/500 et doit l'obtenir en plein soleil.
    func testActionIntentReachesItsTarget() {
        let spec = Assistant.spec(for: .action)
        let aperture = Assistant.startingAperture(
            for: spec, available: md50, ev100: 15, iso: 400)
        let result = Assistant.advise(input(aperture: aperture, desired: 1.0 / 500))
        XCTAssertEqual(result.shutter, "1/500")
    }

    // MARK: - Le flou de bougé

    /// Au 135 mm, le 1/60 passe sous la règle du 1/focale.
    func testHandheldWarningOnLongLens() {
        let result = Assistant.advise(
            input(aperture: 16, ev100: 11, focal: 135))
        XCTAssertTrue(result.advice.contains {
            $0.title.contains("flou de bougé") || $0.title.contains("Flou de bougé")
        })
    }

    /// Sur trépied, l'avertissement n'a pas lieu d'être.
    func testNoHandheldWarningOnTripod() {
        let result = Assistant.advise(
            input(aperture: 16, ev100: 11, focal: 135, handheld: false))
        XCTAssertFalse(result.advice.contains { $0.title.lowercased().contains("bougé") })
    }

    // MARK: - Bornes du matériel

    /// La graduation du X-300 s'arrête au 1/1000 et à la seconde.
    func testCameraShutterRangeIsRespected() {
        XCTAssertEqual(x300.first, "1s")
        XCTAssertEqual(x300.last, "1/1000")
        XCTAssertFalse(x300.contains("1/2000"))
        XCTAssertFalse(x300.contains("30s"))
    }

    // MARK: - Développement

    /// D-76 : 7 min à 20 °C tombent à environ 5 min à 24 °C.
    func testDevelopmentTemperatureCompensation() {
        let result = Development.time(base: 420, temperature: 24)
        XCTAssertEqual(result.correctedSeconds, 291, accuracy: 12)
    }

    /// Pousser d'un diaphragme rallonge d'environ 35 %.
    func testPushExtendsDevelopment() {
        let result = Development.time(base: 600, pushPullStops: 1)
        XCTAssertEqual(result.correctedSeconds, 810, accuracy: 5)
    }
}
