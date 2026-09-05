import Foundation

/// Correction de réciprocité.
public struct ReciprocityModel: Sendable {
    /// Exposant de la loi de puissance. 1,0 = film sans défaut de réciprocité.
    public let exponent: Double
    /// Seuil en secondes en dessous duquel on ne corrige pas.
    public let thresholdSeconds: Double

    public init(exponent: Double, thresholdSeconds: Double) {
        self.exponent = exponent
        self.thresholdSeconds = thresholdSeconds
    }

    /// Temps réellement à poser pour un temps mesuré à la cellule.
    public func corrected(measured seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        guard seconds >= thresholdSeconds, exponent > 1 else { return seconds }
        return pow(seconds, exponent)
    }
}

/// Profondeur de champ et hyperfocale. Distances en mètres, focales en mm.
public struct DepthOfField: Sendable {
    public let hyperfocal: Double
    public let near: Double
    /// `.infinity` dès que la mise au point atteint l'hyperfocale.
    public let far: Double

    public var isFarInfinite: Bool { !far.isFinite }
}

public enum Optics {

    /// Cercle de confusion usuel en 24×36, pour un tirage courant.
    public static let defaultCircleOfConfusion = 0.03

    public static func hyperfocal(
        focal: Double,
        aperture: Double,
        circleOfConfusion: Double = defaultCircleOfConfusion
    ) -> Double {
        ((focal * focal) / (aperture * circleOfConfusion) + focal) / 1000
    }

    /// Filtre gris neutre capable de retirer un nombre donné de diaphragmes,
    /// dans la désignation qu'on lit sur la bague.
    ///
    /// « Il faut un filtre gris neutre » ne sert à rien à qui n'en a jamais
    /// acheté : ce qu'il faut savoir, c'est lequel. La force se compte en
    /// diaphragmes et se vend sous un facteur — six diaphragmes, c'est un ND64.
    /// On arrondit vers le haut : un filtre trop fort se rattrape en ouvrant,
    /// un filtre trop faible ne se rattrape pas.
    public struct NeutralDensity: Sendable, Equatable {
        public let stops: Int
        /// Désignation commerciale, quand elle existe.
        public let name: String?
        /// Faux au-delà de ce qu'un filtre du commerce retire : il faut alors
        /// renoncer, pas empiler des verres jusqu'à l'absurde.
        public var isAvailable: Bool { name != nil }
    }

    public static func neutralDensity(removingStops stops: Double) -> NeutralDensity? {
        let needed = Int(stops.rounded(.up))
        guard needed >= 1 else { return nil }
        // Au-delà de dix diaphragmes, on quitte ce qui se trouve en boutique.
        guard needed <= 10 else { return NeutralDensity(stops: needed, name: nil) }
        // Le ND1000 est vendu pour dix diaphragmes bien qu'il en retire 1024.
        return NeutralDensity(stops: needed, name: needed == 10 ? "ND1000" : "ND\(1 << needed)")
    }

    public static func depthOfField(
        focal: Double,
        aperture: Double,
        distance: Double,
        circleOfConfusion: Double = defaultCircleOfConfusion
    ) -> DepthOfField? {
        guard focal > 0, aperture > 0, distance > 0, circleOfConfusion > 0 else { return nil }

        // Tout le calcul se fait en millimètres, puis on revient aux mètres.
        let subject = distance * 1000
        let h = (focal * focal) / (aperture * circleOfConfusion) + focal

        let near = (subject * (h - focal)) / (h + subject - 2 * focal)

        // Au-delà de l'hyperfocale, la limite lointaine part à l'infini.
        let denominator = h - subject
        let far = denominator <= 0 ? Double.infinity : (subject * (h - focal)) / denominator

        return DepthOfField(
            hyperfocal: h / 1000,
            near: near / 1000,
            far: far.isFinite ? far / 1000 : .infinity
        )
    }
}
