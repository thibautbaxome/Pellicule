import PelliculeCore
import SwiftUI

/// L'aide à la décision.
///
/// Cinq calculateurs posés côte à côte n'aident personne : il faut déjà savoir
/// lequel ouvrir. Cet écran part de l'autre bout — ce qu'on veut faire, et la
/// lumière qu'on a devant soi — et en déduit le réglage. Les curseurs servent
/// ensuite à répondre à la seule question qui compte sur le terrain : « qu'est-ce
/// qui se passe si je change ça ? »
struct AssistantScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette

    @State private var intent: Assistant.Intent = .portrait
    @State private var conditionId = "sunny"
    @State private var aperture: Double?
    @State private var distance: Double = 3
    @State private var focal: Double = 50
    /// Lumière relevée à la caméra. Prime sur l'estimation à l'œil tant qu'on
    /// n'a pas repris la main en choisissant une condition.
    @State private var measuredEV: Double?
    @State private var isMetering = false

    /// Le rouleau en cours donne la sensibilité et le film ; à défaut, on
    /// raisonne sur du 400 ISO, l'émulsion la plus courante.
    private var roll: Model.Roll? { carnet.openRolls.first }
    private var film: Model.FilmStock? { roll.flatMap { carnet.film(id: $0.filmStockId) } }
    private var camera: Model.Camera? { roll.flatMap { carnet.camera(id: $0.cameraId) } }
    private var iso: Double { roll?.shotIso ?? 400 }

    private var condition: Light.Condition {
        Light.condition(id: conditionId) ?? Light.conditions[1]
    }

    /// L'indice employé pour tout le reste de l'écran : la mesure quand il y
    /// en a une, l'estimation sinon.
    private var ev100: Double { measuredEV ?? condition.ev100 }

    private var spec: Assistant.IntentSpec { Assistant.spec(for: intent) }

    private var availableShutters: [String] {
        let declared = camera?.availableShutters ?? []
        return declared.isEmpty ? Exposure.fullShutters : declared
    }

    /// Premier objectif montable sur le boîtier du rouleau, s'il y en a un.
    private var mountedLens: Model.Lens? {
        camera.flatMap { carnet.lenses(forCamera: $0).first }
    }

    /// Un conseil hors de portée de l'objectif ne sert à rien — et faute
    /// d'objectif déclaré, un conseil à f/1 encore moins.
    private var apertureRange: Carnet.ApertureRange {
        carnet.apertureRange(forCamera: camera, lensId: mountedLens?.id)
    }

    private var availableApertures: [Double] { apertureRange.values }

    /// L'ouverture de départ tient compte des vitesses du boîtier : demander
    /// « le plus de flou possible » n'a de sens que dans les limites de ce que
    /// l'obturateur sait accompagner.
    private var workingAperture: Double {
        aperture ?? Assistant.startingAperture(
            for: spec, available: availableApertures,
            ev100: ev100, iso: iso,
            availableShutters: availableShutters)
    }

    private var result: Assistant.Result {
        Assistant.advise(
            Assistant.Input(
                ev100: ev100,
                iso: iso,
                aperture: workingAperture,
                focal: focal,
                distance: distance,
                circleOfConfusion: carnet.settings.circleOfConfusion,
                handheld: spec.handheld,
                availableShutters: availableShutters,
                availableApertures: availableApertures,
                reciprocity: film?.model,
                desiredShutterSeconds: desiredShutterSeconds))
    }

    private var desiredShutterSeconds: Double? {
        if case .shutterSeconds(let seconds) = spec.target { return seconds }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    verdict
                    contextLine
                    intentPicker
                    meterButton
                    lightPicker
                    aperturePicker
                    if spec.handheld { distanceSlider }
                    focalSlider
                    depthOfField
                    adviceList
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Assistant")
            .sheet(isPresented: $isMetering) {
                MeterSheet(
                    iso: iso,
                    aperture: workingAperture,
                    availableShutters: availableShutters,
                    estimated: condition,
                    calibrationStops: carnet.settings.meterCalibrationStops ?? 0
                ) { measured in
                    measuredEV = measured
                    // La condition nommée la plus proche sert d'étiquette, mais
                    // c'est la mesure elle-même qui gouverne les calculs.
                    if let named = Meter.nearestCondition(toEV100: measured) {
                        conditionId = named.id
                    }
                } onCalibrate: { stops in
                    var updated = carnet.settings
                    updated.meterCalibrationStops = stops == 0 ? nil : stops
                    carnet.save(updated)
                }
            }
            .onChange(of: intent) { _, _ in
                // Changer d'intention change l'ouverture de départ : garder
                // l'ancienne donnerait un conseil qui ne sert plus l'intention.
                aperture = nil
                if case .metres(let metres) = spec.focus { distance = metres }
            }
        }
    }

    /// Le couple vitesse/ouverture, en gros, en haut. C'est la seule chose
    /// qu'on regarde en levant les yeux de l'appareil.
    private var verdict: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel(spec.label, colour: palette.accent)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    ValueText(
                        text: result.shutter ?? "—", size: 36, weight: .bold,
                        colour: outOfRange ? palette.danger : palette.text)
                    Text("·")
                        .font(Typo.hero)
                        .foregroundStyle(palette.line)
                    ValueText(
                        text: "f/\(trimmed(workingAperture))", size: 36, weight: .bold,
                        colour: outOfRange ? palette.danger : palette.text)
                    Spacer()
                }
                Text(spec.goal)
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)

                if let suggested = result.suggestedAperture {
                    Button("Corriger à f/\(trimmed(suggested))") {
                        aperture = suggested
                    }
                    .buttonStyle(SecondaryButtonStyle(palette: palette))
                    .padding(.top, 4)
                }
            }
        }
    }

    private var outOfRange: Bool { result.tooBright || result.tooDark }

    /// D'où viennent les chiffres : sans cette ligne, on ne sait pas si
    /// l'application parle du rouleau chargé ou d'une hypothèse.
    private var contextLine: some View {
        HStack(spacing: 10) {
            if let film {
                MicroLabel(film.displayName)
            } else {
                MicroLabel("Aucun rouleau en cours")
            }
            ValueText(text: "\(Int(iso)) ISO", size: 12, colour: palette.accent)
            if let camera {
                MicroLabel(camera.name)
            }
            Spacer()
            if measuredEV != nil {
                MicroLabel("Mesuré", colour: palette.ok)
            }
        }
    }

    private var intentPicker: some View {
        FieldRow(label: "Ce que je veux faire") {
            chipRow(Assistant.intents.map(\.intent), label: { Assistant.spec(for: $0).label }) {
                $0 == intent
            } action: {
                intent = $0
            }
        }
    }

    /// La mesure à la caméra, offerte juste avant le choix à l'œil : c'est
    /// l'ordre dans lequel on hésite.
    private var meterButton: some View {
        Button {
            isMetering = true
        } label: {
            Label(
                measuredEV == nil ? "Mesurer avec la caméra" : "Mesurer à nouveau",
                systemImage: "sun.max")
        }
        .buttonStyle(SecondaryButtonStyle(palette: palette))
    }

    private var lightPicker: some View {
        FieldRow(label: "La lumière que j’ai") {
            VStack(alignment: .leading, spacing: 8) {
                chipRow(Light.conditions, label: \.label) { $0.id == conditionId } action: {
                    conditionId = $0.id
                    // Choisir à la main, c'est reprendre la main : la mesure
                    // précédente ne décrit plus ce qu'on regarde.
                    measuredEV = nil
                }
                // On reconnaît une lumière à ses ombres, pas à un chiffre.
                Text(condition.shadows)
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aperturePicker: some View {
        FieldRow(label: "Ouverture") {
            VStack(alignment: .leading, spacing: 6) {
                ScaleDial(
                    values: availableApertures,
                    label: { "f/\(trimmed($0))" },
                    selection: Binding<Double?>(
                        get: { workingAperture },
                        set: { aperture = $0 }))
                if apertureRange.isAssumed {
                    Text("Aucun objectif déclaré : le conseil suppose un objectif courant. Ajoutez le vôtre dans Matériel pour qu’il soit juste.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var distanceSlider: some View {
        FieldRow(label: "Distance du sujet — \(formatDistance(distance))") {
            // Échelle logarithmique : de 0,5 m à 30 m, un pouce parcourt les
            // distances utiles sans écraser les courtes.
            Slider(
                value: Binding(
                    get: { log2(distance) },
                    set: { distance = pow(2, $0) }),
                in: log2(0.5)...log2(30))
                .tint(palette.accent)
        }
    }

    private var focalSlider: some View {
        FieldRow(label: "Focale — \(Int(focal)) mm") {
            Slider(
                value: Binding(get: { log2(focal) }, set: { focal = pow(2, $0).rounded() }),
                in: log2(20)...log2(300))
                .tint(palette.accent)
        }
    }

    /// La zone de netteté, tracée. Un chiffre ne dit pas si la marge est
    /// confortable ; une barre, si.
    @ViewBuilder
    private var depthOfField: some View {
        if let dof = result.depthOfField {
            FieldRow(label: "Zone de netteté") {
                VStack(alignment: .leading, spacing: 8) {
                    DepthOfFieldBar(depthOfField: dof, distance: distance)
                    HStack {
                        ValueText(text: formatDistance(dof.near), size: 13, colour: palette.textDim)
                        Spacer()
                        ValueText(
                            text: dof.far.isFinite ? formatDistance(dof.far) : "∞",
                            size: 13, colour: palette.textDim)
                    }
                    Text("Hyperfocale à \(formatDistance(dof.hyperfocal)) : au-delà, tout est net jusqu’à l’infini.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                }
            }
        }
    }

    private var adviceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(result.advice.enumerated()), id: \.offset) { _, advice in
                AdviceCard(advice: advice)
            }
        }
    }

    // MARK: - Briques

    /// Rangée de pastilles défilante, employée pour l'intention comme pour la
    /// lumière : deux choix de même nature méritent la même forme.
    private func chipRow<T>(
        _ values: [T],
        label: @escaping (T) -> String,
        isSelected: @escaping (T) -> Bool,
        action: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    let selected = isSelected(value)
                    Button {
                        action(value)
                    } label: {
                        Text(label(value))
                            .font(Typo.caption)
                            .foregroundStyle(selected ? palette.accentInk : palette.textDim)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(selected ? palette.accent : palette.sunken)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    selected ? Color.clear : palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func formatDistance(_ metres: Double) -> String {
        guard metres.isFinite else { return "∞" }
        return metres < 1
            ? "\(Int((metres * 100).rounded())) cm"
            : "\((metres * 10).rounded() / 10) m"
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Zone de netteté sur une échelle logarithmique : c'est la seule qui rende
/// comparables un portrait à deux mètres et un paysage à l'infini.
struct DepthOfFieldBar: View {
    let depthOfField: DepthOfField
    let distance: Double

    @Environment(\.palette) private var palette

    private let minimum = 0.3
    private let maximum = 60.0

    private func position(_ metres: Double) -> Double {
        guard metres.isFinite else { return 1 }
        let clamped = min(max(metres, minimum), maximum)
        return (log2(clamped) - log2(minimum)) / (log2(maximum) - log2(minimum))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let start = position(depthOfField.near) * width
            let end = position(depthOfField.far) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.sunken)
                    .frame(height: 10)
                Capsule()
                    .fill(palette.accent.opacity(0.55))
                    .frame(width: max(end - start, 3), height: 10)
                    .offset(x: start)
                // Le sujet lui-même, pour situer la marge de part et d'autre.
                Rectangle()
                    .fill(palette.text)
                    .frame(width: 2, height: 18)
                    .offset(x: position(distance) * width - 1)
            }
            .frame(height: 18)
        }
        .frame(height: 18)
    }
}

struct AdviceCard: View {
    let advice: Assistant.Advice

    @Environment(\.palette) private var palette

    private var colour: Color {
        switch advice.level {
        case .good: palette.ok
        case .info: palette.textDim
        case .warning: palette.accent
        case .danger: palette.danger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(colour)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(advice.title)
                    .font(Typo.ui(15, .semibold))
                    .foregroundStyle(palette.text)
                Text(advice.detail)
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
