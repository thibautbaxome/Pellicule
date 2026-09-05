import Foundation

/// Moteur de l'assistant de prise de vue.
///
/// Le principe tient en une équation : une fois la lumière mesurée et la
/// sensibilité connue, vitesse et ouverture sont liées. On en fixe une, l'autre
/// suit. Le reste — profondeur de champ, flou de bougé, sortie de plage du
/// boîtier — se déduit de ce couple.
///
/// Ce moteur ne décide rien à la place du photographe : il rend visibles les
/// conséquences de chaque réglage.
public enum Assistant {

    // MARK: - Intentions

    public enum Intent: String, CaseIterable, Sendable {
        case portrait, landscape, street, action, motion, lowLight, night
    }

    public struct IntentSpec: Sendable {
        public enum Target: Sendable {
            /// La plus grande ouverture de l'objectif : dépend du matériel.
            case widestAperture
            case aperture(Double)
            case shutterSeconds(Double)
        }

        public enum Focus: Sendable {
            case metres(Double)
            case hyperfocal
        }

        public let intent: Intent
        public let label: String
        public let target: Target
        public let focus: Focus
        /// Faux quand l'intention suppose un trépied.
        public let handheld: Bool
        public let goal: String
    }

    public static let intents: [IntentSpec] = [
        .init(intent: .portrait, label: "Portrait", target: .widestAperture,
              focus: .metres(2), handheld: true,
              goal: "Détacher le sujet d’un arrière-plan fondu."),
        .init(intent: .landscape, label: "Paysage", target: .aperture(11),
              focus: .hyperfocal, handheld: true,
              goal: "Tout net, du premier plan à l’horizon."),
        .init(intent: .street, label: "Rue", target: .aperture(8),
              focus: .hyperfocal, handheld: true,
              goal: "Déclencher sans mettre au point, en comptant sur la zone de netteté."),
        .init(intent: .action, label: "Mouvement", target: .shutterSeconds(1.0 / 500),
              focus: .metres(5), handheld: true,
              goal: "Figer un sujet qui bouge."),
        .init(intent: .motion, label: "Filé", target: .shutterSeconds(1.0 / 30),
              focus: .metres(5), handheld: true,
              goal: "Suivre le sujet pour le garder net sur un fond filant."),
        .init(intent: .lowLight, label: "Basse lumière", target: .widestAperture,
              focus: .metres(3), handheld: true,
              goal: "Récolter le maximum de lumière sans trépied."),
        .init(intent: .night, label: "Pose longue", target: .shutterSeconds(4),
              focus: .hyperfocal, handheld: false,
              goal: "Laisser le temps travailler : filés d’eau, traînées lumineuses."),
    ]

    public static func spec(for intent: Intent) -> IntentSpec {
        intents.first { $0.intent == intent } ?? intents[0]
    }

    // MARK: - Conseils

    public enum AdviceLevel: Sendable { case good, info, warning, danger }

    public struct Advice: Sendable {
        public let level: AdviceLevel
        public let title: String
        public let detail: String

        public init(level: AdviceLevel, title: String, detail: String) {
            self.level = level
            self.title = title
            self.detail = detail
        }
    }

    public struct Input: Sendable {
        public var ev100: Double
        public var iso: Double
        public var aperture: Double
        public var focal: Double
        public var distance: Double
        public var circleOfConfusion: Double
        public var handheld: Bool
        /// Vitesses réellement disponibles sur le boîtier.
        public var availableShutters: [String]
        /// Ouvertures réellement disponibles sur l'objectif.
        public var availableApertures: [Double]
        public var reciprocity: ReciprocityModel?
        /// Vitesse que l'intention cherche à obtenir, si elle en vise une.
        public var desiredShutterSeconds: Double?

        public init(
            ev100: Double, iso: Double, aperture: Double, focal: Double, distance: Double,
            circleOfConfusion: Double = Optics.defaultCircleOfConfusion,
            handheld: Bool = true,
            availableShutters: [String] = Exposure.fullShutters,
            availableApertures: [Double] = Exposure.fullApertures,
            reciprocity: ReciprocityModel? = nil,
            desiredShutterSeconds: Double? = nil
        ) {
            self.ev100 = ev100
            self.iso = iso
            self.aperture = aperture
            self.focal = focal
            self.distance = distance
            self.circleOfConfusion = circleOfConfusion
            self.handheld = handheld
            self.availableShutters = availableShutters
            self.availableApertures = availableApertures
            self.reciprocity = reciprocity
            self.desiredShutterSeconds = desiredShutterSeconds
        }
    }

    public struct Result: Sendable {
        public let idealSeconds: Double
        public let shutter: String?
        public let shutterSeconds: Double?
        public let snapErrorStops: Double
        public let tooBright: Bool
        public let tooDark: Bool
        public let depthOfField: DepthOfField?
        /// Ouverture à adopter pour ramener la pose dans la plage du boîtier.
        public let suggestedAperture: Double?
        public let advice: [Advice]
    }

    /// Vitesse plancher pour tenir l'appareil à la main : l'inverse de la
    /// focale. Règle empirique, mais éprouvée sur trois générations.
    public static func handheldLimit(focal: Double) -> Double {
        1 / max(focal, 1)
    }

    public static func advise(_ input: Input) -> Result {
        let ideal = Exposure.shutterSeconds(
            ev100: input.ev100, iso: input.iso, aperture: input.aperture)
        let shutter = Exposure.nearestShutter(in: input.availableShutters, to: ideal)
        let shutterSeconds = shutter.flatMap { Exposure.seconds(from: $0) }

        let allSeconds = input.availableShutters.compactMap { Exposure.seconds(from: $0) }
        let fastest = allSeconds.min()
        let slowest = allSeconds.max()

        let tooBright = fastest.map { ideal < $0 / 1.5 } ?? false
        let tooDark = slowest.map { ideal > $0 * 1.5 } ?? false

        let snapError = shutterSeconds.map { log2($0 / ideal) } ?? 0

        // La tolérance vaut un tiers de diaphragme : sur un négatif il ne se
        // voit pas, et il évite de conseiller f/16 quand f/11 suffisait — ce
        // qui ruinerait le flou d'arrière-plan qu'on cherchait justement.
        let thirdStop = pow(2.0, 1.0 / 6.0)
        var suggested: Double?
        if tooBright, let fastest {
            let needed = pow(2, (Exposure.ev(ev100: input.ev100, iso: input.iso)
                + log2(fastest)) / 2)
            suggested = input.availableApertures.first { $0 >= needed / thirdStop }
        } else if tooDark, let slowest {
            let limit = pow(2, (Exposure.ev(ev100: input.ev100, iso: input.iso)
                + log2(slowest)) / 2)
            suggested = input.availableApertures.reversed().first { $0 <= limit * thirdStop }
        }

        let dof = Optics.depthOfField(
            focal: input.focal, aperture: input.aperture,
            distance: input.distance, circleOfConfusion: input.circleOfConfusion)

        var advice: [Advice] = []

        if tooBright {
            advice.append(.init(
                level: .danger,
                title: "Trop de lumière pour ce réglage",
                detail: suggested.map {
                    "À \(formatAperture(input.aperture)), il faudrait poser plus court que le "
                        + "\(Exposure.shutter(fromSeconds: fastest ?? 0)) du boîtier. "
                        + "Fermez à \(formatAperture($0))."
                } ?? {
                    let excess = fastest.map { log2($0 / ideal) } ?? 0
                    // Ici l'ouverture est déjà au bout : le remède le plus
                    // simple n'est pas d'attendre le soir, c'est de charger un
                    // film moins sensible la prochaine fois.
                    return "Même au plus fermé, la scène est trop lumineuse pour cet obturateur. "
                        + remedy(forExcessStops: excess)
                        + " Un film moins sensible aurait évité cela."
                }()))
        }
        if tooDark {
            advice.append(.init(
                level: .danger,
                title: "Pas assez de lumière",
                detail: suggested.map {
                    "À \(formatAperture(input.aperture)), la pose dépasserait la vitesse la plus "
                        + "lente du boîtier. Ouvrez à \(formatAperture($0))."
                } ?? "Même à pleine ouverture, il faudrait poser plus longtemps que le boîtier "
                    + "ne le permet. Passez en pose B sur trépied — l’obturateur reste ouvert "
                    + "tant que vous appuyez —, ou chargez un film plus sensible."))
        }

        // Seulement quand la pose tient dans la plage du boîtier : hors plage,
        // l'écart ne vient pas de la lumière mais des limites de l'obturateur,
        // et le message précédent le dit déjà — plus justement.
        if !tooBright, !tooDark,
           let desired = input.desiredShutterSeconds, let actual = shutterSeconds {
            let gap = log2(actual / desired)
            if gap < -1 {
                // Dire « il faut un filtre » ne sert à rien à qui n'en a jamais
                // acheté : ce qu'il faut savoir, c'est lequel.
                advice.append(.init(
                    level: .warning,
                    title: "Trop de lumière pour poser aussi longtemps",
                    detail: "Cette intention vise \(Exposure.shutter(fromSeconds: desired)) ; la "
                        + "scène impose \(Exposure.shutter(fromSeconds: actual)). "
                        + remedy(forExcessStops: -gap)))
            } else if gap > 1 {
                advice.append(.init(
                    level: .warning,
                    title: "Pas assez de lumière pour cette vitesse",
                    detail: "Cette intention vise \(Exposure.shutter(fromSeconds: desired)) ; la "
                        + "scène ne permet que \(Exposure.shutter(fromSeconds: actual)). Montez "
                        + "en sensibilité, ou acceptez le flou."))
            }
        }

        if input.handheld, let actual = shutterSeconds {
            let limit = handheldLimit(focal: input.focal)
            if actual > limit * 2 {
                advice.append(.init(
                    level: .danger,
                    title: "Flou de bougé quasi certain",
                    detail: "À \(Int(input.focal)) mm, on ne tient guère en dessous du "
                        + "\(Exposure.shutter(fromSeconds: limit)). Cherchez un appui, ou un trépied."))
            } else if actual > limit * 1.05 {
                advice.append(.init(
                    level: .warning,
                    title: "Risque de flou de bougé",
                    detail: "La règle du 1/focale conseille au moins le "
                        + "\(Exposure.shutter(fromSeconds: limit)) à \(Int(input.focal)) mm."))
            }
        }

        // Sans objet quand la scène sort déjà de la plage : l'écart ne vient
        // alors pas d'un arrondi mais d'un réglage irréalisable, déjà signalé.
        if !tooBright, !tooDark, abs(snapError) > 0.34 {
            advice.append(.init(
                level: .info,
                title: "Exposition arrondie",
                detail: "La graduation du boîtier tombe à "
                    + "\(formatStops(abs(snapError))) diaphragme de l’exposition idéale. "
                    + "Sans conséquence sur un négatif, à surveiller sur une diapositive."))
        }

        if let model = input.reciprocity, let actual = shutterSeconds,
           actual >= model.thresholdSeconds, model.exponent > 1 {
            advice.append(.init(
                level: .warning,
                title: "Défaut de réciprocité",
                detail: "Sur une pose de cette durée, l’émulsion perd en sensibilité : posez "
                    + "plutôt \(Exposure.shutter(fromSeconds: model.corrected(measured: actual)))."))
        }

        if let dof, dof.isFarInfinite, input.distance >= dof.hyperfocal * 0.9 {
            advice.append(.init(
                level: .good,
                title: "Net jusqu’à l’infini",
                detail: "Mise au point à l’hyperfocale : tout est net à partir de "
                    + "\(formatMetres(dof.near)). Vous pouvez déclencher sans refaire le point."))
        }

        // Un écran muet laisse le débutant se demander si l'application a
        // compris sa question. Quand rien ne s'oppose au réglage, on le dit.
        if !advice.contains(where: { $0.level == .warning || $0.level == .danger }),
           let shutter, shutterSeconds != nil {
            advice.insert(.init(
                level: .good,
                title: "Ce réglage tient",
                detail: "\(shutter) à \(formatAperture(input.aperture)) : le boîtier sait le "
                    + "faire, et rien dans la scène ne s’y oppose."
                    + (dof.map { " Net de \(formatMetres($0.near)) à "
                        + ($0.isFarInfinite ? "l’infini." : "\(formatMetres($0.far)).") } ?? "")),
                at: 0)
        }

        return Result(
            idealSeconds: ideal,
            shutter: shutter,
            shutterSeconds: shutterSeconds,
            snapErrorStops: snapError,
            tooBright: tooBright,
            tooDark: tooDark,
            depthOfField: dof,
            suggestedAperture: suggested,
            advice: advice
        )
    }

    /// Ouverture de départ pour une intention, ramenée à ce que l'objectif
    /// permet. Quand l'intention pilote la vitesse, c'est l'ouverture qui s'y
    /// plie : on la déduit de la lumière et du temps visé.
    public static func startingAperture(
        for spec: IntentSpec,
        available: [Double],
        ev100: Double,
        iso: Double,
        availableShutters: [String] = Exposure.fullShutters
    ) -> Double {
        guard !available.isEmpty else { return 8 }

        let wished: Double
        switch spec.target {
        case .widestAperture:
            wished = available.min()!
        case .aperture(let value):
            wished = nearest(in: available, to: value)
        case .shutterSeconds(let seconds):
            let wanted = Exposure.aperture(ev100: ev100, iso: iso, seconds: seconds)
            wished = min(max(wanted, available.min()!), available.max()!)
        }
        return workable(
            wished, available: available, ev100: ev100, iso: iso,
            availableShutters: availableShutters)
    }

    /// Ramène une ouverture souhaitée à la plus proche que l'obturateur sache
    /// accompagner.
    ///
    /// Sans cela, un portrait par temps couvert ouvrait à pleine ouverture et
    /// l'écran s'ouvrait sur une erreur rouge : c'est la première chose qu'un
    /// débutant voyait de l'assistant, sur le cas le plus banal qui soit.
    /// Demander « le plus de flou possible », c'est demander le plus de flou
    /// *réalisable* — l'ouverture au-delà de laquelle le boîtier ne suit plus
    /// n'est pas un choix, c'est une impasse.
    static func workable(
        _ wished: Double,
        available: [Double],
        ev100: Double,
        iso: Double,
        availableShutters: [String]
    ) -> Double {
        let seconds = availableShutters.compactMap { Exposure.seconds(from: $0) }
        guard let fastest = seconds.min(), let slowest = seconds.max() else { return wished }

        // Un tiers de diaphragme de tolérance, comme partout ailleurs : il ne
        // se voit pas sur un négatif et évite de fermer pour rien.
        let thirdStop = pow(2.0, 1.0 / 6.0)
        let widestUsable = pow(2, (Exposure.ev(ev100: ev100, iso: iso) + log2(fastest)) / 2)
            / thirdStop
        let narrowestUsable = pow(2, (Exposure.ev(ev100: ev100, iso: iso) + log2(slowest)) / 2)
            * thirdStop

        // Le résultat doit toujours être un cran de la bague : une valeur
        // calculée comme f/11,45 ne se règle sur aucun objectif.
        if wished < widestUsable {
            // Trop de lumière pour ouvrir autant : fermer juste ce qu'il faut.
            return available.first { $0 >= widestUsable } ?? available.max()!
        }
        if wished > narrowestUsable {
            // Pas assez de lumière : ouvrir juste ce qu'il faut.
            return available.reversed().first { $0 <= narrowestUsable } ?? available.min()!
        }
        return nearest(in: available, to: wished)
    }

    /// Valeur de la graduation la plus proche d'une valeur théorique.
    public static func nearest(in scale: [Double], to value: Double) -> Double {
        scale.min { abs(log2($0) - log2(value)) < abs(log2($1) - log2(value)) } ?? value
    }

    /// Restreint la graduation complète à ce que le boîtier sait faire.
    public static func shutters(
        in scale: [String],
        fastest: String?,
        slowest: String?
    ) -> [String] {
        let fastestSeconds = fastest.flatMap { Exposure.seconds(from: $0) }
        let slowestSeconds = slowest.flatMap { Exposure.seconds(from: $0) }

        return scale.filter { label in
            guard let seconds = Exposure.seconds(from: label) else { return false }
            if let fastestSeconds, seconds < fastestSeconds - 1e-9 { return false }
            if let slowestSeconds, seconds > slowestSeconds + 1e-9 { return false }
            return true
        }
    }

    /// Ce qu'il reste à faire quand la scène est trop lumineuse.
    ///
    /// « Il faut un filtre gris neutre » ne sert à rien à qui n'en a jamais
    /// acheté : ce qu'il faut savoir, c'est lequel — et, au-delà de ce que le
    /// commerce propose, qu'il faut renoncer plutôt qu'empiler des verres.
    private static func remedy(forExcessStops stops: Double) -> String {
        guard let filter = Optics.neutralDensity(removingStops: stops) else {
            return "Attendez que la lumière baisse."
        }
        let missing = "Il manque \(filter.stops) diaphragme\(filter.stops > 1 ? "s" : "")"
        guard let name = filter.name else {
            return "\(missing), soit plus qu’aucun filtre du commerce ne retire. "
                + "À cette lumière, cette intention est hors de portée : "
                + "revenez à l’aube ou au crépuscule."
        }
        return "\(missing) : un filtre gris neutre \(name) les retire. "
            + "Sinon, attendez que la lumière baisse."
    }

    private static func formatAperture(_ value: Double) -> String {
        value == value.rounded() ? "f/\(Int(value))" : "f/\((value * 10).rounded() / 10)"
    }

    private static func formatMetres(_ value: Double) -> String {
        value < 1 ? "\(Int((value * 100).rounded())) cm" : "\((value * 10).rounded() / 10) m"
    }

    /// Un écart en diaphragmes, au dixième, à la française : « 0,5 », « 1 ».
    private static func formatStops(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}
