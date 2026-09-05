import XCTest
@testable import PelliculeCore

/// Garde-fou des banques de matériel.
///
/// Les catalogues sont des fichiers JSON écrits à la main — c'est délibéré,
/// c'est ce qui permet d'ajouter son boîtier sans connaître Swift. Mais JSON
/// n'a ni commentaire, ni type, ni contrainte : rien n'y empêche d'écrire une
/// vitesse la plus rapide plus lente que la plus lente, ou une ouverture
/// maximale à f/22. Ces tests tiennent ce rôle.
///
/// Ils portent sur la cohérence, jamais sur l'exactitude historique : ils ne
/// sauront pas dire qu'un Nikon FM2 monte à 1/4000 et non à 1/2000. La règle du
/// projet reste qu'un champ vide vaut mieux qu'un champ deviné — un conseil
/// faux donné avec assurance est pire qu'un conseil absent.
final class CatalogValidationTests: XCTestCase {

    /// Les identifiants voyagent dans les sauvegardes des utilisateurs : ils ne
    /// doivent jamais changer, et rester lisibles pour qu'on repère un doublon
    /// à l'œil. D'où la forme imposée.
    private func assertIsSlug(_ id: String, _ label: String, line: UInt = #line) {
        XCTAssertFalse(id.isEmpty, "\(label) : identifiant vide", line: line)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        XCTAssertTrue(
            id.unicodeScalars.allSatisfy(allowed.contains),
            "\(label) : « \(id) » doit être en minuscules, sans accent ni espace",
            line: line)
    }

    // MARK: - Boîtiers

    func testCameraIdentifiersAreWellFormed() {
        for camera in Catalog.cameras {
            assertIsSlug(camera.id, camera.displayName)
            XCTAssertFalse(camera.brand.isEmpty, "\(camera.id) : marque vide")
            XCTAssertFalse(camera.model.isEmpty, "\(camera.id) : modèle vide")
            XCTAssertFalse(camera.mount.isEmpty, "\(camera.id) : monture vide")
        }
    }

    /// La plage de vitesses est le champ dont dépend tout l'assistant : c'est
    /// elle qui lui permet de dire « ce réglage sort de ce que ton boîtier sait
    /// faire ». Une plage incohérente le ferait mentir.
    func testShutterRangesAreCoherent() throws {
        for camera in Catalog.cameras {
            let fastest = camera.shutterFastest.map { label -> Double in
                let seconds = Exposure.seconds(from: label)
                XCTAssertNotNil(seconds, "\(camera.displayName) : vitesse « \(label) » illisible")
                return seconds ?? 0
            }
            let slowest = camera.shutterSlowest.map { label -> Double in
                let seconds = Exposure.seconds(from: label)
                XCTAssertNotNil(seconds, "\(camera.displayName) : vitesse « \(label) » illisible")
                return seconds ?? 0
            }

            if let fastest, let slowest {
                XCTAssertLessThan(
                    fastest, slowest,
                    "\(camera.displayName) : la vitesse la plus rapide "
                        + "(\(camera.shutterFastest!)) doit être plus courte que la plus lente "
                        + "(\(camera.shutterSlowest!)) — les deux sont probablement inversées")

                XCTAssertFalse(
                    Assistant.shutters(
                        in: Exposure.fullShutters,
                        fastest: camera.shutterFastest,
                        slowest: camera.shutterSlowest
                    ).isEmpty,
                    "\(camera.displayName) : aucune vitesse de la graduation normalisée "
                        + "ne tombe dans la plage déclarée")
            }
        }
    }

    /// Un boîtier a soit une monture, soit un objectif solidaire — jamais les
    /// deux, jamais aucun des deux. C'est cette distinction qui décide si
    /// l'application propose de choisir un objectif.
    func testFixedLensCamerasAreConsistent() {
        for camera in Catalog.cameras {
            let declaresFixedMount = camera.mount == Catalog.fixedMountName

            XCTAssertEqual(
                declaresFixedMount, camera.fixedLens != nil,
                "\(camera.displayName) : monture « \(camera.mount) » et objectif solidaire "
                    + "doivent aller de pair")

            if let lens = camera.fixedLens {
                XCTAssertGreaterThan(lens.focal, 0, "\(camera.displayName) : focale nulle")
                XCTAssertGreaterThan(
                    lens.maxAperture, 0, "\(camera.displayName) : ouverture nulle")
            }
        }
    }

    // MARK: - Objectifs

    func testLensesAreCoherent() {
        for lens in Catalog.lenses {
            assertIsSlug(lens.id, lens.name)
            XCTAssertFalse(lens.brand.isEmpty, "\(lens.id) : marque vide")
            XCTAssertFalse(lens.mount.isEmpty, "\(lens.id) : monture vide")

            XCTAssertGreaterThan(lens.focalMin, 0, "\(lens.name) : focale minimale nulle")
            XCTAssertLessThanOrEqual(
                lens.focalMin, lens.focalMax,
                "\(lens.name) : focales inversées (\(lens.focalMin)–\(lens.focalMax) mm)")

            // Une ouverture « maximale » porte le plus petit nombre : f/1.7 est
            // plus grande ouverture que f/16. L'erreur d'inversion est courante.
            XCTAssertLessThan(
                lens.maxAperture, lens.minAperture,
                "\(lens.name) : f/\(lens.maxAperture) et f/\(lens.minAperture) sont inversées — "
                    + "la plus grande ouverture porte le plus petit nombre")
            XCTAssertGreaterThan(lens.maxAperture, 0, "\(lens.name) : ouverture nulle")

            if let thread = lens.filterThread {
                XCTAssertTrue(
                    (20...127).contains(thread),
                    "\(lens.name) : diamètre de filtre de \(thread) mm invraisemblable")
            }
        }
    }

    /// Un objectif dont la monture n'existe sur aucun boîtier de la banque est
    /// invisible dans l'application : le sélecteur filtre par monture.
    func testEveryLensMountExistsOnSomeCamera() {
        let cameraMounts = Set(Catalog.cameras.map(\.mount))
        for lens in Catalog.lenses {
            XCTAssertTrue(
                cameraMounts.contains(lens.mount),
                "\(lens.name) : la monture « \(lens.mount) » n'existe sur aucun boîtier de la "
                    + "banque — l'objectif serait introuvable à la sélection")
        }
    }

    // MARK: - Pellicules

    func testFilmsAreCoherent() {
        for film in Catalog.films {
            assertIsSlug(film.id, film.displayName)
            XCTAssertFalse(film.brand.isEmpty, "\(film.id) : marque vide")
            XCTAssertFalse(film.process.isEmpty, "\(film.id) : procédé vide")

            XCTAssertGreaterThan(film.iso, 0, "\(film.displayName) : sensibilité nulle")
            XCTAssertTrue(
                (1...12800).contains(film.iso),
                "\(film.displayName) : sensibilité de \(Int(film.iso)) ISO invraisemblable")

            XCTAssertTrue(
                (12...40).contains(film.defaultExposures),
                "\(film.displayName) : \(film.defaultExposures) poses invraisemblable en 135")
        }
    }

    /// La réciprocité gouverne les poses longues : un exposant erroné se
    /// traduit directement par un négatif sous-exposé.
    func testReciprocityCurvesArePlausible() {
        for film in Catalog.films {
            let model = film.reciprocityModel

            // Un exposant inférieur à 1 raccourcirait la pose : aucun film ne
            // se comporte ainsi. Au-delà de 1,5, la correction devient telle
            // qu'il s'agit presque sûrement d'une faute de saisie.
            XCTAssertTrue(
                (1.0...1.5).contains(model.exponent),
                "\(film.displayName) : exposant de réciprocité de \(model.exponent) "
                    + "hors du domaine plausible")
            XCTAssertGreaterThan(
                model.thresholdSeconds, 0,
                "\(film.displayName) : seuil de réciprocité nul")

            // Sous le seuil, on ne corrige pas ; au-dessus, la pose s'allonge.
            let short = model.thresholdSeconds / 2
            XCTAssertEqual(
                model.corrected(measured: short), short, accuracy: 1e-9,
                "\(film.displayName) : correction appliquée sous le seuil")
            if model.exponent > 1 {
                let long = model.thresholdSeconds * 10
                XCTAssertGreaterThan(
                    model.corrected(measured: long), long,
                    "\(film.displayName) : la pose devrait s'allonger au-delà du seuil")
            }
        }
    }

    /// Les temps de développement sont ce qu'on lit la minuterie à la main : un
    /// nombre faux gâche un rouleau entier, sans retour possible.
    func testDevelopmentTimesArePlausible() {
        for film in Catalog.films {
            for time in film.devTimes ?? [] {
                XCTAssertFalse(
                    time.developer.isEmpty, "\(film.displayName) : révélateur sans nom")
                XCTAssertTrue(
                    (60...3600).contains(time.timeSec),
                    "\(film.displayName) / \(time.developer) : \(Int(time.timeSec)) s "
                        + "hors du domaine plausible (1 min à 1 h)")
                XCTAssertTrue(
                    (14...30).contains(time.tempC),
                    "\(film.displayName) / \(time.developer) : \(time.tempC) °C "
                        + "hors du domaine plausible")
                XCTAssertGreaterThan(
                    time.iso, 0, "\(film.displayName) / \(time.developer) : sensibilité nulle")
            }
        }
    }

    /// Seul le noir et blanc se développe à la maison : un temps de
    /// développement sur un film couleur relèverait d'une confusion de procédé.
    func testOnlyBlackAndWhiteFilmsCarryDevelopmentTimes() {
        for film in Catalog.films where !(film.devTimes ?? []).isEmpty {
            XCTAssertEqual(
                film.type, .blackAndWhite,
                "\(film.displayName) : des temps de développement sur un film \(film.type.label)")
        }
    }
}
