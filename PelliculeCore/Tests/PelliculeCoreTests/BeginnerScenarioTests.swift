import XCTest
@testable import PelliculeCore

/// Ce qu'un débutant voit sur les scènes qu'il photographiera vraiment.
///
/// Les invariants du balayage disent que l'assistant ne se contredit jamais ;
/// ces tests-ci disent qu'il est *utile*. La différence n'est pas théorique :
/// avant eux, la scène la plus banale qui soit — un portrait par temps
/// couvert — ouvrait l'écran sur une erreur rouge, parce que « le plus de flou
/// possible » était pris au pied de la lettre plutôt que comme « le plus de
/// flou réalisable ».
final class BeginnerScenarioTests: XCTestCase {

    /// Le matériel de référence du projet.
    private let x300 = Assistant.shutters(
        in: Exposure.fullShutters, fastest: "1/1000", slowest: "1s")
    private let md50: [Double] = [1.7, 2, 2.8, 4, 5.6, 8, 11, 16]

    private func advise(
        _ intent: Assistant.Intent, _ conditionId: String, iso: Double = 400, focal: Double = 50
    ) throws -> (Assistant.Result, Double) {
        let spec = Assistant.spec(for: intent)
        let condition = try XCTUnwrap(Light.condition(id: conditionId))
        var desired: Double?
        if case .shutterSeconds(let seconds) = spec.target { desired = seconds }

        let aperture = Assistant.startingAperture(
            for: spec, available: md50, ev100: condition.ev100, iso: iso,
            availableShutters: x300)
        let result = Assistant.advise(Assistant.Input(
            ev100: condition.ev100, iso: iso, aperture: aperture,
            focal: focal, distance: 3, handheld: spec.handheld,
            availableShutters: x300, availableApertures: md50,
            reciprocity: ReciprocityModel(exponent: 1.28, thresholdSeconds: 1),
            desiredShutterSeconds: desired))
        return (result, aperture)
    }

    private func dangers(_ result: Assistant.Result) -> [String] {
        result.advice.filter { $0.level == .danger }.map(\.title)
    }

    /// Les scènes ordinaires doivent marcher du premier coup. C'est la
    /// promesse de l'écran : on dit ce qu'on veut, on obtient un réglage.
    func testEverydayScenesJustWork() throws {
        let everyday: [(Assistant.Intent, String, String)] = [
            (.portrait, "overcast", "portrait par temps couvert"),
            (.portrait, "open-shade", "portrait à l’ombre"),
            (.landscape, "sunny", "paysage en plein soleil"),
            (.landscape, "slight-overcast", "paysage sous un soleil voilé"),
            (.street, "open-shade", "rue en fin de journée"),
            (.street, "overcast", "rue par temps couvert"),
            (.action, "sunny", "sujet en mouvement au soleil"),
        ]

        for (intent, condition, what) in everyday {
            let (result, aperture) = try advise(intent, condition)
            XCTAssertFalse(result.tooBright || result.tooDark, "hors plage : \(what)")
            XCTAssertEqual(dangers(result), [], "erreur affichée sur un cas banal : \(what)")
            XCTAssertNotNil(result.shutter, "aucune vitesse proposée : \(what)")
            XCTAssertTrue(md50.contains(aperture), "f/\(aperture) n’existe pas : \(what)")
            XCTAssertTrue(
                result.advice.contains { $0.level == .good },
                "rien ne confirme au photographe que son réglage tient : \(what)")
        }
    }

    /// Un portrait par temps couvert doit ouvrir autant que le boîtier le
    /// permet, et pas davantage. C'est exactement le cas qui affichait une
    /// erreur rouge à l'ouverture de l'écran.
    func testPortraitOpensAsWideAsTheBodyAllows() throws {
        let (result, aperture) = try advise(.portrait, "overcast")
        XCTAssertEqual(result.shutter, "1/1000", "on cherche le flou, donc la vitesse la plus haute")
        XCTAssertEqual(aperture, 5.6)
        XCTAssertFalse(result.tooBright)
    }

    /// En pleine lumière, l'ouverture se ferme d'elle-même : plus de lumière,
    /// moins de flou possible. La progression doit être monotone.
    func testBrighterLightClosesTheAperture() throws {
        let dim = try advise(.portrait, "heavy-overcast").1
        let bright = try advise(.portrait, "sunny").1
        XCTAssertLessThan(dim, bright, "plus il y a de lumière, plus il faut fermer")
    }

    /// Une pose longue en plein jour est impossible sans filtre. L'application
    /// doit dire lequel — « il faut un filtre gris neutre » ne sert à rien à
    /// qui n'en a jamais acheté.
    func testDaylightLongExposureNamesTheFilter() throws {
        let (result, _) = try advise(.night, "heavy-overcast")
        let detail = result.advice.map(\.detail).joined(separator: " ")
        XCTAssertTrue(
            detail.contains("ND"),
            "la force du filtre doit être nommée : \(detail)")
        XCTAssertTrue(detail.contains("diaphragme"), detail)
    }

    /// Au-delà de ce que le commerce propose, il faut dire de renoncer, et non
    /// nommer un filtre qui n'existe pas.
    func testAnImpossibleLongExposureSaysToGiveUp() throws {
        let (result, _) = try advise(.night, "sunny")
        let detail = result.advice.map(\.detail).joined(separator: " ")
        XCTAssertTrue(
            detail.contains("hors de portée"),
            "onze diaphragmes ne se retirent pas : \(detail)")
        XCTAssertFalse(detail.contains("ND"), "aucun filtre du commerce ne convient : \(detail)")
    }

    /// Un film trop rapide pour la lumière est un problème de film, pas de
    /// patience : le dire, plutôt que de conseiller d'attendre le soir.
    func testTooFastAFilmIsNamedAsSuch() throws {
        let (result, aperture) = try advise(.portrait, "sunny", iso: 1600)
        XCTAssertEqual(aperture, 16, "l’ouverture doit déjà être au bout")
        let detail = result.advice.map(\.detail).joined(separator: " ")
        XCTAssertTrue(detail.contains("film moins sensible"), detail)
    }

    /// La rue de nuit à main levée n'est pas possible, et l'application doit
    /// le dire franchement plutôt que de proposer un réglage flou.
    func testNightStreetWarnsAboutCameraShake() throws {
        let (result, _) = try advise(.street, "street-night")
        XCTAssertTrue(
            result.advice.contains { $0.title.contains("bougé") && $0.level == .danger },
            "une pose d’une seconde à main levée doit être signalée")
    }

    /// Un intérieur ordinaire le soir demande la pleine ouverture : c'est la
    /// réalité de la photographie argentique en intérieur, et l'application ne
    /// doit pas la maquiller.
    func testOrdinaryInteriorNeedsTheLensWideOpen() throws {
        let (result, aperture) = try advise(.lowLight, "indoors-dim")
        XCTAssertEqual(aperture, 1.7, "il n’y a pas de marge en intérieur")
        XCTAssertNotNil(result.shutter)
        XCTAssertFalse(result.tooDark, "à f/1,7 le X-300 y arrive encore")
    }
}
