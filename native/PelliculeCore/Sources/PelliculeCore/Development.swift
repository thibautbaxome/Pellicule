import Foundation

/// Correction des temps de développement, portée depuis la version web.
///
/// Deux corrections se combinent : la température du bain et l'écart de
/// sensibilité. Les modèles reproduisent à quelques pourcents près les tables
/// publiées par Kodak et Ilford — ils cadrent une décision, ils ne remplacent
/// pas la notice du film.
public enum Development {

    /// Température de référence des notices, en degrés Celsius.
    public static let referenceTemperature = 20.0

    /// Un facteur 2,5 par tranche de 10 °C reproduit les tables classiques :
    /// la référence D-76 de 7 min à 20 °C tombe bien à 5 min à 24 °C.
    private static let q10 = 2.5

    public static func temperatureFactor(
        _ temperature: Double,
        reference: Double = referenceTemperature
    ) -> Double {
        pow(q10, (reference - temperature) / 10)
    }

    /// Un diaphragme poussé rallonge d'environ 35 %, un diaphragme retenu
    /// raccourcit d'un quart ; on prolonge continûment ces deux règles.
    public static func pushPullFactor(stops: Double) -> Double {
        guard stops != 0 else { return 1 }
        return stops > 0 ? pow(1.35, stops) : pow(0.75, -stops)
    }

    public struct Result: Sendable {
        public let baseSeconds: Double
        public let correctedSeconds: Double
        public let temperatureFactor: Double
        public let pushPullFactor: Double
        public let warnings: [String]
    }

    public static func time(
        base seconds: Double,
        temperature: Double = referenceTemperature,
        reference: Double = referenceTemperature,
        pushPullStops: Double = 0
    ) -> Result {
        let tFactor = temperatureFactor(temperature, reference: reference)
        let ppFactor = pushPullFactor(stops: pushPullStops)
        let corrected = seconds * tFactor * ppFactor

        var warnings: [String] = []
        // Sous cinq minutes, la moindre irrégularité d'agitation se voit.
        if corrected > 0 && corrected < 300 {
            warnings.append(
                "Sous 5 minutes, le développement devient difficile à rendre homogène : "
                    + "préférer une dilution plus forte ou une température plus basse."
            )
        }
        if temperature > 24 {
            warnings.append("Au-delà de 24 °C, le grain se creuse et l’émulsion se ramollit.")
        }
        if temperature < 18 {
            warnings.append(
                "Sous 18 °C, la plupart des révélateurs deviennent paresseux et irréguliers."
            )
        }
        if pushPullStops >= 3 {
            warnings.append(
                "Au-delà de +2 IL, le contraste grimpe fortement et les ombres se bouchent."
            )
        }

        return Result(
            baseSeconds: seconds,
            correctedSeconds: corrected,
            temperatureFactor: tFactor,
            pushPullFactor: ppFactor,
            warnings: warnings
        )
    }
}
