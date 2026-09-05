import PelliculeCore
import SwiftUI

/// Mesurer la lumière avec la caméra du téléphone.
///
/// L'écran affiche autant la mesure que ce qu'elle vaut : d'où elle vient, si
/// l'appareil a touché ses limites, et de combien elle s'écarte de ce que le
/// photographe avait estimé à l'œil. Ce dernier chiffre est le plus utile des
/// trois — c'est lui qui apprend à se passer de l'application.
struct MeterSheet: View {
    let iso: Double
    let aperture: Double
    let availableShutters: [String]
    /// Ce que le photographe avait estimé avant de mesurer.
    let estimated: Light.Condition
    let onUse: (Double) -> Void
    /// La correction se règle une fois et doit survivre à la fermeture : sans
    /// cela, le réglage serait à refaire à chaque mesure.
    let onCalibrate: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var meter = LightMeter()

    init(
        iso: Double,
        aperture: Double,
        availableShutters: [String],
        estimated: Light.Condition,
        calibrationStops: Double,
        onUse: @escaping (Double) -> Void,
        onCalibrate: @escaping (Double) -> Void
    ) {
        self.iso = iso
        self.aperture = aperture
        self.availableShutters = availableShutters
        self.estimated = estimated
        self.onUse = onUse
        self.onCalibrate = onCalibrate
        _meter = State(initialValue: {
            let meter = LightMeter()
            meter.calibrationStops = calibrationStops
            return meter
        }())
    }

    var body: some View {
        NavigationStack {
            Group {
                switch meter.status {
                case .measuring: measuring
                case .noCamera: unavailable(
                    "Pas de caméra",
                    "Cet appareil n’a pas de caméra utilisable. C’est le cas d’un simulateur.")
                case .permissionDenied: unavailable(
                    "Accès refusé",
                    "Autorisez l’accès à la caméra dans Réglages → Pellicule pour mesurer la lumière.")
                case .failed(let reason): unavailable("Mesure impossible", reason)
                case .idle: ProgressView().tint(palette.accent)
                }
            }
            .carnetBackground(palette)
            .navigationTitle("Mesurer la lumière")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { await meter.start() }
            .onDisappear { meter.stop() }
        }
    }

    // MARK: - En mesure

    @ViewBuilder
    private var measuring: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CameraPreview(session: meter.previewSession)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        // La cible : la mesure se fait au centre du cadre.
                        Rectangle()
                            .strokeBorder(palette.accent, lineWidth: 1.5)
                            .frame(width: 54, height: 54))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.line, lineWidth: 1))

                Text("Visez ce que vous voulez exposer correctement. Le cadre au centre est ce qui compte : le ciel, lui, fausserait la mesure de plusieurs diaphragmes.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                if let reading = meter.reading {
                    verdict(reading)
                    if reading.isAtLimit { limitWarning }
                    comparison(reading)
                    calibration
                } else {
                    Text("Mesure en cours…")
                        .font(Typo.body)
                        .foregroundStyle(palette.textDim)
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if let reading = meter.reading, !reading.isAtLimit {
                Button("Utiliser cette mesure") {
                    onUse(reading.ev100)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .padding(16)
                .background(palette.bg)
            }
        }
    }

    private func verdict(_ reading: Meter.Reading) -> some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel("Lumière mesurée", colour: palette.accent)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    ValueText(text: shutterHere(reading) ?? "—", size: 34, weight: .bold)
                    Text("·")
                        .font(Typo.hero)
                        .foregroundStyle(palette.line)
                    ValueText(text: "f/\(trimmed(aperture))", size: 34, weight: .bold)
                    Spacer()
                }
                HStack(spacing: 10) {
                    ValueText(
                        text: "IL \(oneDecimal(reading.ev100))", size: 13, colour: palette.textDim)
                    if let named = Meter.nearestCondition(toEV100: reading.ev100) {
                        MicroLabel(named.label)
                    }
                    ValueText(text: "\(Int(iso)) ISO", size: 13, colour: palette.textDim)
                }
            }
        }
    }

    /// Quand la caméra est au bout de ce qu'elle sait faire, la mesure n'en est
    /// plus une : c'est une borne. L'employer ferait sous-exposer sans le
    /// savoir, ce qui est exactement ce qu'un posemètre doit éviter.
    private var limitWarning: some View {
        AdviceCard(advice: Assistant.Advice(
            level: .danger,
            title: "La caméra est à bout",
            detail: "L’appareil a poussé sa sensibilité et son temps de pose au maximum : "
                + "la scène est au moins aussi sombre que ce chiffre, peut-être davantage. "
                + "Cette mesure ne doit pas être employée telle quelle."))
    }

    /// L'écart entre l'estimation et la mesure : le seul chiffre de cet écran
    /// qui apprenne quelque chose.
    private func comparison(_ reading: Meter.Reading) -> some View {
        let drift = Meter.drift(estimated: estimated, measured: reading.ev100)
        let magnitude = abs(drift)

        return FieldRow(label: "Votre estimation") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    MicroLabel(estimated.label)
                    ValueText(
                        text: "IL \(oneDecimal(estimated.ev100))", size: 13,
                        colour: palette.textDim)
                }
                Text(comparisonText(drift: drift, magnitude: magnitude))
                    .font(Typo.caption)
                    .foregroundStyle(magnitude < 0.5 ? palette.ok : palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func comparisonText(drift: Double, magnitude: Double) -> String {
        guard magnitude >= 0.5 else {
            return "Vous ne vous êtes pas trompé : votre estimation tombe juste, "
                + "à moins d’un demi-diaphragme près."
        }
        let stops = oneDecimal(magnitude)
        return drift > 0
            ? "Il y a \(stops) diaphragme\(magnitude >= 2 ? "s" : "") de moins que vous ne pensiez."
            : "Il y a \(stops) diaphragme\(magnitude >= 2 ? "s" : "") de plus que vous ne pensiez."
    }

    /// Les capteurs ne s'accordent pas tous ; l'écart d'un téléphone donné avec
    /// une cellule à main est constant, donc réglable une fois pour toutes.
    private var calibration: some View {
        FieldRow(label: "Correction du posemètre") {
            VStack(alignment: .leading, spacing: 6) {
                ScaleDial(
                    values: [-1, -0.5, -(1.0 / 3), 0, 1.0 / 3, 0.5, 1] as [Double],
                    label: { value in
                        value == 0 ? "0" : (value > 0 ? "+\(oneDecimal(value))" : oneDecimal(value))
                    },
                    selection: Binding<Double?>(
                        get: { meter.calibrationStops },
                        set: {
                            meter.calibrationStops = $0 ?? 0
                            onCalibrate($0 ?? 0)
                        }))
                Text("À ne toucher qu’après comparaison avec une cellule ou un boîtier dont vous êtes sûr.")
                    .font(Typo.caption)
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func unavailable(_ title: String, _ message: String) -> some View {
        EmptyState(title: title, message: message)
    }

    // MARK: - Mise en forme

    /// La vitesse que donnerait la mesure sur le matériel employé : c'est cela
    /// qu'on va régler, pas un indice de lumination.
    private func shutterHere(_ reading: Meter.Reading) -> String? {
        let seconds = Exposure.shutterSeconds(
            ev100: reading.ev100, iso: iso, aperture: aperture)
        return Exposure.nearestShutter(in: availableShutters, to: seconds)
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
