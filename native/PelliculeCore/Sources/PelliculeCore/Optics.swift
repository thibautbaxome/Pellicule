import Foundation

/// Correction de réciprocité, portée depuis la version web.
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
