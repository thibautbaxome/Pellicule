import Foundation

/// Estimation de la lumière par la scène — la règle du f/16.
///
/// C'est le posemètre qui ne tombe jamais en panne de pile : en plein soleil, à
/// f/16, le temps de pose correct vaut l'inverse de la sensibilité du film —
/// 1/125 s à f/16 pour du 125 ISO. Chaque condition moins favorable ouvre d'un
/// diaphragme.
///
/// La méthode a exposé un siècle de photographie et reste juste à un
/// diaphragme près, ce que la latitude d'un négatif absorbe sans broncher. Elle
/// se décrit d'ailleurs mieux qu'elle ne se mesure : ce qu'on regarde, ce sont
/// les ombres — leur présence, la dureté de leurs bords —, pas un chiffre.
public enum Light {

    public struct Condition: Sendable, Identifiable, Hashable {
        public let id: String
        public let label: String
        /// Ouverture de l'énoncé mnémotechnique : celle qu'on emploie quand le
        /// temps de pose vaut 1/ISO. Elle sert à retenir la règle, pas à
        /// calculer — voir `pairings`.
        ///
        /// Absente en dessous de l'ombre ouverte : la règle du f/16 décrit la
        /// lumière du jour, et prolonger sa progression jusqu'à l'intérieur ou
        /// à la rue de nuit donnerait des ouvertures fausses de un à deux
        /// diaphragmes et demi. Un repère faux est pire qu'un repère absent.
        public let aperture: Double?
        /// Ce qu'on voit, pour reconnaître la condition sans instrument.
        public let shadows: String
        /// Indice de lumination à 100 ISO.
        public let ev100: Double
    }

    /// De la plus vive à la plus faible. L'écart est d'un diaphragme d'une
    /// ligne à l'autre, ce qui rend la graduation lisible comme une échelle.
    public static let conditions: [Condition] = [
        Condition(
            id: "snow-sand", label: "Neige ou sable", aperture: 22,
            shadows: "Surface très réfléchissante en plein soleil, ombres dures et découpées.",
            ev100: 16),
        Condition(
            id: "sunny", label: "Plein soleil", aperture: 16,
            shadows: "Ciel dégagé, ombres nettes aux contours francs.",
            ev100: 15),
        Condition(
            id: "slight-overcast", label: "Soleil voilé", aperture: 11,
            shadows: "Ombres présentes mais aux bords adoucis.",
            ev100: 14),
        Condition(
            id: "overcast", label: "Nuageux", aperture: 8,
            shadows: "Ombres à peine perceptibles.",
            ev100: 13),
        Condition(
            id: "heavy-overcast", label: "Très couvert", aperture: 5.6,
            shadows: "Plus aucune ombre portée, lumière parfaitement diffuse.",
            ev100: 12),
        Condition(
            id: "open-shade", label: "Ombre ouverte", aperture: 4,
            shadows: "À l’ombre d’un bâtiment sous un ciel clair, ou coucher de soleil.",
            ev100: 11),
        Condition(
            id: "indoors-bright", label: "Intérieur clair", aperture: nil,
            shadows: "Grande fenêtre en plein jour, pièce baignée de lumière.",
            ev100: 9),
        Condition(
            id: "indoors", label: "Intérieur bien éclairé", aperture: nil,
            shadows: "Pièce vivement éclairée le soir, plusieurs sources allumées.",
            ev100: 7),
        // Deux diaphragmes séparent une pièce vivement éclairée d'une pièce
        // ordinaire, et les tables publiées distinguent les deux. Ne garder
        // que la première sous un libellé décrivant la seconde faisait
        // sous-exposer de deux diaphragmes — ce qui, sur un négatif, ne se
        // rattrape pas au tirage.
        Condition(
            id: "indoors-dim", label: "Intérieur ordinaire", aperture: nil,
            shadows: "Une lampe ou deux, le soir. Il faut un film rapide, un appui, ou les deux.",
            ev100: 5),
        Condition(
            id: "street-night", label: "Rue de nuit", aperture: nil,
            shadows: "Éclairage public ordinaire. Une vitrine ou une façade éclairée vaut un diaphragme de plus.",
            ev100: 4),
    ]

    public static func condition(id: String) -> Condition? {
        conditions.first { $0.id == id }
    }

    /// Indice de lumination d'une condition pour une sensibilité donnée.
    public static func ev(for condition: Condition, iso: Double) -> Double {
        Exposure.ev(ev100: condition.ev100, iso: iso)
    }

    public struct Pairing: Sendable, Hashable {
        public let aperture: Double
        public let shutter: String
        public let seconds: Double
    }

    /// Décline une condition en tous les couples vitesse/ouverture équivalents.
    ///
    /// C'est la table qu'on lit sur le terrain : la même lumière se rend par
    /// f/2,8 au 1/2000 comme par f/16 au 1/60, et le choix entre les deux est
    /// une décision de photographe, pas de calcul.
    ///
    /// Les valeurs sont calculées depuis l'indice de lumination, et non depuis
    /// l'énoncé mnémotechnique « 1/ISO à f/16 ». Les deux ne coïncident pas
    /// tout à fait : à 100 ISO en plein soleil, la règle donne 1/100 quand
    /// l'indice donne 1/128, soit un tiers de diaphragme d'écart — l'énoncé
    /// arrondit dans le sens de la surexposition, ce qu'un négatif encaisse
    /// volontiers. Cet écart est sans conséquence sur le film ; deux réponses
    /// différentes dans la même application, si. C'est donc l'indice qui fait
    /// foi, ici comme dans l'assistant, et l'ouverture de référence de chaque
    /// condition ne sert plus qu'à retenir la règle.
    public static func pairings(
        iso: Double,
        condition: Condition,
        exposureCompStops: Double = 0
    ) -> [Pairing] {
        guard iso.isFinite, iso > 0 else { return [] }

        return Exposure.fullApertures
            .filter { $0 >= 1.4 && $0 <= 32 }
            .map { aperture in
                let seconds = Exposure.shutterSeconds(
                    ev100: condition.ev100, iso: iso, aperture: aperture)
                    * pow(2, exposureCompStops)
                return Pairing(
                    aperture: aperture,
                    shutter: Exposure.shutter(fromSeconds: seconds),
                    seconds: seconds)
            }
    }

    /// Écart, en diaphragmes, entre l'énoncé mnémotechnique de la condition et
    /// son indice de lumination. Sert à vérifier que la table livrée reste
    /// fidèle à la règle qu'elle prétend appliquer.
    static func mnemonicDrift(_ condition: Condition) -> Double? {
        guard let aperture = condition.aperture else { return nil }
        // « 1/ISO à l'ouverture de référence » vaut, à 100 ISO :
        let ruleEv = Exposure.av(aperture: aperture) + log2(100)
        return ruleEv - condition.ev100
    }
}
