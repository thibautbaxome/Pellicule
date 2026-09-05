import Foundation
import ImageIO
import PelliculeCore
import UIKit

/// Les photos de repérage.
///
/// Une photo prise à l'iPhone au moment de déclencher, pour se rappeler le
/// cadrage quand le rouleau revient du laboratoire trois semaines plus tard —
/// et, ce jour-là, reconnaître ses images pour les rapprocher des scans.
///
/// Elles ne vont pas dans le fichier du carnet : une image pèse mille fois une
/// vue, et le carnet doit rester un fichier qu'on relit d'un coup. Ce sont des
/// fichiers à côté, désignés par leur identifiant, et la sauvegarde les
/// emporte seulement quand on le lui demande.
enum PhotoStore {

    static let directory: URL = {
        let url = URL.documentsDirectory.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Le plus grand côté conservé. Un repérage n'a pas besoin de plus : au
    /// delà, on stocke des mégaoctets pour se souvenir d'un cadrage.
    static let longestSide: CGFloat = 1_600

    static func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("jpg")
    }

    /// Enregistre une image réduite et rend son identifiant.
    static func save(_ image: UIImage) -> String? {
        let id = UUID().uuidString
        guard let data = shrink(image).jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    static func save(data: Data, id: String) throws {
        try data.write(to: url(for: id), options: .atomic)
    }

    static func load(_ id: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    static func data(_ id: String) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    private static let thumbnails = NSCache<NSString, UIImage>()

    /// Une vignette pour les listes. Décoder la photo entière pour l'afficher
    /// en quarante points coûterait huit mégaoctets par ligne et ferait
    /// bégayer le défilement ; ImageIO sait produire directement une image
    /// réduite, et on la garde en cache tant que la mémoire le permet.
    static func thumbnail(_ id: String, side: CGFloat) -> UIImage? {
        let key = "\(id)@\(Int(side))" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }

        // Trois pixels par point : net sur tous les écrans, sans interroger
        // l'écran depuis un endroit qui n'a pas à le connaître.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(side * 3),
        ]
        guard let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil),
              let reduced = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let image = UIImage(cgImage: reduced)
        thumbnails.setObject(image, forKey: key)
        return image
    }

    static func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// Toutes les photos que des vues désignent encore, prêtes pour une
    /// sauvegarde complète. Les orphelines — d'une vue supprimée — ne partent pas.
    static func attachments(for frames: [Model.Frame]) -> [Backup.Attachment] {
        frames.compactMap { frame in
            guard let id = frame.refPhotoId, let data = data(id) else { return nil }
            let image = UIImage(data: data)
            return Backup.Attachment(
                id: id,
                mime: "image/jpeg",
                width: image.map { Double($0.size.width * $0.scale) },
                height: image.map { Double($0.size.height * $0.scale) },
                createdAt: frame.createdAt,
                base64: data.base64EncodedString())
        }
    }

    /// Reprend les photos d'une sauvegarde. Une image illisible est ignorée,
    /// pas fatale : mieux vaut un carnet sans une photo qu'aucun carnet.
    static func restore(_ attachments: [Backup.Attachment]) -> Int {
        var restored = 0
        for attachment in attachments {
            guard let data = attachment.imageData else { continue }
            if (try? save(data: data, id: attachment.id)) != nil { restored += 1 }
        }
        return restored
    }

    private static func shrink(_ image: UIImage) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > longestSide else { return image }
        let scale = longestSide / largest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
