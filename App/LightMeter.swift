import AVFoundation
import Observation
import PelliculeCore
import SwiftUI

/// Le posemètre : lecture des réglages que la caméra retient d'elle-même.
///
/// Cette classe ne calcule rien — tout le calcul est dans `Meter`, vérifié sur
/// des valeurs connues. Elle ne fait que tenir la session de capture ouverte et
/// relever, à intervalle régulier, ce que l'appareil a décidé.
///
/// Toute défaillance est un état affichable, jamais un plantage ni un silence :
/// un posemètre qui ne dit rien laisse croire qu'il mesure zéro.
@Observable
final class LightMeter {

    enum Status: Equatable {
        case idle
        /// L'appareil n'a pas de caméra utilisable — le simulateur, par exemple.
        case noCamera
        case permissionDenied
        case failed(String)
        case measuring
    }

    private(set) var status: Status = .idle
    private(set) var reading: Meter.Reading?

    /// Correction appliquée à la mesure, en diaphragmes.
    var calibrationStops: Double = 0

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.pellicule.posemetre")
    private var device: AVCaptureDevice?
    private var poll: Timer?

    // MARK: - Cycle de vie

    @MainActor
    func start() async {
        guard status != .measuring else { return }

        // L'appareil d'abord, l'autorisation ensuite. Réclamer l'accès à une
        // caméra pour annoncer aussitôt qu'il n'y en a pas est une demande
        // qu'on ne peut pas justifier — et c'est le simulateur qui l'a montré.
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        else {
            status = .noCamera
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                status = .permissionDenied
                return
            }
        case .denied, .restricted:
            status = .permissionDenied
            return
        @unknown default:
            status = .permissionDenied
            return
        }

        do {
            try configure(camera)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        device = camera
        status = .measuring
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
        // Un relevé toutes les deux dixièmes : assez pour suivre la main qui
        // balaie la scène, assez peu pour que le chiffre reste lisible.
        poll = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    @MainActor
    func stop() {
        poll?.invalidate()
        poll = nil
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        status = .idle
    }

    private func configure(_ camera: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // La qualité de l'image ne compte pas : on ne lit que les réglages.
        // Le format le plus léger laisse la mesure réactive.
        if session.canSetSessionPreset(.medium) { session.sessionPreset = .medium }

        for input in session.inputs { session.removeInput(input) }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw NSError(
                domain: "app.pellicule", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "La caméra est occupée par une autre application."])
        }
        session.addInput(input)

        try camera.lockForConfiguration()
        // Mesure continue : c'est l'exposition automatique elle-même qui fait
        // office de cellule.
        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }
        // Au centre, comme un posemètre à visée réflexe.
        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        camera.unlockForConfiguration()
    }

    // MARK: - Relevé

    @MainActor
    private func sample() {
        guard let device else { return }
        let duration = CMTimeGetSeconds(device.exposureDuration)
        let format = device.activeFormat

        reading = Meter.reading(
            aperture: Double(device.lensAperture),
            durationSeconds: duration,
            iso: Double(device.iso),
            limits: Meter.DeviceLimits(
                shortestDuration: CMTimeGetSeconds(format.minExposureDuration),
                longestDuration: CMTimeGetSeconds(format.maxExposureDuration),
                lowestISO: Double(format.minISO),
                highestISO: Double(format.maxISO)),
            calibrationStops: calibrationStops)
    }

    deinit {
        poll?.invalidate()
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }
}

/// Aperçu de ce que la caméra voit.
///
/// Nécessaire, et pas décoratif : sans image, on ne sait pas ce qu'on mesure —
/// et pointer le ciel plutôt que le sujet change la réponse de plusieurs
/// diaphragmes.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

extension LightMeter {
    /// La session, pour l'aperçu. Exposée en lecture seule.
    var previewSession: AVCaptureSession { session }
}
