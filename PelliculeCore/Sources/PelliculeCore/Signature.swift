import Foundation

/// La signature de l'application, lue dans le profil qu'elle embarque.
///
/// Installée hors de l'App Store avec un compte Apple gratuit, l'application
/// n'est valable que sept jours : passé ce délai, elle refuse de s'ouvrir tant
/// qu'on ne l'a pas réinstallée depuis l'ordinateur. Aucun réglage du
/// téléphone ne dit quand cela arrivera. Le profil de signature, lui, le sait
/// — il est dans le paquet de l'application, et il suffit de le lire.
public enum Signature {

    public struct Profile: Sendable, Equatable {
        public let name: String?
        public let team: String?
        public let expiresAt: Date

        public init(name: String?, team: String?, expiresAt: Date) {
            self.name = name
            self.team = team
            self.expiresAt = expiresAt
        }

        public func isExpired(at now: Date) -> Bool { expiresAt <= now }

        /// Jours entiers restants ; zéro le dernier jour.
        public func daysLeft(at now: Date) -> Int {
            max(0, Int(expiresAt.timeIntervalSince(now) / 86_400))
        }
    }

    /// Le profil est une enveloppe signée (CMS, en DER) autour d'un plist XML.
    /// On ne vérifie pas la signature — c'est le travail du système — on lit
    /// la date. Le plist se repère à ses bornes, sans décoder l'enveloppe.
    public static func profile(from data: Data) -> Profile? {
        let bytes = [UInt8](data)
        guard let start = bytes.firstRange(of: Array("<?xml".utf8)),
              let end = bytes.firstRange(of: Array("</plist>".utf8), from: start.upperBound)
        else { return nil }
        let plist = Data(bytes[start.lowerBound..<end.upperBound])

        guard let object = try? PropertyListSerialization.propertyList(from: plist, format: nil),
              let dictionary = object as? [String: Any],
              let expiresAt = dictionary["ExpirationDate"] as? Date
        else { return nil }

        return Profile(
            name: dictionary["Name"] as? String,
            team: dictionary["TeamName"] as? String,
            expiresAt: expiresAt)
    }
}

private extension Array where Element == UInt8 {
    /// Première occurrence d'un motif, à partir d'un rang donné.
    func firstRange(of pattern: [UInt8], from offset: Int = 0) -> Range<Int>? {
        guard !pattern.isEmpty, count >= pattern.count else { return nil }
        var index = offset
        while index + pattern.count <= count {
            if self[index] == pattern[0],
               self[index..<index + pattern.count].elementsEqual(pattern) {
                return index..<index + pattern.count
            }
            index += 1
        }
        return nil
    }
}
