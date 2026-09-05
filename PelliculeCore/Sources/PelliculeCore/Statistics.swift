import Foundation

/// Ce que le carnet sait dire de lui-même, une fois qu'il a quelques rouleaux.
///
/// Rien de savant : des comptes. Mais ce sont ceux qu'on se pose vraiment — ce
/// que coûte une vue, quelle émulsion on emploie le plus, combien de rouleaux
/// dorment au laboratoire. Tout est calculé ici, testé, et l'écran ne fait
/// qu'afficher.
public enum Statistics {

    public struct FilmUsage: Sendable, Equatable, Identifiable {
        public let filmId: String
        public let name: String
        public let rolls: Int
        public let frames: Int
        public var id: String { filmId }
    }

    public struct Summary: Sendable, Equatable {
        public let rolls: Int
        public let openRolls: Int
        public let rollsByStatus: [Model.RollStatus: Int]
        public let frames: Int
        public let framesWithLocation: Int
        public let framesKept: Int
        /// Coût total connu, toutes lignes confondues.
        public let totalCost: Double
        /// Coût par vue, sur les seuls rouleaux dont on connaît le coût.
        public let costPerFrame: Double?
        public let films: [FilmUsage]
        public let mostUsedShutter: String?
        public let mostUsedAperture: Double?
    }

    public static func summary(
        rolls: [Model.Roll],
        frames: [Model.Frame],
        filmName: (String) -> String?
    ) -> Summary {
        var byStatus: [Model.RollStatus: Int] = [:]
        for roll in rolls { byStatus[roll.status, default: 0] += 1 }

        let framesByRoll = Dictionary(grouping: frames, by: \.rollId)

        // Le coût par vue ne se calcule que sur les rouleaux chiffrés : diviser
        // le total par toutes les vues, y compris celles des rouleaux sans
        // coût, donnerait un chiffre faussement bas. Un rouleau encore dans le
        // boîtier compte pour ses poses annoncées, pas pour les vues déjà
        // notées : sinon le chiffre baisserait à chaque déclenchement.
        var costedFrames = 0
        var totalCost = 0.0
        for roll in rolls {
            guard let costs = roll.costs, costs.total > 0 else { continue }
            totalCost += costs.total
            let noted = framesByRoll[roll.id]?.count ?? 0
            costedFrames += roll.status.isOpen ? max(noted, roll.exposures) : noted
        }

        var usage: [String: (rolls: Int, frames: Int)] = [:]
        for roll in rolls {
            let current = usage[roll.filmStockId] ?? (0, 0)
            usage[roll.filmStockId] = (
                current.rolls + 1,
                current.frames + (framesByRoll[roll.id]?.count ?? 0))
        }
        let films = usage
            .map { FilmUsage(
                filmId: $0.key, name: filmName($0.key) ?? $0.key,
                rolls: $0.value.rolls, frames: $0.value.frames) }
            .sorted { ($0.frames, $0.name) > ($1.frames, $1.name) }

        return Summary(
            rolls: rolls.count,
            openRolls: rolls.filter(\.status.isOpen).count,
            rollsByStatus: byStatus,
            frames: frames.count,
            framesWithLocation: frames.filter { $0.location != nil }.count,
            framesKept: frames.filter { $0.status == .keep || $0.status == .printed }.count,
            totalCost: totalCost,
            costPerFrame: costedFrames > 0 ? totalCost / Double(costedFrames) : nil,
            films: films,
            mostUsedShutter: mode(frames.compactMap(\.shutter)),
            mostUsedAperture: mode(frames.compactMap(\.aperture)))
    }

    /// La valeur la plus fréquente ; à égalité, la première rencontrée.
    static func mode<T: Hashable>(_ values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        var counts: [T: Int] = [:]
        var order: [T] = []
        for value in values {
            if counts[value] == nil { order.append(value) }
            counts[value, default: 0] += 1
        }
        return order.max { counts[$0]! < counts[$1]! }
    }
}
