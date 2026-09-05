import Foundation

/// Lecture et écriture des sauvegardes du carnet.
///
/// Le format sert deux usages. C'est d'abord la sauvegarde de l'application :
/// un fichier lisible, exportable, qui appartient au photographe et ne dépend
/// d'aucun service. C'est ensuite le chemin de reprise depuis la première
/// implémentation du carnet, en TypeScript, dont il conserve exactement les
/// noms de champs — quiconque y a déjà consigné des rouleaux les récupère ici
/// sans rien ressaisir.
public struct Backup: Codable, Sendable {

    public static let formatName = "pellicule-backup"
    public static let currentVersion = 1

    public let format: String
    public let version: Int
    public let exportedAt: String
    /// Les photos de repérage sont absentes des sauvegardes légères.
    public let includesPhotos: Bool
    public let data: Payload

    public struct Payload: Codable, Sendable {
        public var cameras: [Model.Camera]
        public var lenses: [Model.Lens]
        public var filmStocks: [Model.FilmStock]
        public var rolls: [Model.Roll]
        public var frames: [Model.Frame]
        public var settings: [Model.Settings]
        public var attachments: [Attachment]
    }

    public struct Attachment: Codable, Sendable, Identifiable {
        public var id: String
        public var mime: String
        public var width: Double?
        public var height: Double?
        public var createdAt: String
        /// Contenu de l'image, encodé en base64 sans préfixe de type.
        public var base64: String

        public var imageData: Data? { Data(base64Encoded: base64) }
    }

    public enum ImportError: Error, CustomStringConvertible, Equatable {
        case notABackup(String)
        case tooRecent(found: Int, supported: Int)

        public var description: String {
            switch self {
            case .notABackup(let found):
                "Ce fichier n’est pas une sauvegarde Pellicule (format « \(found) »)."
            case .tooRecent(let found, let supported):
                "Cette sauvegarde vient d’une version plus récente de l’application "
                    + "(format \(found), pris en charge jusqu’à \(supported)). "
                    + "Mettez l’application à jour avant de la restaurer."
            }
        }
    }

    /// Décode une sauvegarde et refuse ce qui n'en est pas une.
    ///
    /// Une version plus récente est rejetée plutôt que lue au mieux : mieux
    /// vaut un message clair qu'un carnet importé à moitié.
    public static func decode(from data: Data) throws -> Backup {
        let backup = try JSONDecoder().decode(Backup.self, from: data)

        guard backup.format == formatName else {
            throw ImportError.notABackup(backup.format)
        }
        guard backup.version <= currentVersion else {
            throw ImportError.tooRecent(found: backup.version, supported: currentVersion)
        }
        return backup
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Ce que la restauration a effectivement repris, à afficher à l'utilisateur.
    public struct Summary: Sendable, Equatable {
        public let cameras: Int
        public let lenses: Int
        public let films: Int
        public let rolls: Int
        public let frames: Int
        public let photos: Int
    }

    public var summary: Summary {
        Summary(
            cameras: data.cameras.count,
            lenses: data.lenses.count,
            films: data.filmStocks.count,
            rolls: data.rolls.count,
            frames: data.frames.count,
            photos: data.attachments.count)
    }

    // MARK: - Lectures dérivées

    /// Vues d'un rouleau, dans l'ordre des numéros.
    public func frames(ofRoll rollId: String) -> [Model.Frame] {
        data.frames
            .filter { $0.rollId == rollId }
            .sorted { $0.number < $1.number }
    }

    public func film(id: String) -> Model.FilmStock? {
        data.filmStocks.first { $0.id == id }
    }

    public func camera(id: String) -> Model.Camera? {
        data.cameras.first { $0.id == id }
    }

    public func lens(id: String) -> Model.Lens? {
        data.lenses.first { $0.id == id }
    }

    /// Rouleaux encore dans un boîtier, du plus récemment chargé au plus ancien.
    public var openRolls: [Model.Roll] {
        data.rolls
            .filter { $0.status.isOpen }
            .sorted { $0.loadedAt > $1.loadedAt }
    }

    /// Signale les références rompues : un rouleau dont la pellicule ou le
    /// boîtier manque, une vue orpheline. Une sauvegarde saine n'en a aucune,
    /// mais une fusion malheureuse peut en produire.
    public func danglingReferences() -> [String] {
        var problems: [String] = []
        let filmIds = Set(data.filmStocks.map(\.id))
        let cameraIds = Set(data.cameras.map(\.id))
        let rollIds = Set(data.rolls.map(\.id))

        for roll in data.rolls {
            if !filmIds.contains(roll.filmStockId) {
                problems.append("Rouleau « \(roll.label ?? roll.id) » : pellicule introuvable")
            }
            if !cameraIds.contains(roll.cameraId) {
                problems.append("Rouleau « \(roll.label ?? roll.id) » : boîtier introuvable")
            }
        }
        for frame in data.frames where !rollIds.contains(frame.rollId) {
            problems.append("Vue n° \(frame.number) : rouleau introuvable")
        }
        return problems
    }
}
