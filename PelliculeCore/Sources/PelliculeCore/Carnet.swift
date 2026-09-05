import Foundation
import Observation

/// Le carnet : matériel, rouleaux, vues, réglages, et leur persistance.
///
/// Il n'y a pas de base de données. Le carnet tient dans un fichier JSON, dont
/// le format est exactement celui de la sauvegarde — exporter revient donc à
/// copier le fichier, et importer à le relire. Ce choix a trois conséquences
/// qui valent mieux qu'un moteur de persistance :
///
/// - un seul modèle de données, celui de `Model`, au lieu d'un modèle de
///   domaine doublé d'un modèle de stockage qu'il faudrait tenir synchronisés ;
/// - aucune migration à écrire, puisque le format de sauvegarde en porte déjà
///   la version et le refus des versions plus récentes ;
/// - aucune dépendance aux SDK Apple, donc tout ceci se teste sur Linux, y
///   compris l'écriture sur disque.
///
/// Le volume le justifie : un rouleau de 36 poses pèse une quinzaine de
/// kilo-octets. Il faudrait des décennies de pratique assidue pour que la
/// lecture intégrale au démarrage devienne perceptible. Les photos de repérage,
/// elles, ne sont pas dans ce fichier — ce sont des fichiers à côté, désignés
/// par leur identifiant.
@Observable
public final class Carnet {

    public private(set) var cameras: [Model.Camera] = []
    public private(set) var lenses: [Model.Lens] = []
    /// Pellicules connues du carnet. La banque livrée n'y est pas recopiée
    /// d'avance : une émulsion n'y entre qu'au chargement d'un rouleau, ce qui
    /// garde le fichier petit tout en le laissant autonome — une sauvegarde
    /// contient toujours les pellicules auxquelles ses rouleaux renvoient.
    public private(set) var films: [Model.FilmStock] = []
    public private(set) var rolls: [Model.Roll] = []
    public private(set) var frames: [Model.Frame] = []
    public private(set) var settings: Model.Settings

    /// Emplacement du fichier. Nil pour un carnet en mémoire, ce dont se
    /// servent les tests et les aperçus d'interface.
    private let fileURL: URL?
    private let now: () -> Date
    private let makeID: () -> String

    /// Vrai quand la relecture du fichier a échoué.
    ///
    /// Le carnet refuse alors toute écriture. C'est la précaution la plus
    /// importante du fichier : un carnet qu'on n'a pas su lire contient
    /// peut-être des années de prises de vue, et l'écraser par un carnet vide
    /// à la première saisie les effacerait définitivement. Mieux vaut une
    /// application inutilisable qu'une application destructrice.
    public private(set) var isSealed = false

    /// Dernière erreur d'écriture, s'il y en a eu une.
    ///
    /// Une écriture qui échoue ne doit pas faire perdre la saisie en cours : la
    /// modification reste en mémoire et l'interface peut la signaler. C'est
    /// pour cela que les mutations ne lancent pas d'erreur.
    public private(set) var lastWriteError: String?

    public init(
        fileURL: URL?,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.fileURL = fileURL
        self.now = now
        self.makeID = makeID
        self.settings = Model.Settings.initial(at: Self.timestamp(now()))
    }

    // MARK: - Persistance

    /// Relit le carnet depuis le disque. Un fichier absent est un carnet neuf,
    /// pas une erreur.
    public func load() throws {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            adopt(try Backup.decode(from: Data(contentsOf: fileURL)))
            isSealed = false
        } catch {
            isSealed = true
            throw error
        }
    }

    private func adopt(_ backup: Backup) {
        cameras = backup.data.cameras
        lenses = backup.data.lenses
        films = backup.data.filmStocks
        rolls = backup.data.rolls
        frames = backup.data.frames
        if let stored = backup.data.settings.first { settings = stored }
    }

    /// Écrit le carnet. Appelée après chaque modification.
    ///
    /// L'écriture est atomique : une interruption laisse l'ancien fichier
    /// intact plutôt qu'un fichier tronqué. Perdre la dernière vue saisie est
    /// désagréable ; perdre le carnet entier ne doit pas pouvoir arriver.
    public func persist() {
        guard !isSealed else { return }
        guard let fileURL else { return }
        do {
            try backup(includingPhotos: false).encoded().write(to: fileURL, options: .atomic)
            lastWriteError = nil
        } catch {
            lastWriteError = String(describing: error)
        }
    }

    public func backup(includingPhotos: Bool, attachments: [Backup.Attachment] = []) -> Backup {
        Backup(
            format: Backup.formatName,
            version: Backup.currentVersion,
            exportedAt: Self.timestamp(now()),
            includesPhotos: includingPhotos,
            data: Backup.Payload(
                cameras: cameras, lenses: lenses, filmStocks: films,
                rolls: rolls, frames: frames, settings: [settings],
                attachments: attachments))
    }

    public enum RestoreMode: Sendable {
        /// Le carnet importé remplace l'existant.
        case replace
        /// Les entrées importées complètent l'existant ; à identifiant égal,
        /// c'est la plus récemment modifiée qui l'emporte.
        case merge
    }

    public func restore(_ backup: Backup, mode: RestoreMode) {
        switch mode {
        case .replace:
            adopt(backup)
        case .merge:
            cameras = Self.merged(cameras, backup.data.cameras, by: \.id, date: \.updatedAt)
            lenses = Self.merged(lenses, backup.data.lenses, by: \.id, date: \.updatedAt)
            films = Self.merged(films, backup.data.filmStocks, by: \.id, date: \.updatedAt)
            rolls = Self.merged(rolls, backup.data.rolls, by: \.id, date: \.updatedAt)
            frames = Self.merged(frames, backup.data.frames, by: \.id, date: \.updatedAt)
        }
        persist()
    }

    /// Fusion par identifiant, la date de modification tranchant les conflits.
    /// Les dates sont au format ISO 8601, dont l'ordre lexicographique suit
    /// l'ordre chronologique — la comparaison de chaînes suffit donc.
    private static func merged<T>(
        _ existing: [T], _ incoming: [T],
        by id: KeyPath<T, String>, date: KeyPath<T, String>
    ) -> [T] {
        // L'ordre d'ajout est conservé : un dictionnaire remettrait le
        // matériel dans un ordre différent à chaque import, et l'écran le suit.
        var result = existing
        var position = Dictionary(
            existing.enumerated().map { ($1[keyPath: id], $0) }, uniquingKeysWith: { a, _ in a })
        for item in incoming {
            let key = item[keyPath: id]
            if let index = position[key] {
                if result[index][keyPath: date] < item[keyPath: date] { result[index] = item }
            } else {
                position[key] = result.count
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Lectures

    /// Rouleaux encore dans un boîtier, du plus récemment chargé au plus ancien.
    public var openRolls: [Model.Roll] {
        rolls.filter(\.status.isOpen).sorted { $0.loadedAt > $1.loadedAt }
    }

    /// Rouleaux terminés, du plus récent au plus ancien.
    public var closedRolls: [Model.Roll] {
        rolls.filter { !$0.status.isOpen }.sorted { $0.loadedAt > $1.loadedAt }
    }

    public func roll(id: String) -> Model.Roll? { rolls.first { $0.id == id } }
    public func camera(id: String) -> Model.Camera? { cameras.first { $0.id == id } }
    public func lens(id: String) -> Model.Lens? { lenses.first { $0.id == id } }

    /// Une pellicule connue du carnet, ou à défaut la fiche de la banque
    /// livrée : un rouleau reste lisible même si son émulsion n'a pas encore
    /// été matérialisée.
    public func film(id: String) -> Model.FilmStock? {
        films.first { $0.id == id } ?? Catalog.films.first { $0.id == id }.map(Self.film(from:))
    }

    public func frames(ofRoll rollId: String) -> [Model.Frame] {
        frames.filter { $0.rollId == rollId }.sorted { $0.number < $1.number }
    }

    /// Objectifs montables sur un boîtier. Un boîtier à objectif solidaire n'en
    /// accepte aucun ; un boîtier sans monture déclarée les accepte tous, faute
    /// de pouvoir trancher.
    public func lenses(forCamera camera: Model.Camera) -> [Model.Lens] {
        guard camera.fixedLens == nil else { return [] }
        let available = lenses.filter { !$0.archived }
        guard let mount = camera.mount, mount != Catalog.fixedMountName else { return available }
        return available.filter { $0.mount == nil || $0.mount == mount }
    }

    /// Graduation d'ouvertures proposable, et si ses bornes sont une hypothèse.
    public struct ApertureRange: Sendable, Equatable {
        public let values: [Double]
        /// Vrai quand aucun objectif déclaré ne borne l'ouverture, et que la
        /// graduation repose donc sur une supposition.
        public let isAssumed: Bool
    }

    /// La plus grande ouverture qu'on suppose à un objectif inconnu.
    ///
    /// La graduation complète descend à f/1, que trois objectifs au monde
    /// atteignent. La proposer à quelqu'un qui n'a pas déclaré son objectif
    /// serait un conseil faux donné avec l'assurance des autres — exactement ce
    /// que ce projet refuse. f/2,8 est ce qu'un objectif courant permet à coup
    /// sûr, et l'interface a de quoi dire que c'est une hypothèse.
    public static let assumedWidestAperture = 2.8
    public static let assumedNarrowestAperture = 22.0

    public func apertureRange(forCamera camera: Model.Camera?, lensId: String?) -> ApertureRange {
        let lens = lensId.flatMap { self.lens(id: $0) }
        let declaredWidest = lens?.maxAperture ?? camera?.fixedLens?.maxAperture
        let declaredNarrowest = lens?.minAperture ?? camera?.fixedLens?.minAperture

        let widest = declaredWidest ?? Self.assumedWidestAperture
        let narrowest = declaredNarrowest ?? Self.assumedNarrowestAperture

        var values = Exposure.fullApertures.filter {
            $0 >= widest - 0.01 && $0 <= narrowest + 0.01
        }
        // Une ouverture maximale hors graduation — f/1,7, f/3,5 — est gravée
        // sur la bague : la taire ferait perdre un tiers de diaphragme au
        // photographe qui l'a précisément achetée pour cela.
        if let declaredWidest, !values.contains(where: { abs($0 - declaredWidest) < 0.01 }) {
            values.insert(declaredWidest, at: 0)
        }
        return ApertureRange(
            values: values.isEmpty ? [widest] : values,
            isAssumed: declaredWidest == nil)
    }

    public func nextFrameNumber(inRoll rollId: String) -> Int {
        (frames(ofRoll: rollId).map(\.number).max() ?? 0) + 1
    }

    /// Vrai si du matériel est employé par un rouleau : on l'archive alors au
    /// lieu de le supprimer, sans quoi les vues déjà saisies perdraient leur
    /// boîtier ou leur objectif.
    public func isUsed(cameraId: String) -> Bool { rolls.contains { $0.cameraId == cameraId } }
    public func isUsed(lensId: String) -> Bool { frames.contains { $0.lensId == lensId } }

    // MARK: - Écritures

    public func save(_ camera: Model.Camera) {
        cameras = Self.upserting(camera, in: cameras)
        persist()
    }

    public func save(_ lens: Model.Lens) {
        lenses = Self.upserting(lens, in: lenses)
        persist()
    }

    public func save(_ film: Model.FilmStock) {
        films = Self.upserting(film, in: films)
        persist()
    }

    public func save(_ roll: Model.Roll) {
        rolls = Self.upserting(roll, in: rolls)
        persist()
    }

    public func save(_ frame: Model.Frame) {
        frames = Self.upserting(frame, in: frames)
        // Poser la première vue fait passer le rouleau de « chargé » à « en
        // cours » : c'est un état qu'on ne pense jamais à changer soi-même.
        if var roll = roll(id: frame.rollId), roll.status == .loaded {
            roll.status = .shooting
            roll.updatedAt = Self.timestamp(now())
            rolls = Self.upserting(roll, in: rolls)
        }
        persist()
    }

    public func save(_ newSettings: Model.Settings) {
        settings = newSettings
        settings.updatedAt = Self.timestamp(now())
        persist()
    }

    /// Remplace l'entrée de même identifiant, ou ajoute à la fin.
    ///
    /// Volontairement sans `inout` : la propriété serait alors empruntée en
    /// écriture exclusive pendant que `persist` la relit pour former la
    /// sauvegarde, ce que Swift interdit — et signale par un arrêt du
    /// programme, non par une erreur.
    private static func upserting<T: Identifiable>(_ item: T, in collection: [T]) -> [T]
    where T.ID == String {
        var updated = collection
        if let index = updated.firstIndex(where: { $0.id == item.id }) {
            updated[index] = item
        } else {
            updated.append(item)
        }
        return updated
    }

    public func delete(cameraId: String) {
        cameras.removeAll { $0.id == cameraId }
        persist()
    }

    public func delete(lensId: String) {
        lenses.removeAll { $0.id == lensId }
        // Les vues gardent leur existence, elles perdent seulement l'objectif :
        // supprimer la vue avec l'objectif effacerait une prise de vue réelle.
        for index in frames.indices where frames[index].lensId == lensId {
            frames[index].lensId = nil
        }
        persist()
    }

    /// Supprime un rouleau et les vues qu'il porte : une vue sans rouleau n'a
    /// aucun sens et resterait invisible dans le carnet.
    public func delete(rollId: String) {
        rolls.removeAll { $0.id == rollId }
        frames.removeAll { $0.rollId == rollId }
        persist()
    }

    public func delete(frameId: String) {
        frames.removeAll { $0.id == frameId }
        persist()
    }

    // MARK: - Fabriques

    /// Ces méthodes remplissent identifiant et dates, que l'appelant n'a pas à
    /// connaître, et rattachent la fiche de la banque livrée quand il y en a
    /// une. Elles n'enregistrent rien : c'est `save` qui décide.

    public func makeCamera(from entry: Catalog.Camera) -> Model.Camera {
        let stamp = Self.timestamp(now())
        return Model.Camera(
            id: makeID(),
            name: entry.displayName,
            make: entry.brand,
            model: entry.model,
            serial: nil,
            mount: entry.mount,
            meterBiasStops: nil,
            shutterFastest: entry.shutterFastest,
            shutterSlowest: entry.shutterSlowest,
            fixedLens: entry.fixedLens.map {
                Model.Camera.FixedLens(focal: $0.focal, maxAperture: $0.maxAperture)
            },
            notes: entry.notes,
            archived: false,
            createdAt: stamp,
            updatedAt: stamp)
    }

    public func makeCamera(named name: String) -> Model.Camera {
        let stamp = Self.timestamp(now())
        return Model.Camera(
            id: makeID(), name: name, make: nil, model: nil, serial: nil, mount: nil,
            meterBiasStops: nil, shutterFastest: nil, shutterSlowest: nil, fixedLens: nil,
            notes: nil, archived: false, createdAt: stamp, updatedAt: stamp)
    }

    public func makeLens(from entry: Catalog.Lens) -> Model.Lens {
        let stamp = Self.timestamp(now())
        return Model.Lens(
            id: makeID(),
            name: "\(entry.brand) \(entry.name)",
            make: entry.brand,
            model: entry.name,
            serial: nil,
            mount: entry.mount,
            focalMin: entry.focalMin,
            focalMax: entry.focalMax,
            maxAperture: entry.maxAperture,
            minAperture: entry.minAperture,
            filterThread: entry.filterThread,
            notes: entry.notes,
            archived: false,
            createdAt: stamp,
            updatedAt: stamp)
    }

    public func makeLens(named name: String, focal: Double, maxAperture: Double) -> Model.Lens {
        let stamp = Self.timestamp(now())
        return Model.Lens(
            id: makeID(), name: name, make: nil, model: nil, serial: nil, mount: nil,
            focalMin: focal, focalMax: focal, maxAperture: maxAperture, minAperture: nil,
            filterThread: nil, notes: nil, archived: false, createdAt: stamp, updatedAt: stamp)
    }

    /// L'identifiant de la banque est repris tel quel : une pellicule
    /// matérialisée deux fois porterait deux fiches là où le photographe n'en
    /// voit qu'une.
    static func film(from entry: Catalog.Film) -> Model.FilmStock {
        Model.FilmStock(
            id: entry.id,
            brand: entry.brand,
            name: entry.name,
            iso: entry.iso,
            type: entry.type,
            process: entry.process,
            defaultExposures: entry.defaultExposures,
            reciprocity: Model.FilmStock.Reciprocity(
                exponent: entry.reciprocityModel.exponent,
                thresholdSec: entry.reciprocityModel.thresholdSeconds,
                colorShiftNote: entry.colourShiftNote),
            devTimes: entry.devTimes,
            notes: entry.notes,
            isCustom: false,
            discontinued: entry.discontinued,
            createdAt: "",
            updatedAt: "")
    }

    /// Charge un rouleau et matérialise au passage sa pellicule si le carnet ne
    /// la connaissait pas encore.
    public func loadRoll(
        film entry: Catalog.Film,
        camera: Model.Camera,
        shotIso: Double? = nil,
        exposures: Int? = nil,
        label: String? = nil
    ) -> Model.Roll {
        if !films.contains(where: { $0.id == entry.id }) {
            var stock = Self.film(from: entry)
            let stamp = Self.timestamp(now())
            stock.createdAt = stamp
            stock.updatedAt = stamp
            films.append(stock)
        }

        let stamp = Self.timestamp(now())
        return Model.Roll(
            id: makeID(),
            label: label,
            filmStockId: entry.id,
            cameraId: camera.id,
            shotIso: shotIso ?? entry.iso,
            exposures: exposures ?? entry.defaultExposures,
            loadedAt: stamp,
            finishedAt: nil,
            status: .loaded,
            archiveRef: nil,
            lab: settings.defaultLab,
            development: nil,
            costs: nil,
            notes: nil,
            createdAt: stamp,
            updatedAt: stamp)
    }

    /// Prépare la vue suivante d'un rouleau, en reprenant les réglages de la
    /// précédente : d'une vue à l'autre, la lumière change rarement du tout au
    /// tout, et c'est ce qui rend la saisie tenable sur le terrain.
    public func makeFrame(inRoll rollId: String) -> Model.Frame {
        let stamp = Self.timestamp(now())
        let previous = frames(ofRoll: rollId).last

        return Model.Frame(
            id: makeID(),
            rollId: rollId,
            number: nextFrameNumber(inRoll: rollId),
            shotAt: stamp,
            shutter: previous?.shutter,
            aperture: previous?.aperture,
            lensId: previous?.lensId ?? settings.defaultLensId,
            focal: previous?.focal,
            exposureComp: nil,
            meteringNote: nil,
            filter: previous?.filter,
            flash: nil,
            focusDistance: nil,
            subject: nil,
            notes: nil,
            tags: [],
            location: nil,
            lightNote: nil,
            refPhotoId: nil,
            status: .shot,
            rating: nil,
            createdAt: stamp,
            updatedAt: stamp)
    }

    // MARK: - Horodatage

    /// Format ISO 8601 avec fractions de seconde, celui du fichier de
    /// sauvegarde. Deux vues prises dans la même seconde restent ordonnables.
    public static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
