import XCTest
@testable import PelliculeCore

final class StatisticsTests: XCTestCase {

    private let carnet = Carnet(fileURL: nil)

    private func film(_ id: String) -> Catalog.Film { Catalog.films.first { $0.id == id }! }

    private func makeRoll(
        film id: String, frames: Int, costs: Model.Roll.Costs? = nil,
        status: Model.RollStatus = .shooting, shutter: String = "1/125", aperture: Double = 8
    ) -> Model.Roll {
        let camera = carnet.cameras.first ?? {
            let c = carnet.makeCamera(named: "Boîtier"); carnet.save(c); return c
        }()
        var roll = carnet.loadRoll(film: film(id), camera: camera)
        roll.costs = costs
        roll.status = status
        carnet.save(roll)
        for _ in 0..<frames {
            var frame = carnet.makeFrame(inRoll: roll.id)
            frame.shutter = shutter
            frame.aperture = aperture
            carnet.save(frame)
        }
        return carnet.roll(id: roll.id)!
    }

    private var summary: Statistics.Summary {
        Statistics.summary(rolls: carnet.rolls, frames: carnet.frames) {
            carnet.film(id: $0)?.displayName
        }
    }

    func testEmptyCarnetHasNothingToSay() {
        let s = summary
        XCTAssertEqual(s.rolls, 0)
        XCTAssertEqual(s.frames, 0)
        XCTAssertNil(s.costPerFrame)
        XCTAssertNil(s.mostUsedShutter)
        XCTAssertTrue(s.films.isEmpty)
    }

    /// Le coût par vue ne compte que les rouleaux chiffrés : diviser par toutes
    /// les vues donnerait un chiffre faussement bas.
    func testCostPerFrameIgnoresUncostedRolls() {
        _ = makeRoll(film: "kodak-tri-x-400", frames: 10,
                     costs: Model.Roll.Costs(film: 8, development: 12, scan: nil, prints: nil),
                     status: .developed)
        _ = makeRoll(film: "kodak-tri-x-400", frames: 10)

        let s = summary
        XCTAssertEqual(s.totalCost, 20, accuracy: 1e-9)
        XCTAssertEqual(s.costPerFrame ?? 0, 2, accuracy: 1e-9, "20 € sur les 10 vues chiffrées")
        XCTAssertEqual(s.frames, 20)
    }

    /// Un rouleau encore dans le boîtier compte pour ses poses annoncées : le
    /// coût par vue ne doit pas fondre à chaque déclenchement.
    func testOpenRollCountsItsAnnouncedExposures() {
        _ = makeRoll(film: "kodak-tri-x-400", frames: 3,
                     costs: Model.Roll.Costs(film: 9, development: nil, scan: nil, prints: nil),
                     status: .shooting)
        let s = summary
        XCTAssertEqual(s.costPerFrame ?? 0, 9.0 / 36.0, accuracy: 1e-9)
    }

    func testFilmsAreRankedByFramesShot() {
        _ = makeRoll(film: "kodak-tri-x-400", frames: 3)
        _ = makeRoll(film: "ilford-hp5-plus-400", frames: 8)
        _ = makeRoll(film: "kodak-tri-x-400", frames: 4)

        let films = summary.films
        XCTAssertEqual(films.first?.name, "Ilford HP5 Plus 400")
        XCTAssertEqual(films.first?.frames, 8)
        XCTAssertEqual(films.last?.rolls, 2)
        XCTAssertEqual(films.last?.frames, 7)
    }

    func testRollsAreCountedByStatus() {
        _ = makeRoll(film: "kodak-tri-x-400", frames: 1, status: .shooting)
        _ = makeRoll(film: "kodak-tri-x-400", frames: 1, status: .atLab)
        _ = makeRoll(film: "kodak-tri-x-400", frames: 1, status: .atLab)

        let s = summary
        XCTAssertEqual(s.openRolls, 1)
        XCTAssertEqual(s.rollsByStatus[.atLab], 2)
        XCTAssertNil(s.rollsByStatus[.archived])
    }

    func testMostUsedSettingsAreTheMode() {
        _ = makeRoll(film: "kodak-tri-x-400", frames: 5, shutter: "1/250", aperture: 5.6)
        _ = makeRoll(film: "kodak-tri-x-400", frames: 2, shutter: "1/60", aperture: 11)

        let s = summary
        XCTAssertEqual(s.mostUsedShutter, "1/250")
        XCTAssertEqual(s.mostUsedAperture, 5.6)
    }

    /// À égalité, la première valeur rencontrée : un résultat stable vaut mieux
    /// qu'un résultat qui change à chaque affichage.
    func testModeIsStableOnTies() {
        XCTAssertEqual(Statistics.mode(["a", "b", "a", "b"]), "a")
        XCTAssertEqual(Statistics.mode([3, 1, 1, 3]), 3)
        XCTAssertNil(Statistics.mode([String]()))
    }
}
