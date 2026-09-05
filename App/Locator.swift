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
        /// Refusée pour l'application, ou service de localisation coupé pour
        /// tout le téléphone : CoreLocation ne distingue pas les deux.
        case permissionDenied
        /// Interdite par une restriction — Temps d'écran, gestion de
        /// l'appareil — sur laquelle l'utilisateur n'a pas la main.
        case restricted
        /// Le relevé a échoué ; la raison est déjà rédigée pour l'écran.
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
            status = .restricted
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
            status = .restricted
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
        // La description système est en anglais et parle en codes d'erreur ;
        // le photographe a besoin de savoir quoi faire, pas de quel domaine
        // vient l'échec.
        switch (error as? CLError)?.code {
        case .denied:
            // Un refus arrive aussi par ici sur certaines versions.
            status = .permissionDenied
        case .locationUnknown:
            status = .failed("le téléphone n’a pas réussi à se situer. Réessayez à découvert.")
        case .network:
            status = .failed("aucun réseau pour établir la position.")
        default:
            status = .failed("le téléphone n’a pas pu se situer.")
        }
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
