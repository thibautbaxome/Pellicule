import XCTest
@testable import PelliculeCore

/// La date d'expiration de la signature, lue dans le profil embarqué.
final class SignatureTests: XCTestCase {

    /// Un profil ressemble à ceci : des octets binaires de l'enveloppe signée,
    /// un plist XML au milieu, d'autres octets binaires après.
    private func profileData(expiring date: String) -> Data {
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Name</key><string>Pellicule</string>
                <key>TeamName</key><string>Thibaut</string>
                <key>ExpirationDate</key><date>\(date)</date>
            </dict>
            </plist>
            """
        var data = Data([0x30, 0x82, 0x0A, 0x00, 0x06, 0x09, 0xFF, 0x00])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0x31, 0x82, 0x01, 0xFE, 0xA0]))
        return data
    }

    func testExpirationIsReadThroughTheBinaryEnvelope() throws {
        let profile = try XCTUnwrap(Signature.profile(from: profileData(expiring: "2026-09-13T10:00:00Z")))
        XCTAssertEqual(profile.name, "Pellicule")
        XCTAssertEqual(profile.team, "Thibaut")

        let now = ISO8601DateFormatter().date(from: "2026-09-07T09:00:00Z")!
        XCTAssertEqual(profile.daysLeft(at: now), 6)
        XCTAssertFalse(profile.isExpired(at: now))
    }

    func testTheLastDayCountsAsZeroAndPastIsExpired() throws {
        let profile = try XCTUnwrap(Signature.profile(from: profileData(expiring: "2026-09-13T10:00:00Z")))
        let lastDay = ISO8601DateFormatter().date(from: "2026-09-13T08:00:00Z")!
        XCTAssertEqual(profile.daysLeft(at: lastDay), 0)
        XCTAssertFalse(profile.isExpired(at: lastDay))

        let after = ISO8601DateFormatter().date(from: "2026-09-13T11:00:00Z")!
        XCTAssertTrue(profile.isExpired(at: after))
        XCTAssertEqual(profile.daysLeft(at: after), 0)
    }

    /// Sans profil — simulateur, App Store — il n'y a rien à afficher, et
    /// surtout rien à inventer.
    func testGarbageYieldsNothing() {
        XCTAssertNil(Signature.profile(from: Data([0x00, 0x01, 0x02])))
        XCTAssertNil(Signature.profile(from: Data("<?xml version=\"1.0\"?><plist><dict/></plist>".utf8)))
    }
}
