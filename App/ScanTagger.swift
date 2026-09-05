import ImageIO
import PelliculeCore
import UniformTypeIdentifiers
import Foundation

/// Écriture des métadonnées dans les scans.
///
/// C'est ce que la version web ne pouvait pas faire : un navigateur sait
/// produire un fichier de commandes, pas modifier une image. Ici l'application
/// écrit les balises elle-même, et le scan se comporte dès lors comme une photo
/// numérique dans n'importe quelle photothèque — daté, situé, avec son boîtier
/// et ses réglages.
///
/// Les originaux ne sont jamais touchés. L'application écrit des copies dans un
/// dossier temporaire, que le photographe enregistre où il veut : un carnet
/// n'a pas à prendre le risque d'abîmer des négatifs numérisés qu'on ne peut
/// pas refaire.
enum ScanTagger {

    enum Failure: LocalizedError {
        case unreadable(String)
        case unsupported(String)
        case notWritten(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name): "« \(name) » n’a pas pu être lu."
            case .unsupported(let name): "Le format de « \(name) » ne se laisse pas annoter."
            case .notWritten(let name): "« \(name) » n’a pas pu être écrit."
            }
        }
    }

    struct Outcome {
        var written: [URL] = []
        var failures: [String] = []
    }

    /// Annote une copie de chaque scan et rend les fichiers produits.
    static func tag(
        pairings: [ExifExport.Pairing],
        sources: [String: URL],
        context: ExifExport.Context,
        pattern: String,
        into directory: URL
    ) -> Outcome {
        var outcome = Outcome()

        for pairing in pairings {
            guard let frame = pairing.frame, let source = sources[pairing.fileName] else { continue }
            let row = ExifExport.metadata(for: frame, in: context, pattern: pattern)
            // Le nom voulu par le motif, mais l'extension du fichier d'origine :
            // renommer un TIFF en .jpg le rendrait illisible.
            let name = (row["SourceFile"] as NSString?)?.deletingPathExtension
                ?? pairing.fileName
            let destination = directory
                .appendingPathComponent(name)
                .appendingPathExtension(source.pathExtension)

            do {
                try write(row: row, from: source, to: destination)
                outcome.written.append(destination)
            } catch {
                outcome.failures.append(error.localizedDescription)
            }
        }
        return outcome
    }

    private static func write(row: [String: String], from source: URL, to destination: URL) throws {
        let name = source.lastPathComponent
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        guard let reader = CGImageSourceCreateWithURL(source as CFURL, nil),
              let type = CGImageSourceGetType(reader),
              CGImageSourceGetCount(reader) > 0
        else { throw Failure.unreadable(name) }

        guard let writer = CGImageDestinationCreateWithURL(
            destination as CFURL, type, 1, nil)
        else { throw Failure.unsupported(name) }

        // On repart des propriétés existantes : le scanner y a laissé la
        // résolution et le profil colorimétrique, qu'il serait absurde de perdre
        // en ajoutant une date de prise de vue.
        var properties = (CGImageSourceCopyPropertiesAtIndex(reader, 0, nil)
            as? [CFString: Any]) ?? [:]

        var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        var iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]

        if let date = row["DateTimeOriginal"], !date.isEmpty {
            exif[kCGImagePropertyExifDateTimeOriginal] = date
            exif[kCGImagePropertyExifDateTimeDigitized] = date
            tiff[kCGImagePropertyTIFFDateTime] = date
        }
        if let aperture = row["FNumber"].flatMap(Double.init) {
            exif[kCGImagePropertyExifFNumber] = aperture
        }
        // La vitesse est notée « 1/125 » dans le carnet ; EXIF la veut en
        // secondes.
        if let shutter = row["ExposureTime"], let seconds = Exposure.seconds(from: shutter) {
            exif[kCGImagePropertyExifExposureTime] = seconds
        }
        if let iso = row["ISO"].flatMap(Int.init) {
            exif[kCGImagePropertyExifISOSpeedRatings] = [iso]
        }
        if let focal = row["FocalLength"].flatMap(Double.init) {
            exif[kCGImagePropertyExifFocalLength] = focal
        }
        if let lens = row["LensModel"], !lens.isEmpty {
            exif[kCGImagePropertyExifLensModel] = lens
        }
        if let comment = row["UserComment"], !comment.isEmpty {
            exif[kCGImagePropertyExifUserComment] = comment
        }
        if let compensation = row["ExposureCompensation"].flatMap(Double.init) {
            exif[kCGImagePropertyExifExposureBiasValue] = compensation
        }
        if let distance = row["SubjectDistance"].flatMap(Double.init) {
            exif[kCGImagePropertyExifSubjectDistance] = distance
        }
        // Le bit 0 de Flash dit s'il a servi ; c'est tout ce que le carnet sait.
        exif[kCGImagePropertyExifFlash] = (row["Flash"] == "Fired") ? 1 : 0

        if let make = row["Make"], !make.isEmpty { tiff[kCGImagePropertyTIFFMake] = make }
        if let model = row["Model"], !model.isEmpty { tiff[kCGImagePropertyTIFFModel] = model }
        if let description = row["ImageDescription"], !description.isEmpty {
            tiff[kCGImagePropertyTIFFImageDescription] = description
        }
        if let keywords = row["Keywords"], !keywords.isEmpty {
            iptc[kCGImagePropertyIPTCKeywords] = keywords
                .components(separatedBy: ", ").filter { !$0.isEmpty }
        }

        properties[kCGImagePropertyExifDictionary] = exif
        properties[kCGImagePropertyTIFFDictionary] = tiff
        properties[kCGImagePropertyIPTCDictionary] = iptc

        if let latitude = row["GPSLatitude"].flatMap(Double.init),
           let longitude = row["GPSLongitude"].flatMap(Double.init) {
            var gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
            gps[kCGImagePropertyGPSLatitude] = latitude
            gps[kCGImagePropertyGPSLatitudeRef] = row["GPSLatitudeRef"] ?? "N"
            gps[kCGImagePropertyGPSLongitude] = longitude
            gps[kCGImagePropertyGPSLongitudeRef] = row["GPSLongitudeRef"] ?? "E"
            if let altitude = row["GPSAltitude"].flatMap(Double.init) {
                gps[kCGImagePropertyGPSAltitude] = abs(altitude)
                gps[kCGImagePropertyGPSAltitudeRef] = altitude < 0 ? 1 : 0
            }
            properties[kCGImagePropertyGPSDictionary] = gps
        }

        CGImageDestinationAddImageFromSource(writer, reader, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(writer) else {
            throw Failure.notWritten(name)
        }
    }
}
