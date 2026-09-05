import Foundation

/// Modèle de données du carnet.
///
/// Ce sont des structures Swift ordinaires : le carnet se range tel quel dans un
/// fichier JSON, et le format de ce fichier est celui de la sauvegarde. Aucun
/// SDK Apple n'intervient, si bien que tout le domaine reste testable sur Linux
/// — y compris le stockage.
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

            public init(focal: Double, maxAperture: Double, minAperture: Double? = nil) {
                self.focal = focal
                self.maxAperture = maxAperture
                self.minAperture = minAperture
            }
        }

        // Les initialiseurs publics n'ont volontairement aucune valeur par
        // défaut : ajouter un champ au modèle casse alors la compilation de
        // tout ce qui construit la valeur, au lieu de le laisser silencieusement
        // à zéro. C'est le seul garde-fou possible entre deux modules.
        public init(
            id: String, name: String, make: String?, model: String?, serial: String?,
            mount: String?, meterBiasStops: Double?, shutterFastest: String?,
            shutterSlowest: String?, fixedLens: FixedLens?, notes: String?,
            archived: Bool, createdAt: String, updatedAt: String
        ) {
            self.id = id
            self.name = name
            self.make = make
            self.model = model
            self.serial = serial
            self.mount = mount
            self.meterBiasStops = meterBiasStops
            self.shutterFastest = shutterFastest
            self.shutterSlowest = shutterSlowest
            self.fixedLens = fixedLens
            self.notes = notes
            self.archived = archived
            self.createdAt = createdAt
            self.updatedAt = updatedAt
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

        public init(
            id: String, name: String, make: String?, model: String?, serial: String?,
            mount: String?, focalMin: Double, focalMax: Double, maxAperture: Double?,
            minAperture: Double?, filterThread: Double?, notes: String?,
            archived: Bool, createdAt: String, updatedAt: String
        ) {
            self.id = id
            self.name = name
            self.make = make
            self.model = model
            self.serial = serial
            self.mount = mount
            self.focalMin = focalMin
            self.focalMax = focalMax
            self.maxAperture = maxAperture
            self.minAperture = minAperture
            self.filterThread = filterThread
            self.notes = notes
            self.archived = archived
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
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

            public init(exponent: Double, thresholdSec: Double, colorShiftNote: String? = nil) {
                self.exponent = exponent
                self.thresholdSec = thresholdSec
                self.colorShiftNote = colorShiftNote
            }
        }

        public init(
            id: String, brand: String, name: String, iso: Double, type: Catalog.FilmType,
            process: String, defaultExposures: Int, reciprocity: Reciprocity,
            devTimes: [Catalog.DevTime]?, notes: String?, isCustom: Bool,
            discontinued: Bool?, createdAt: String, updatedAt: String
        ) {
            self.id = id
            self.brand = brand
            self.name = name
            self.iso = iso
            self.type = type
            self.process = process
            self.defaultExposures = defaultExposures
            self.reciprocity = reciprocity
            self.devTimes = devTimes
            self.notes = notes
            self.isCustom = isCustom
            self.discontinued = discontinued
            self.createdAt = createdAt
            self.updatedAt = updatedAt
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

            public init(
                developedByOwner: Bool, developer: String?, dilution: String?,
                timeSec: Double?, tempC: Double?, agitation: String?,
                developedAt: String?, notes: String?
            ) {
                self.developedByOwner = developedByOwner
                self.developer = developer
                self.dilution = dilution
                self.timeSec = timeSec
                self.tempC = tempC
                self.agitation = agitation
                self.developedAt = developedAt
                self.notes = notes
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

            public init(
                film: Double?, development: Double?, scan: Double?, prints: Double?
            ) {
                self.film = film
                self.development = development
                self.scan = scan
                self.prints = prints
            }
        }

        public init(
            id: String, label: String?, filmStockId: String, cameraId: String,
            shotIso: Double, exposures: Int, loadedAt: String, finishedAt: String?,
            status: RollStatus, archiveRef: String?, lab: String?,
            development: Development?, costs: Costs?, notes: String?,
            createdAt: String, updatedAt: String
        ) {
            self.id = id
            self.label = label
            self.filmStockId = filmStockId
            self.cameraId = cameraId
            self.shotIso = shotIso
            self.exposures = exposures
            self.loadedAt = loadedAt
            self.finishedAt = finishedAt
            self.status = status
            self.archiveRef = archiveRef
            self.lab = lab
            self.development = development
            self.costs = costs
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
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

        public init(
            lat: Double, lon: Double, accuracy: Double? = nil,
            altitude: Double? = nil, label: String? = nil
        ) {
            self.lat = lat
            self.lon = lon
            self.accuracy = accuracy
            self.altitude = altitude
            self.label = label
        }
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

            public init(name: String, factorStops: Double) {
                self.name = name
                self.factorStops = factorStops
            }
        }

        public init(
            id: String, rollId: String, number: Int, shotAt: String, shutter: String?,
            aperture: Double?, lensId: String?, focal: Double?, exposureComp: Double?,
            meteringNote: String?, filter: Filter?, flash: Bool?, focusDistance: Double?,
            subject: String?, notes: String?, tags: [String], location: GeoLocation?,
            lightNote: String?, refPhotoId: String?, status: FrameStatus, rating: Int?,
            createdAt: String, updatedAt: String
        ) {
            self.id = id
            self.rollId = rollId
            self.number = number
            self.shotAt = shotAt
            self.shutter = shutter
            self.aperture = aperture
            self.lensId = lensId
            self.focal = focal
            self.exposureComp = exposureComp
            self.meteringNote = meteringNote
            self.filter = filter
            self.flash = flash
            self.focusDistance = focusDistance
            self.subject = subject
            self.notes = notes
            self.tags = tags
            self.location = location
            self.lightNote = lightNote
            self.refPhotoId = refPhotoId
            self.status = status
            self.rating = rating
            self.createdAt = createdAt
            self.updatedAt = updatedAt
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

        public init(
            id: String, theme: String, currency: String, stopIncrement: String,
            autoGeolocate: Bool, defaultCameraId: String?, defaultLensId: String?,
            defaultFilmStockId: String?, defaultExposures: Int, defaultLab: String?,
            circleOfConfusion: Double, updatedAt: String
        ) {
            self.id = id
            self.theme = theme
            self.currency = currency
            self.stopIncrement = stopIncrement
            self.autoGeolocate = autoGeolocate
            self.defaultCameraId = defaultCameraId
            self.defaultLensId = defaultLensId
            self.defaultFilmStockId = defaultFilmStockId
            self.defaultExposures = defaultExposures
            self.defaultLab = defaultLab
            self.circleOfConfusion = circleOfConfusion
            self.updatedAt = updatedAt
        }

        /// Réglages d'un carnet neuf. Le cercle de confusion est celui du 24×36,
        /// valeur d'usage pour la profondeur de champ.
        public static func initial(at now: String) -> Settings {
            Settings(
                id: "settings", theme: "dark", currency: "EUR", stopIncrement: "third",
                autoGeolocate: true, defaultCameraId: nil, defaultLensId: nil,
                defaultFilmStockId: nil, defaultExposures: 36, defaultLab: nil,
                circleOfConfusion: 0.03, updatedAt: now)
        }
    }
}
