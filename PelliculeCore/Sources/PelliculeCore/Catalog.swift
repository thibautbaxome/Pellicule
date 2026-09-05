import Foundation

/// Banques de matériel : pellicules, boîtiers, objectifs.
///
/// Les données sont décodées depuis les fichiers JSON empaquetés avec le
/// module, dans `Resources/`. Ce sont eux la source de vérité : on les édite à
/// la main, sans rien connaître de Swift, et posséder un boîtier absent de la
/// liste suffit pour l'ajouter. En contrepartie, JSON n'ayant ni commentaire ni
/// contrainte, c'est `CatalogValidationTests` qui tient lieu de garde-fou.
public enum Catalog {

    // MARK: - Pellicules

    public enum FilmType: String, Codable, Sendable, CaseIterable {
        case blackAndWhite = "bw"
        case colourNegative = "color_neg"
        case slide

        public var label: String {
            switch self {
            case .blackAndWhite: "Noir et blanc"
            case .colourNegative: "Négatif couleur"
            case .slide: "Diapositive"
            }
        }
    }

    public struct DevTime: Codable, Sendable, Hashable {
        public let developer: String
        public let dilution: String
        public let iso: Double
        public let timeSec: Double
        public let tempC: Double
    }

    public struct Film: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public let brand: String
        public let name: String
        public let iso: Double
        public let type: FilmType
        public let process: String
        public let defaultExposures: Int
        public let devTimes: [DevTime]?
        public let notes: String?
        public let discontinued: Bool?

        /// Le modèle de réciprocité arrive imbriqué dans le JSON ; on le
        /// reconstitue dans le type qu'utilise le reste du noyau.
        private let reciprocity: RawReciprocity

        private struct RawReciprocity: Codable, Sendable, Hashable {
            let exponent: Double
            let thresholdSec: Double
            let colorShiftNote: String?
        }

        public var reciprocityModel: ReciprocityModel {
            ReciprocityModel(
                exponent: reciprocity.exponent,
                thresholdSeconds: reciprocity.thresholdSec)
        }

        public var colourShiftNote: String? { reciprocity.colorShiftNote }
        public var displayName: String { "\(brand) \(name)" }
    }

    // MARK: - Boîtiers

    public enum CameraType: String, Codable, Sendable {
        case slr, rangefinder, compact, viewfinder

        public var label: String {
            switch self {
            case .slr: "Reflex"
            case .rangefinder: "Télémétrique"
            case .compact: "Compact"
            case .viewfinder: "Viseur direct"
            }
        }
    }

    public struct FixedLens: Codable, Sendable, Hashable {
        public let focal: Double
        public let maxAperture: Double
    }

    public struct Camera: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public let brand: String
        public let model: String
        /// « Fixe » pour un objectif solidaire du boîtier.
        public let mount: String
        public let type: CameraType
        public let years: String?
        public let shutterFastest: String?
        public let shutterSlowest: String?
        public let fixedLens: FixedLens?
        public let notes: String?

        public var displayName: String { "\(brand) \(model)" }
        public var hasInterchangeableLens: Bool { mount != fixedMountName }
    }

    /// Monture conventionnelle des appareils à objectif non interchangeable.
    public static let fixedMountName = "Fixe"

    // MARK: - Objectifs

    public struct Lens: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public let brand: String
        public let name: String
        public let mount: String
        public let focalMin: Double
        public let focalMax: Double
        public let maxAperture: Double
        public let minAperture: Double
        public let filterThread: Double?
        public let notes: String?

        public var isPrime: Bool { focalMin == focalMax }
        public var focalLabel: String {
            isPrime ? "\(Int(focalMin)) mm" : "\(Int(focalMin))–\(Int(focalMax)) mm"
        }
    }

    // MARK: - Chargement

    public static let films: [Film] = load("films")
    public static let cameras: [Camera] = load("cameras")
    public static let lenses: [Lens] = load("lenses")

    /// Montures distinctes du catalogue, pour filtrer les objectifs.
    public static let mounts: [String] = Set(cameras.map(\.mount))
        .subtracting([fixedMountName])
        .sorted()

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            // Une banque manquante est un défaut d'empaquetage, pas une
            // situation à gérer : mieux vaut le voir tout de suite.
            assertionFailure("Catalogue \(name).json absent du module")
            return []
        }
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            assertionFailure("Catalogue \(name).json illisible : \(error)")
            return []
        }
    }

    // MARK: - Recherche

    /// Insensible à la casse et aux accents, et acceptant les mots dans le
    /// désordre, pour que « minolta 300 » trouve le X-300.
    public static func normalise(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    public static func searchCameras(_ query: String, limit: Int = 24) -> [Camera] {
        let terms = normalise(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }

        return cameras.filter { camera in
            let haystack = normalise("\(camera.brand) \(camera.model) \(camera.mount)")
            return terms.allSatisfy { haystack.contains($0) }
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Sans recherche mais avec une monture connue, on propose d'emblée ce qui
    /// s'y monte : c'est le cas le plus fréquent.
    public static func searchLenses(
        _ query: String,
        mount: String? = nil,
        limit: Int = 24
    ) -> [Lens] {
        let pool = mount.map { m in lenses.filter { $0.mount == m } } ?? lenses
        let terms = normalise(query).split(separator: " ").map(String.init)

        guard !terms.isEmpty else {
            return mount == nil ? [] : Array(pool.prefix(limit))
        }

        return pool.filter { lens in
            // « zoom » doit trouver un 35-70 même quand son nom ne le dit pas.
            let kind = lens.isPrime ? "" : " zoom"
            let haystack = normalise("\(lens.brand) \(lens.name) \(lens.mount)\(kind)")
            return terms.allSatisfy { haystack.contains($0) }
        }
        .prefix(limit)
        .map { $0 }
    }

    public static func searchFilms(_ query: String, limit: Int = 24) -> [Film] {
        let terms = normalise(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }

        return films.filter { film in
            let haystack = normalise("\(film.brand) \(film.name)")
            return terms.allSatisfy { haystack.contains($0) }
        }
        .prefix(limit)
        .map { $0 }
    }
}
