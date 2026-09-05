import Foundation

/// Facteurs de filtre.
///
/// Un filtre absorbe une partie de la lumière : son « facteur » est le
/// multiplicateur de temps de pose qu'il impose, et son équivalent en
/// diaphragmes vaut le logarithme binaire de ce facteur. Un orange de
/// facteur 4 coûte donc deux diaphragmes.
///
/// Les valeurs des filtres colorés valent pour la lumière du jour et un film
/// panchromatique. Sous éclairage tungstène, riche en rouge, un rouge coûte
/// moins cher et un bleu davantage — c'est dit plutôt que corrigé, faute d'une
/// valeur publiée sur laquelle s'appuyer.
public enum Filters {

    public enum Category: String, Sendable, CaseIterable {
        case blackAndWhite = "bw"
        case neutralDensity = "nd"
        case conversion = "color"
        case other

        public var label: String {
            switch self {
            case .blackAndWhite: "Noir et blanc"
            case .neutralDensity: "Gris neutre"
            case .conversion: "Conversion"
            case .other: "Autres"
            }
        }
    }

    public struct Preset: Sendable, Identifiable, Hashable {
        public let id: String
        public let name: String
        /// Multiplicateur du temps de pose.
        public let factor: Double
        public let category: Category
        /// Ce que le filtre fait à l'image, en une phrase.
        public let effect: String

        public var stops: Double { Filters.stops(fromFactor: factor) }
    }

    public static let presets: [Preset] = [
        // Filtres colorés pour le noir et blanc : ils éclaircissent leur propre
        // couleur et assombrissent la complémentaire.
        Preset(id: "yellow-8", name: "Jaune n°8", factor: 2, category: .blackAndWhite,
               effect: "Assombrit légèrement le ciel, rend les nuages lisibles."),
        Preset(id: "yellow-green-11", name: "Jaune-vert n°11", factor: 4, category: .blackAndWhite,
               effect: "Carnations plus naturelles, feuillages éclaircis."),
        Preset(id: "orange-16", name: "Orange n°16", factor: 4, category: .blackAndWhite,
               effect: "Ciel nettement plus sombre, brume atténuée."),
        Preset(id: "red-25", name: "Rouge n°25", factor: 8, category: .blackAndWhite,
               effect: "Ciel presque noir, contraste théâtral."),
        Preset(id: "green-58", name: "Vert n°58", factor: 8, category: .blackAndWhite,
               effect: "Sépare les verts du feuillage."),
        Preset(id: "blue-47", name: "Bleu n°47", factor: 8, category: .blackAndWhite,
               effect: "Accentue la brume atmosphérique."),

        // Densités neutres : pour poser long ou ouvrir grand en plein jour.
        Preset(id: "nd-2", name: "ND2", factor: 2, category: .neutralDensity, effect: "1 diaphragme"),
        Preset(id: "nd-4", name: "ND4", factor: 4, category: .neutralDensity, effect: "2 diaphragmes"),
        Preset(id: "nd-8", name: "ND8", factor: 8, category: .neutralDensity, effect: "3 diaphragmes"),
        Preset(id: "nd-16", name: "ND16", factor: 16, category: .neutralDensity, effect: "4 diaphragmes"),
        Preset(id: "nd-64", name: "ND64", factor: 64, category: .neutralDensity, effect: "6 diaphragmes"),
        Preset(id: "nd-1000", name: "ND1000", factor: 1000, category: .neutralDensity,
               effect: "10 diaphragmes"),

        Preset(id: "polarizer", name: "Polarisant", factor: 3, category: .other,
               effect: "Supprime les reflets, sature le ciel. De 1,5 à 2 diaphragmes selon l’orientation."),
        Preset(id: "uv", name: "UV / Skylight", factor: 1, category: .other,
               effect: "Aucune correction : sert de protection frontale."),
        Preset(id: "85b", name: "85B — tungstène vers jour", factor: 2, category: .conversion,
               effect: "Pour exposer un film tungstène en plein jour."),
        Preset(id: "80a", name: "80A — jour vers tungstène", factor: 4, category: .conversion,
               effect: "Pour exposer un film lumière du jour sous ampoule."),
        Preset(id: "r72", name: "Infrarouge R72", factor: 32, category: .other,
               effect: "Coupe le visible. Le facteur varie beaucoup selon le film : à essayer."),
    ]

    public static func preset(named name: String) -> Preset? {
        presets.first { $0.name == name }
    }

    public static func presets(in category: Category) -> [Preset] {
        presets.filter { $0.category == category }
    }

    public static func stops(fromFactor factor: Double) -> Double {
        guard factor.isFinite, factor > 0 else { return 0 }
        return log2(factor)
    }

    public static func factor(fromStops stops: Double) -> Double { pow(2, stops) }

    /// Filtres empilés : les diaphragmes s'additionnent, pas les facteurs.
    /// C'est l'erreur classique — deux ND4 donnent quatre diaphragmes, pas huit.
    public static func combinedStops(factors: [Double]) -> Double {
        factors.reduce(0) { $0 + stops(fromFactor: $1) }
    }
}
