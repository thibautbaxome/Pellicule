import XCTest
@testable import PelliculeCore

/// Les valeurs attendues ne sont pas inventées : ce sont celles que la version
/// web produit déjà, vérifiées à l'écran. Ce fichier prouve donc que le portage
/// Swift reste fidèle au comportement validé par l'usage.
final class PelliculeCoreTests: XCTestCase {

    // MARK: - Échelles

    func testShutterParsing() {
        XCTAssertEqual(Exposure.seconds(from: "1/125")!, 0.008, accuracy: 1e-9)
        XCTAssertEqual(Exposure.seconds(from: "8s")!, 8, accuracy: 1e-9)
        XCTAssertNil(Exposure.seconds(from: "B"))
    }

    func testShutterFormatting() {
        XCTAssertEqual(Exposure.shutter(fromSeconds: 0.008), "1/125")
        XCTAssertEqual(Exposure.shutter(fromSeconds: 4), "4s")
    }

    // MARK: - Exposition

    /// Plein soleil (IL 15 à 100 ISO) sur un film 400 ISO donne IL 17.
    func testExposureValueAtIso() {
        XCTAssertEqual(Exposure.ev(ev100: 15, iso: 400), 17, accuracy: 1e-9)
    }

    /// Le cas « Paysage, plein soleil » de l'assistant : f/11 doit tomber
    /// sur le 1/1000 du Minolta X-300.
    func testLandscapeInFullSun() {
        let seconds = Exposure.shutterSeconds(ev100: 15, iso: 400, aperture: 11)
        let shutter = Exposure.nearestShutter(in: Exposure.fullShutters, to: seconds)
        XCTAssertEqual(shutter, "1/1000")
    }

    /// Le portrait à pleine ouverture en plein soleil sort de la plage du
    /// boîtier : c'est ce qui déclenche le conseil de correction.
    func testPortraitInFullSunIsOutOfRange() {
        let seconds = Exposure.shutterSeconds(ev100: 15, iso: 400, aperture: 2)
        XCTAssertLessThan(seconds, Exposure.seconds(from: "1/1000")!)
    }

    func testPushPull() {
        // Tri-X 400 exposée à 1600 : deux diaphragmes poussés.
        XCTAssertEqual(Exposure.pushPullStops(shotIso: 1600, boxIso: 400), 2, accuracy: 1e-9)
    }

    // MARK: - Réciprocité

    /// Tri-X, exposant 1,28 : une pose de 8 s en demande réellement 14,32.
    func testTriXReciprocity() {
        let triX = ReciprocityModel(exponent: 1.28, thresholdSeconds: 1)
        XCTAssertEqual(triX.corrected(measured: 8), pow(8, 1.28), accuracy: 1e-9)
        XCTAssertEqual(triX.corrected(measured: 8), 14.32, accuracy: 0.01)
    }

    /// L'Acros II ne corrige rien avant deux minutes de pose.
    func testAcrosNeedsNoCorrection() {
        let acros = ReciprocityModel(exponent: 1.0, thresholdSeconds: 120)
        XCTAssertEqual(acros.corrected(measured: 60), 60, accuracy: 1e-9)
    }

    // MARK: - Optique

    /// 50 mm à f/11 : hyperfocale à 7,63 m.
    func testHyperfocal() {
        XCTAssertEqual(Optics.hyperfocal(focal: 50, aperture: 11), 7.626, accuracy: 0.002)
    }

    /// Le cas affiché à l'écran : 50 mm, f/11, sujet à 8 m,
    /// net à partir de 3,9 m et jusqu'à l'infini.
    func testLandscapeDepthOfFieldMatchesTheApp() throws {
        let dof = try XCTUnwrap(Optics.depthOfField(focal: 50, aperture: 11, distance: 8))
        XCTAssertEqual(dof.near, 3.904, accuracy: 0.01)
        XCTAssertTrue(dof.isFarInfinite)
    }

    /// Portrait à f/2, sujet à 2 m : moins de 20 cm de zone nette.
    func testPortraitDepthOfFieldIsThin() throws {
        let dof = try XCTUnwrap(Optics.depthOfField(focal: 50, aperture: 2, distance: 2))
        XCTAssertLessThan(dof.far - dof.near, 0.20)
    }
}
