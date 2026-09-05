import Foundation

/// Échelles d'exposition argentiques, portées depuis la version web.
///
/// Tout passe par l'IL : une valeur en IL vaut le logarithme binaire du temps
/// ou du carré de l'ouverture, ce qui rend les additions triviales.
public enum Exposure {

    /// Vitesses de la graduation normalisée, de la plus lente à la plus rapide.
    public static let fullShutters: [String] = [
        "30s", "15s", "8s", "4s", "2s", "1s",
        "1/2", "1/4", "1/8", "1/15", "1/30", "1/60", "1/125", "1/250",
        "1/500", "1/1000", "1/2000", "1/4000", "1/8000",
    ]

    public static let fullApertures: [Double] = [
        1, 1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22, 32, 45, 64,
    ]

    /// Convertit un libellé de vitesse en secondes. Nil pour la pose B.
    public static func seconds(from shutter: String) -> Double? {
        let text = shutter.trimmingCharacters(in: .whitespaces)
        if text.uppercased() == "B" || text.isEmpty { return nil }

        if text.hasPrefix("1/") {
            guard let denominator = Double(text.dropFirst(2)), denominator > 0 else { return nil }
            return 1 / denominator
        }
        guard let value = Double(text.replacingOccurrences(of: "s", with: "")), value > 0 else {
            return nil
        }
        return value
    }

    /// Met un nombre de secondes sous la forme habituelle d'une graduation.
    public static func shutter(fromSeconds seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        if seconds >= 1 {
            let rounded = seconds >= 10 ? seconds.rounded() : (seconds * 10).rounded() / 10
            return "\(formatted(rounded))s"
        }
        let denominator = 1 / seconds
        let shown = denominator < 10 ? (denominator * 10).rounded() / 10 : denominator.rounded()
        return "1/\(formatted(shown))"
    }

    /// Valeur d'ouverture : f/1 vaut 0, f/1,4 vaut 1, f/2 vaut 2…
    public static func av(aperture: Double) -> Double { 2 * log2(aperture) }

    /// Indice de lumination de la scène pour la sensibilité employée.
    public static func ev(ev100: Double, iso: Double) -> Double {
        ev100 + log2(iso / 100)
    }

    /// Temps de pose théorique pour une ouverture donnée, en secondes.
    public static func shutterSeconds(ev100: Double, iso: Double, aperture: Double) -> Double {
        pow(2, av(aperture: aperture) - ev(ev100: ev100, iso: iso))
    }

    /// Ouverture théorique pour un temps de pose donné.
    public static func aperture(ev100: Double, iso: Double, seconds: Double) -> Double {
        pow(2, (ev(ev100: ev100, iso: iso) + log2(seconds)) / 2)
    }

    /// Vitesse de la graduation la plus proche d'une durée théorique.
    public static func nearestShutter(in scale: [String], to seconds: Double) -> String? {
        scale
            .compactMap { label -> (String, Double)? in
                guard let value = Self.seconds(from: label) else { return nil }
                return (label, abs(log2(value) - log2(seconds)))
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Écart en IL entre la sensibilité employée et l'ISO nominal du film.
    public static func pushPullStops(shotIso: Double, boxIso: Double) -> Double {
        guard shotIso > 0, boxIso > 0 else { return 0 }
        return log2(shotIso / boxIso)
    }

    private static func formatted(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%g", value)
    }
}
