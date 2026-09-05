import Foundation

/// Métadonnées à injecter dans les scans.
///
/// Un scan de laboratoire arrive nu : aucune date de prise de vue, aucun
/// boîtier, aucun réglage. Ce module reconstitue ces informations à partir du
/// carnet. En natif, elles seront écrites directement dans les fichiers ; le
/// CSV et le script exiftool restent produits pour les scans que l'application
/// ne sait pas modifier elle-même, comme les TIFF.
public enum ExifExport {

    /// Contexte d'un rouleau : tout ce qu'il faut pour décrire ses vues.
    public struct Context: Sendable {
        public let roll: Model.Roll
        public let frames: [Model.Frame]
        public let film: Model.FilmStock?
        public let camera: Model.Camera?
        public let lenses: [String: Model.Lens]

        public init(
            roll: Model.Roll,
            frames: [Model.Frame],
            film: Model.FilmStock?,
            camera: Model.Camera?,
            lenses: [String: Model.Lens]
        ) {
            self.roll = roll
            self.frames = frames
            self.film = film
            self.camera = camera
            self.lenses = lenses
        }
    }

    /// Motif de nom de fichier. Jetons reconnus : `{n}`, `{nn}`, `{nnn}` pour
    /// le numéro de vue, `{roll}` pour la référence du rouleau.
    public static let defaultFilenamePattern = "{roll}-{nn}.jpg"

    public static func filename(
        pattern: String,
        roll: Model.Roll,
        frame: Model.Frame
    ) -> String {
        let token = slug(roll.archiveRef ?? roll.label ?? "rouleau")
        return pattern
            .replacingOccurrences(of: "{roll}", with: token)
            .replacingOccurrences(of: "{nnn}", with: String(format: "%03d", frame.number))
            .replacingOccurrences(of: "{nn}", with: String(format: "%02d", frame.number))
            .replacingOccurrences(of: "{n}", with: String(frame.number))
    }

    /// Colonnes produites, dans l'ordre. `SourceFile` doit rester en tête :
    /// c'est la clé qu'exiftool emploie pour retrouver le fichier.
    public static let columns = [
        "SourceFile", "Make", "Model", "LensModel", "FocalLength", "FNumber",
        "ExposureTime", "ISO", "DateTimeOriginal", "CreateDate",
        "ExposureCompensation", "Flash", "SubjectDistance",
        "ImageDescription", "Description", "Keywords", "UserComment",
        "GPSLatitude", "GPSLatitudeRef", "GPSLongitude", "GPSLongitudeRef", "GPSAltitude",
    ]

    public static func metadata(
        for frame: Model.Frame,
        in context: Context,
        pattern: String = defaultFilenamePattern
    ) -> [String: String] {
        let lens = frame.lensId.flatMap { context.lenses[$0] }
        // La focale d'un zoom n'est connue que si elle a été saisie ; celle
        // d'une focale fixe se déduit de l'objectif.
        let focal = frame.focal ?? (lens?.isPrime == true ? lens?.focalMin : nil)

        var keywords = frame.tags
        if let film = context.film { keywords.append(film.displayName) }
        if let camera = context.camera { keywords.append(camera.name) }
        if context.film?.type == .blackAndWhite { keywords.append("noir et blanc") }
        keywords.append("argentique")

        var row: [String: String] = [
            "SourceFile": filename(pattern: pattern, roll: context.roll, frame: frame),
            // Le nom du boîtier tient lieu de modèle quand la marque n'est pas
            // renseignée : c'est ce qui s'affiche dans les photothèques.
            "Make": context.camera?.make
                ?? context.camera?.name.split(separator: " ").first.map(String.init) ?? "",
            "Model": context.camera?.model ?? context.camera?.name ?? "",
            "LensModel": lens?.name ?? "",
            "FocalLength": focal.map { String(Int($0)) } ?? "",
            "FNumber": frame.aperture.map { trim($0) } ?? "",
            // exiftool accepte aussi bien « 1/125 » que la valeur décimale.
            "ExposureTime": frame.shutterSeconds != nil ? (frame.shutter ?? "") : "",
            "ISO": String(Int(context.roll.shotIso)),
            "DateTimeOriginal": exifDate(frame.shotAt),
            "CreateDate": exifDate(frame.shotAt),
            "ExposureCompensation": frame.exposureComp.map { trim($0) } ?? "",
            "Flash": (frame.flash ?? false) ? "Fired" : "No Flash",
            "SubjectDistance": frame.focusDistance.map { trim($0) } ?? "",
            "ImageDescription": frame.subject ?? "",
            "Description": frame.subject ?? "",
            "Keywords": keywords.joined(separator: ", "),
            "UserComment": userComment(for: frame, in: context),
        ]

        if let location = frame.location {
            row["GPSLatitude"] = trim(abs(location.lat))
            row["GPSLatitudeRef"] = location.lat >= 0 ? "N" : "S"
            row["GPSLongitude"] = trim(abs(location.lon))
            row["GPSLongitudeRef"] = location.lon >= 0 ? "E" : "W"
            row["GPSAltitude"] = location.altitude.map { String(Int($0.rounded())) } ?? ""
        } else {
            for key in ["GPSLatitude", "GPSLatitudeRef", "GPSLongitude",
                        "GPSLongitudeRef", "GPSAltitude"] {
                row[key] = ""
            }
        }
        return row
    }

    public static func rows(
        for context: Context,
        pattern: String = defaultFilenamePattern
    ) -> [[String: String]] {
        context.frames.map { metadata(for: $0, in: context, pattern: pattern) }
    }

    // MARK: - Rendus

    public static func csv(_ rows: [[String: String]]) -> String {
        let header = columns.joined(separator: ",")
        let lines = rows.map { row in
            columns.map { escapeCSV(row[$0] ?? "") }.joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n")
    }

    /// Commentaire lisible reprenant ce qu'aucune balise standard ne sait
    /// porter : l'émulsion, la sensibilité employée et le développement.
    private static func userComment(for frame: Model.Frame, in context: Context) -> String {
        var parts: [String] = []

        if let film = context.film {
            parts.append("Film: \(film.displayName) (\(Int(film.iso)) ISO)")
            if context.roll.shotIso != film.iso {
                parts.append("Exposée à \(Int(context.roll.shotIso)) ISO")
            }
        }
        if let reference = context.roll.archiveRef { parts.append("Rouleau: \(reference)") }
        parts.append("Vue: \(frame.number)")

        if let development = context.roll.development, development.developedByOwner,
           let developer = development.developer {
            var line = "Dév: \(developer)"
            if let dilution = development.dilution { line += " \(dilution)" }
            if let time = development.timeSec {
                line += String(format: " %d:%02d", Int(time) / 60, Int(time) % 60)
            }
            if let temperature = development.tempC { line += " à \(trim(temperature))°C" }
            parts.append(line)
        } else if let lab = context.roll.lab {
            parts.append("Labo: \(lab)")
        }

        if let filter = frame.filter { parts.append("Filtre: \(filter.name)") }
        if let metering = frame.meteringNote { parts.append("Mesure: \(metering)") }
        if let notes = frame.notes { parts.append(notes) }

        return parts.joined(separator: " · ")
    }

    // MARK: - Utilitaires

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(where: { "\",\n\r".contains($0) }) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Date au format attendu par EXIF : « 2026:04:18 17:32:04 ».
    static func exifDate(_ iso8601: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso8601)
            ?? {
                let fallback = ISO8601DateFormatter()
                fallback.formatOptions = [.withInternetDateTime]
                return fallback.date(from: iso8601)
            }()
        guard let date else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func slug(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive], locale: nil).lowercased()
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(cleaned)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return joined.isEmpty ? "rouleau" : String(joined.prefix(40))
    }
}

// MARK: - Rapprochement des scans

/// Associer des fichiers de scan aux vues d'un rouleau.
///
/// C'est le problème que personne ne voit venir. Le laboratoire numérote ses
/// fichiers dans son ordre à lui, en partant de la première image exploitable :
/// les deux ou trois vues gâchées à l'amorce n'existent pas pour lui, alors
/// qu'elles occupent bien les numéros 1 à 3 du carnet. Les deux numérotations
/// sont donc décalées d'un nombre que la machine ne peut pas deviner.
///
/// Aucune heuristique ne réglera cela — l'horodatage d'un scan est celui de la
/// numérisation, pas de la prise de vue. La seule réponse honnête est de
/// laisser le photographe régler le décalage et de lui montrer aussitôt à quoi
/// il aboutit, vue par vue.
public extension ExifExport {

    struct Pairing: Sendable, Equatable, Identifiable {
        public let fileName: String
        public let frame: Model.Frame?

        public var id: String { fileName }
        /// Un scan qu'aucune vue ne réclame : décalage trop grand, ou vue
        /// jamais notée.
        public var isOrphan: Bool { frame == nil }
    }

    /// Rapproche des fichiers, dans l'ordre où le laboratoire les a nommés, des
    /// vues du rouleau, décalées d'autant de rangs qu'on le demande.
    ///
    /// Un décalage de 2 signifie que le premier fichier du laboratoire
    /// correspond à la troisième vue du carnet.
    static func pair(
        files: [String],
        with frames: [Model.Frame],
        offset: Int
    ) -> [Pairing] {
        let ordered = frames.sorted { $0.number < $1.number }
        return files.enumerated().map { index, name in
            let position = index + offset
            let frame = ordered.indices.contains(position) ? ordered[position] : nil
            return Pairing(fileName: name, frame: frame)
        }
    }

    /// Décalages qu'il vaut la peine de proposer, et le nombre de vues que
    /// chacun laisse sans scan. Aucun n'est « le bon » : c'est le photographe
    /// qui reconnaît ses images.
    static func plausibleOffsets(fileCount: Int, frameCount: Int) -> [Int] {
        guard fileCount > 0, frameCount > 0 else { return [0] }
        // Au-delà de cinq vues perdues à l'amorce, ce n'est plus une amorce.
        let maximum = max(0, min(5, frameCount - 1))
        return Array(0...maximum)
    }

    /// Script pour `exiftool`, à lancer dans le dossier des scans.
    ///
    /// Il existe pour les fichiers que l'application ne sait pas modifier
    /// elle-même — les TIFF, les DNG de scanner — et pour qui préfère voir ce
    /// qui sera écrit avant que ça le soit.
    static func script(rows: [[String: String]]) -> String {
        var lines = [
            "#!/bin/sh",
            "# Métadonnées engendrées par Pellicule.",
            "#",
            "# À lancer dans le dossier contenant les scans. exiftool conserve",
            "# l'original sous le suffixe _original ; supprimez-le une fois le",
            "# résultat vérifié.",
            "set -e",
            "",
        ]

        for row in rows {
            guard let file = row["SourceFile"], !file.isEmpty else { continue }
            var arguments: [String] = []
            for column in columns where column != "SourceFile" {
                guard let value = row[column], !value.isEmpty else { continue }
                arguments.append("-\(column)=\(shellQuoted(value))")
            }
            guard !arguments.isEmpty else { continue }
            lines.append("exiftool \(arguments.joined(separator: " ")) \(shellQuoted(file))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Guillemets simples pour le shell : tout y est littéral, sauf le
    /// guillemet lui-même, qu'il faut sortir de la chaîne.
    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
