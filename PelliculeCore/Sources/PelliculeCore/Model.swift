import Foundation

/// Modèle de données du carnet.
///
/// Ce sont des structures Swift ordinaires, indépendantes de tout mécanisme de
/// persistance : elles se décodent depuis les sauvegardes JSON et servent de
/// socle aux entités SwiftData. Les séparer laisse tout le domaine testable sur
/// Linux, sans SDK Apple.
///
/// Les noms de champs sont ceux du format de sauvegarde, et ne doivent pas en
/// dévier : une divergence ferait perdre des données à l'import, sans erreur
/// visible.
public enum Model {

    // MARK: - Matériel

    public struct Camera: Codable, Sendable, Identifiable, Hashable {
        public var id: String
        public var name: String
        public var make: String?
        public var model: String?
        public var serial: String?
        public var mount: String?
        public var meterBiasStops: Double?
        public var shutterFastest: String?
        public var shutterSlowest: String?
        public var fixedLens: FixedLens?
        public var notes: String?
        public var archived: Bool
        public var createdAt: String
        public var updatedAt: String

        public struct FixedLens: Codable, Sendable, Hashable {
            public var focal: Double
            public var maxAperture: Double
            public var minAperture: Double?
        }

        /// Vitesses réellement disponibles, pour l'assistant.
        public var availableShutters: [String] {
            Assistant.shutters(
                in: Exposure.fullShutters,
                fastest: shutterFastest,
                slowest: shutterSlowest)
        }
    }

    public struct Lens: Codable, Sendable, Identifiable, Hashable {
        public var id: String
        public var name: String
        public var make: String?
        public var model: String?
        public var serial: String?
        public var mount: String?
        public var focalMin: Double
        public var focalMax: Double
        public var maxAperture: Double?
        public var minAperture: Double?
        public var filterThread: Double?
        public var notes: String?
        public var archived: Bool
        public var createdAt: String
        public var updatedAt: String

        public var isPrime: Bool { focalMin == focalMax }
    }

    public struct FilmStock: Codable, Sendable, Identifiable, Hashable {
        public var id: String
        public var brand: String
        public var name: String
        public var iso: Double
        public var type: Catalog.FilmType
        public var process: String
        public var defaultExposures: Int
        public var reciprocity: Reciprocity
        public var devTimes: [Catalog.DevTime]?
        public var notes: String?
        public var isCustom: Bool
        public var discontinued: Bool?
        public var createdAt: String
        public var updatedAt: String

        public struct Reciprocity: Codable, Sendable, Hashable {
            public var exponent: Double
            public var thresholdSec: Double
            public var colorShiftNote: String?
        }

        public var model: ReciprocityModel {
            ReciprocityModel(
                exponent: reciprocity.exponent,
                thresholdSeconds: reciprocity.thresholdSec)
        }

        public var displayName: String { "\(brand) \(name)" }
    }

    // MARK: - Rouleaux

    /// Cycle de vie d'un rouleau, dans l'ordre de la progression normale.
    public enum RollStatus: String, Codable, Sendable, CaseIterable {
        case loaded, shooting, finished
        case atLab = "at_lab"
        case developed, scanned, archived

        public var label: String {
            switch self {
            case .loaded: "Chargé"
            case .shooting: "En cours"
            case .finished: "Terminé"
            case .atLab: "Au labo"
            case .developed: "Développé"
            case .scanned: "Scanné"
            case .archived: "Archivé"
            }
        }

        /// Un rouleau est ouvert tant qu'on peut encore y ajouter des vues.
        public var isOpen: Bool { self == .loaded || self == .shooting }
    }

    public struct Roll: Codable, Sendable, Identifiable, Hashable {
        public var id: String
        public var label: String?
        public var filmStockId: String
        public var cameraId: String
        /// Sensibilité réellement employée : si elle diffère de l'ISO boîte,
        /// le rouleau est poussé ou retenu.
        public var shotIso: Double
        public var exposures: Int
        public var loadedAt: String
        public var finishedAt: String?
        public var status: RollStatus
        public var archiveRef: String?
        public var lab: String?
        public var development: Development?
        public var costs: Costs?
        public var notes: String?
        public var createdAt: String
        public var updatedAt: String

        public struct Development: Codable, Sendable, Hashable {
            /// Développé par le photographe plutôt qu'au laboratoire.
            /// Le champ s'appelle « self » dans le JSON web ; en Swift ce mot
            /// est réservé, d'où le renommage et la clé de décodage explicite.
            public var developedByOwner: Bool
            public var developer: String?
            public var dilution: String?
            public var timeSec: Double?
            public var tempC: Double?
            public var agitation: String?
            public var developedAt: String?
            public var notes: String?

            private enum CodingKeys: String, CodingKey {
                case developedByOwner = "self"
                case developer, dilution, timeSec, tempC, agitation, developedAt, notes
            }
        }

        public struct Costs: Codable, Sendable, Hashable {
            public var film: Double?
            public var development: Double?
            public var scan: Double?
            public var prints: Double?

            public var total: Double {
                [film, development, scan, prints].compactMap { $0 }.reduce(0, +)
            }
        }

        /// Écart en diaphragmes par rapport à l'ISO nominal du film.
        public func pushPullStops(boxIso: Double) -> Double {
            Exposure.pushPullStops(shotIso: shotIso, boxIso: boxIso)
        }
    }

    // MARK: - Vues

    public enum FrameStatus: String, Codable, Sendable, CaseIterable {
        case shot, keep, reject, printed

        public var label: String {
            switch self {
            case .shot: "Prise"
            case .keep: "À tirer"
            case .reject: "Ratée"
            case .printed: "Tirée"
            }
        }
    }

    public struct GeoLocation: Codable, Sendable, Hashable {
        public var lat: Double
        public var lon: Double
        public var accuracy: Double?
        public var altitude: Double?
        public var label: String?
    }

    public struct Frame: Codable, Sendable, Identifiable, Hashable {
        public var id: String
        public var rollId: String
        /// Numéro de vue sur le rouleau, à partir de 1.
        public var number: Int
        public var shotAt: String
        /// Vitesse sous forme canonique : « 1/125 », « 2s », « B ».
        public var shutter: String?
        public var aperture: Double?
        public var lensId: String?
        public var focal: Double?
        public var exposureComp: Double?
        public var meteringNote: String?
        public var filter: Filter?
        public var flash: Bool?
        public var focusDistance: Double?
        public var subject: String?
        public var notes: String?
        public var tags: [String]
        public var location: GeoLocation?
        public var lightNote: String?
        public var refPhotoId: String?
        public var status: FrameStatus
        public var rating: Int?
        public var createdAt: String
        public var updatedAt: String

        public struct Filter: Codable, Sendable, Hashable {
            public var name: String
            /// Facteur du filtre exprimé en diaphragmes.
            public var factorStops: Double
        }

        public var shutterSeconds: Double? {
            shutter.flatMap { Exposure.seconds(from: $0) }
        }
    }

    // MARK: - Réglages

    public struct Settings: Codable, Sendable {
        public var id: String
        public var theme: String
        public var currency: String
        public var stopIncrement: String
        public var autoGeolocate: Bool
        public var defaultCameraId: String?
        public var defaultLensId: String?
        public var defaultFilmStockId: String?
        public var defaultExposures: Int
        public var defaultLab: String?
        public var circleOfConfusion: Double
        public var updatedAt: String
    }
}
