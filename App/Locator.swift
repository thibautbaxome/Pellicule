import CoreLocation
import Observation
import PelliculeCore

/// Relevé de la position au moment de la prise de vue.
///
/// C'est ce qui permet, des mois plus tard, de retrouver où une vue a été
/// faite — et surtout de l'inscrire dans les métadonnées du scan, qui se
/// comporte dès lors comme une photo numérique dans n'importe quelle
/// photothèque.
///
/// Un relevé unique, jamais un suivi : le carnet n'a besoin de savoir où l'on
/// est qu'à l'instant où l'on note une vue. Laisser la localisation tourner
/// viderait la batterie et collecterait un trajet dont personne n'a l'usage.
@Observable
final class Locator: NSObject, CLLocationManagerDelegate {

    enum Status: Equatable {
        case idle
        case locating
        case located
        case permissionDenied
        /// La localisation est coupée à l'échelle de l'appareil.
        case servicesOff
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var location: Model.GeoLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Une dizaine de mètres suffit à retrouver un lieu ; exiger mieux
        // ferait attendre le photographe pour rien.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func request() {
        guard status != .locating else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            status = .locating
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .locating
            manager.requestLocation()
        case .denied:
            status = .permissionDenied
        case .restricted:
            status = .servicesOff
        @unknown default:
            status = .permissionDenied
        }
    }

    func forget() {
        location = nil
        status = .idle
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if status == .locating { manager.requestLocation() }
        case .denied:
            status = .permissionDenied
        case .restricted:
            status = .servicesOff
        case .notDetermined:
            break
        @unknown default:
            status = .permissionDenied
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        location = Model.GeoLocation(
            lat: last.coordinate.latitude,
            lon: last.coordinate.longitude,
            // Une précision négative signale une valeur invalide.
            accuracy: last.horizontalAccuracy >= 0 ? last.horizontalAccuracy : nil,
            altitude: last.verticalAccuracy >= 0 ? last.altitude : nil,
            label: nil)
        status = .located
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Un refus arrive aussi par ici sur certaines versions.
        if let clError = error as? CLError, clError.code == .denied {
            status = .permissionDenied
            return
        }
        status = .failed(error.localizedDescription)
    }
}

extension Model.GeoLocation {
    /// Coordonnées lisibles, à la minute près comme sur une carte.
    var readable: String {
        let latitude = String(format: "%.4f", abs(lat))
        let longitude = String(format: "%.4f", abs(lon))
        return "\(latitude)° \(lat >= 0 ? "N" : "S")  \(longitude)° \(lon >= 0 ? "E" : "O")"
    }
}
