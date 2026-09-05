import Foundation

/// Mesure de la lumière par la caméra du téléphone.
///
/// Le principe tient en une phrase : un appareil en exposition automatique
/// choisit lui-même une ouverture, une vitesse et une sensibilité ; lire ce
/// qu'il a choisi, c'est lire la lumière qu'il a vue. Aucune autre méthode
/// n'est fiable — la clarté moyenne de l'image, elle, reste constante quelle
/// que soit la scène, puisque c'est précisément ce que la correction
/// automatique s'emploie à obtenir.
///
/// C'est cette lecture que les navigateurs refusent de publier, et la raison
/// pour laquelle ce carnet a quitté le web.
///
/// Ce fichier ne contient que l'arithmétique, sans le moindre appel aux SDK
/// Apple : il se vérifie donc ici, sur des valeurs connues, plutôt que sur un
/// téléphone où l'on ne saurait pas distinguer une erreur de calcul d'une
/// particularité du capteur.
public enum Meter {

    /// Indice de lumination à 100 ISO d'une scène, déduit des réglages retenus.
    ///
    /// De la définition même de l'IL : `EV = log2(N² / t)` à la sensibilité
    /// employée, ramené à 100 ISO.
    public static func exposureValue(
        aperture: Double,
        durationSeconds: Double,
        iso: Double
    ) -> Double? {
        guard aperture > 0, durationSeconds > 0, iso > 0,
              aperture.isFinite, durationSeconds.isFinite, iso.isFinite
        else { return nil }
        return log2(100 * aperture * aperture / (durationSeconds * iso))
    }

    /// Ce que la caméra a retenu, et ce qu'il faut en penser.
    public struct Reading: Sendable, Equatable {
        public let ev100: Double
        public let aperture: Double
        public let durationSeconds: Double
        public let iso: Double

        /// Vrai quand l'appareil est allé au bout de ce qu'il sait faire.
        ///
        /// La mesure n'est alors plus une mesure mais une borne : la scène est
        /// au moins aussi sombre, ou au moins aussi claire. Le dire vaut mieux
        /// que d'afficher un chiffre qui a l'air d'en être un.
        public let isAtLimit: Bool

        public init(
            ev100: Double, aperture: Double, durationSeconds: Double,
            iso: Double, isAtLimit: Bool
        ) {
            self.ev100 = ev100
            self.aperture = aperture
            self.durationSeconds = durationSeconds
            self.iso = iso
            self.isAtLimit = isAtLimit
        }
    }

    /// Bornes de l'appareil, pour savoir si la mesure en touche une.
    public struct DeviceLimits: Sendable, Equatable {
        public let shortestDuration: Double
        public let longestDuration: Double
        public let lowestISO: Double
        public let highestISO: Double

        public init(
            shortestDuration: Double, longestDuration: Double,
            lowestISO: Double, highestISO: Double
        ) {
            self.shortestDuration = shortestDuration
            self.longestDuration = longestDuration
            self.lowestISO = lowestISO
            self.highestISO = highestISO
        }
    }

    /// Écart admis avant de considérer qu'une borne est atteinte : un
    /// vingtième, soit bien en deçà du tiers de diaphragme qui commencerait à
    /// se voir.
    private static let limitTolerance = 0.05

    public static func reading(
        aperture: Double,
        durationSeconds: Double,
        iso: Double,
        limits: DeviceLimits?,
        calibrationStops: Double = 0
    ) -> Reading? {
        guard let raw = exposureValue(
            aperture: aperture, durationSeconds: durationSeconds, iso: iso)
        else { return nil }

        var atLimit = false
        if let limits {
            // Sombre : l'appareil a ouvert le temps et monté la sensibilité au
            // maximum. Clair : il les a poussés au minimum.
            let longEnough = durationSeconds >= limits.longestDuration * (1 - limitTolerance)
            let sensitiveEnough = iso >= limits.highestISO * (1 - limitTolerance)
            let shortEnough = durationSeconds <= limits.shortestDuration * (1 + limitTolerance)
            let insensitiveEnough = iso <= limits.lowestISO * (1 + limitTolerance)
            atLimit = (longEnough && sensitiveEnough) || (shortEnough && insensitiveEnough)
        }

        return Reading(
            ev100: raw + calibrationStops,
            aperture: aperture,
            durationSeconds: durationSeconds,
            iso: iso,
            isAtLimit: atLimit)
    }

    /// Condition nommée la plus proche d'une mesure.
    ///
    /// Sert à traduire un chiffre en quelque chose qu'on reconnaît : un
    /// débutant ne sait pas ce que vaut « IL 12,3 », mais il sait à quoi
    /// ressemble un ciel très couvert. C'est aussi ce qui permet de vérifier sa
    /// propre estimation contre la mesure — et donc d'apprendre à s'en passer.
    public static func nearestCondition(toEV100 ev100: Double) -> Light.Condition? {
        Light.conditions.min { abs($0.ev100 - ev100) < abs($1.ev100 - ev100) }
    }

    /// Écart, en diaphragmes, entre une estimation à l'œil et la mesure.
    /// Positif quand l'estimation annonce plus de lumière qu'il n'y en a.
    public static func drift(estimated: Light.Condition, measured ev100: Double) -> Double {
        estimated.ev100 - ev100
    }
}
