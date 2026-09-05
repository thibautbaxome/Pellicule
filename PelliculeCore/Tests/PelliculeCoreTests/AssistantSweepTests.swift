import XCTest
@testable import PelliculeCore

/// Balayage de tout ce que l'assistant peut rencontrer.
///
/// Les autres tests vérifient des scénarios choisis : celui-ci parcourt le
/// produit de toutes les intentions, de toutes les conditions de lumière, de
/// trois sensibilités et de trois boîtiers, et vérifie sur chaque combinaison
/// des propriétés qui doivent tenir partout.
///
/// C'est la seule façon d'attraper le cas qu'on n'aurait pas pensé à écrire —
/// et c'est ainsi qu'on a déjà trouvé un conseil contradictoire qui traînait
/// depuis des semaines.
final class AssistantSweepTests: XCTestCase {

    private struct Body {
        let name: String
        let fastest: String
        let slowest: String
        var shutters: [String] {
            Assistant.shutters(in: Exposure.fullShutters, fastest: fastest, slowest: slowest)
        }
    }

    private let bodies = [
        Body(name: "Minolta X-300", fastest: "1/1000", slowest: "1s"),
        Body(name: "Boîtier complet", fastest: "1/8000", slowest: "30s"),
        // Un compact modeste : c'est là que les limites mordent le plus.
        Body(name: "Compact", fastest: "1/500", slowest: "1/8"),
    ]

    private let apertures: [Double] = [2, 2.8, 4, 5.6, 8, 11, 16]
    private let sensitivities: [Double] = [100, 400, 1600]
    private let focals: [Double] = [28, 50, 135]

    /// Chaque combinaison, telle que l'écran la construirait.
    private func sweep(
        _ check: (Assistant.IntentSpec, Light.Condition, Double, Body, Double,
                  Assistant.Input, Assistant.Result) -> Void
    ) {
        for spec in Assistant.intents {
            for condition in Light.conditions {
                for iso in sensitivities {
                    for body in bodies {
                        for focal in focals {
                            let aperture = Assistant.startingAperture(
                                for: spec, available: apertures,
                                ev100: condition.ev100, iso: iso)
                            let input = Assistant.Input(
                                ev100: condition.ev100,
                                iso: iso,
                                aperture: aperture,
                                focal: focal,
                                distance: 3,
                                handheld: spec.handheld,
                                availableShutters: body.shutters,
                                availableApertures: apertures,
                                reciprocity: ReciprocityModel(
                                    exponent: 1.28, thresholdSeconds: 1),
                                desiredShutterSeconds: desired(spec))
                            check(spec, condition, iso, body, focal,
                                  input, Assistant.advise(input))
                        }
                    }
                }
            }
        }
    }

    private func desired(_ spec: Assistant.IntentSpec) -> Double? {
        if case .shutterSeconds(let seconds) = spec.target { return seconds }
        return nil
    }

    private func situation(
        _ spec: Assistant.IntentSpec, _ condition: Light.Condition,
        _ iso: Double, _ body: Body, _ focal: Double
    ) -> String {
        "\(spec.label) · \(condition.label) · \(Int(iso)) ISO · \(body.name) · \(Int(focal)) mm"
    }

    // MARK: - Ce qui doit tenir partout

    /// Une scène ne peut pas être à la fois trop claire et trop sombre. Cela
    /// paraît évident, et c'est pourtant le défaut qu'on a trouvé en portant
    /// ce code : les deux messages s'affichaient côte à côte.
    func testNeverBothTooBrightAndTooDark() {
        sweep { spec, condition, iso, body, focal, _, result in
            XCTAssertFalse(
                result.tooBright && result.tooDark,
                situation(spec, condition, iso, body, focal))
        }
    }

    /// Deux conseils ne doivent jamais se contredire dans la même liste.
    func testAdviceNeverContradictsItself() {
        sweep { spec, condition, iso, body, focal, _, result in
            let titles = Set(result.advice.map(\.title))
            let opensUp = titles.contains { $0.contains("Pas assez de lumière") }
            let closesDown = titles.contains { $0.contains("Trop de lumière") }
            XCTAssertFalse(
                opensUp && closesDown,
                "conseils contradictoires — \(situation(spec, condition, iso, body, focal)) : "
                    + titles.joined(separator: " / "))
        }
    }

    /// Le test qui compte pour un débutant : quand l'application propose une
    /// correction, l'appliquer doit résoudre le problème. Un bouton « corriger »
    /// qui laisse le même message est pire que pas de bouton du tout.
    func testTheSuggestedApertureActuallyFixesTheProblem() {
        sweep { spec, condition, iso, body, focal, input, result in
            guard let suggested = result.suggestedAperture else { return }
            XCTAssertTrue(
                self.apertures.contains(suggested),
                "l’ouverture proposée doit exister sur l’objectif — "
                    + situation(spec, condition, iso, body, focal))

            var corrected = input
            corrected.aperture = suggested
            let after = Assistant.advise(corrected)

            XCTAssertFalse(
                after.tooBright || after.tooDark,
                "appliquer f/\(suggested) laisse la scène hors plage — "
                    + situation(spec, condition, iso, body, focal))
        }
    }

    /// Hors plage sans correction possible, l'application doit dire quoi faire
    /// d'autre — filtre, trépied, autre film — et non constater l'échec.
    func testAnImpossibleSceneAlwaysExplainsTheWayOut() {
        sweep { spec, condition, iso, body, focal, _, result in
            guard result.tooBright || result.tooDark, result.suggestedAperture == nil else {
                return
            }
            let detail = result.advice.map(\.detail).joined(separator: " ")
            let mentionsARemedy = ["filtre", "trépied", "pose B", "film", "sensible"]
                .contains { detail.lowercased().contains($0.lowercased()) }
            XCTAssertTrue(
                mentionsARemedy,
                "aucune issue proposée — \(situation(spec, condition, iso, body, focal)) : \(detail)")
        }
    }

    /// La vitesse conseillée doit exister sur le boîtier. Conseiller un
    /// 1/2000 à quelqu'un dont la molette s'arrête au 1/1000, c'est lui faire
    /// rater la photo en toute confiance.
    func testTheAdvisedShutterExistsOnTheBody() {
        sweep { spec, condition, iso, body, focal, input, result in
            guard let shutter = result.shutter else { return }
            XCTAssertTrue(
                input.availableShutters.contains(shutter),
                "\(shutter) n’existe pas sur ce boîtier — "
                    + situation(spec, condition, iso, body, focal))
        }
    }

    /// Le photographe doit toujours repartir avec quelque chose : soit le
    /// réglage tient, soit on lui dit pourquoi il ne tient pas.
    func testOutOfRangeAlwaysSaysSomething() {
        sweep { spec, condition, iso, body, focal, _, result in
            if result.tooBright || result.tooDark {
                XCTAssertFalse(
                    result.advice.isEmpty,
                    "silence sur une scène hors plage — "
                        + situation(spec, condition, iso, body, focal))
            }
        }
    }

    /// Dans la plage, l'arrondi à la graduation ne peut pas dépasser un demi
    /// diaphragme : au-delà, ce n'est plus un arrondi mais une erreur.
    func testRoundingStaysWithinHalfAStop() {
        sweep { spec, condition, iso, body, focal, _, result in
            guard !result.tooBright, !result.tooDark, result.shutter != nil else { return }
            XCTAssertLessThanOrEqual(
                abs(result.snapErrorStops), 0.51,
                "arrondi de \(result.snapErrorStops) IL — "
                    + situation(spec, condition, iso, body, focal))
        }
    }

    /// La règle du 1/focale doit être appliquée dans les deux sens : avertir
    /// quand il faut, et se taire quand la vitesse est suffisante. Un
    /// avertissement qui s'affiche tout le temps ne se lit plus.
    func testCameraShakeWarningIsConsistentWithTheRule() {
        sweep { spec, condition, iso, body, focal, input, result in
            guard input.handheld, let seconds = result.shutterSeconds else { return }
            let warned = result.advice.contains { $0.title.contains("bougé") }
            let limit = Assistant.handheldLimit(focal: focal)

            if seconds > limit * 2 {
                XCTAssertTrue(
                    warned, "flou de bougé non signalé — "
                        + situation(spec, condition, iso, body, focal))
            }
            if seconds < limit {
                XCTAssertFalse(
                    warned, "flou de bougé signalé à tort — "
                        + situation(spec, condition, iso, body, focal))
            }
        }
    }

    /// L'ouverture de départ doit toujours exister sur l'objectif.
    func testStartingApertureIsAlwaysOnTheLens() {
        for spec in Assistant.intents {
            for condition in Light.conditions {
                for iso in sensitivities {
                    let value = Assistant.startingAperture(
                        for: spec, available: apertures,
                        ev100: condition.ev100, iso: iso)
                    XCTAssertTrue(
                        apertures.contains(value),
                        "f/\(value) hors de l’objectif — \(spec.label) · \(condition.label)")
                }
            }
        }
    }

    /// Fermer d'un diaphragme double le temps de pose, toujours.
    ///
    /// La tolérance d'un dixième de diaphragme n'est pas du laxisme : la
    /// graduation gravée sur les bagues est arrondie — f/11 vaut en réalité
    /// 11,31 et f/22 vaut 22,63 —, si bien que deux crans successifs ne font
    /// jamais exactement un diaphragme. C'est la convention du matériel, et
    /// l'application doit compter comme lui.
    func testClosingOneStopDoublesTheExposure() {
        for condition in Light.conditions {
            for iso in sensitivities {
                for (open, closed) in zip(apertures, apertures.dropFirst()) {
                    let short = Exposure.shutterSeconds(
                        ev100: condition.ev100, iso: iso, aperture: open)
                    let long = Exposure.shutterSeconds(
                        ev100: condition.ev100, iso: iso, aperture: closed)
                    XCTAssertEqual(
                        log2(long / short), 1, accuracy: 0.12,
                        "f/\(open) → f/\(closed) à \(Int(iso)) ISO")
                }
            }
        }
    }
}
