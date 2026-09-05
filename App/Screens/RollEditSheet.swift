import PelliculeCore
import SwiftUI

/// Tout ce qu'un rouleau porte au-delà de ses vues : d'où il vient, où il est
/// allé, ce qu'il a coûté, comment il a été développé.
///
/// Ces champs paraissent secondaires tant qu'on n'a qu'un rouleau. Ils
/// deviennent le carnet lui-même dès qu'on en a vingt — c'est par la référence
/// d'archive qu'on retrouve un négatif dans une boîte, et par le journal de
/// développement qu'on refait un tirage réussi.
struct RollEditSheet: View {
    @Bindable var carnet: Carnet
    @State var roll: Model.Roll

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private var film: Model.FilmStock? { carnet.film(id: roll.filmStockId) }

    /// Écart à l'ISO de la boîte : c'est lui qui allonge le développement.
    private var pushPull: Double {
        film.map { roll.pushPullStops(boxIso: $0.iso) } ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    identification
                    development
                    costs
                    FieldRow(label: "Notes") {
                        TextField("Ce qu'il faudra se rappeler…",
                                  text: optional($roll.notes), axis: .vertical)
                            .lineLimit(2...6)
                            .fieldStyle(palette)
                    }
                }
                .padding(16)
            }
            .carnetBackground(palette)
            .navigationTitle("Le rouleau")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer") {
                    roll.updatedAt = Carnet.timestamp(Date())
                    carnet.save(roll)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .padding(16)
                .background(palette.bg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    // MARK: - Identification

    private var identification: some View {
        VStack(alignment: .leading, spacing: 18) {
            FieldRow(label: "Nom") {
                TextField("Pointe du Raz, Sortie du dimanche…",
                          text: optional($roll.label))
                    .textInputAutocapitalization(.sentences)
                    .fieldStyle(palette)
            }

            FieldRow(label: "Référence d’archive") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("2026-014", text: optional($roll.archiveRef))
                        .fieldStyle(palette)
                    Text("Ce que vous écrivez sur la pochette du négatif. C’est par là qu’on retrouve une bande dans une boîte, des années plus tard — et c’est aussi le nom que prendront les fichiers à l’export.")
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FieldRow(label: "Laboratoire") {
                TextField("Où le rouleau part au développement",
                          text: optional($roll.lab))
                    .fieldStyle(palette)
            }
        }
    }

    // MARK: - Développement

    private var development: some View {
        FieldRow(label: "Développement") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(
                    get: { roll.development?.developedByOwner ?? false },
                    set: { own in
                        var current = roll.development ?? Self.emptyDevelopment
                        current.developedByOwner = own
                        roll.development = current
                    })
                ) {
                    Text("Développé par moi")
                        .font(Typo.body)
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)

                if roll.development?.developedByOwner == true {
                    ownDevelopment
                }
            }
        }
    }

    @ViewBuilder
    private var ownDevelopment: some View {
        VStack(alignment: .leading, spacing: 16) {
            developerPicker

            FieldRow(label: "Dilution") {
                TextField("1+1, B (1+31)…", text: developmentText(\.dilution))
                    .fieldStyle(palette)
            }

            FieldRow(label: "Température du bain") {
                ScaleDial(
                    values: [16, 18, 20, 22, 24] as [Double],
                    label: { "\(Int($0)) °C" },
                    selection: developmentValue(\.tempC))
            }

            if let suggestion = suggestedTime {
                suggestionCard(suggestion)
            }

            FieldRow(label: "Temps effectif") {
                ScaleDial(
                    values: developmentTimes,
                    label: { formatMinutes($0) },
                    selection: developmentValue(\.timeSec))
            }

            FieldRow(label: "Agitation") {
                TextField("30 s puis 5 s toutes les minutes",
                          text: developmentText(\.agitation))
                    .fieldStyle(palette)
            }
        }
    }

    /// Les révélateurs pour lesquels la banque publie un temps de référence sur
    /// cette pellicule ; les autres se saisissent à la main.
    private var developerPicker: some View {
        FieldRow(label: "Révélateur") {
            VStack(alignment: .leading, spacing: 8) {
                let known = Array(Set((film?.devTimes ?? []).map(\.developer))).sorted()
                if !known.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(known, id: \.self) { developer in
                                let selected = roll.development?.developer == developer
                                Button {
                                    var current = roll.development ?? Self.emptyDevelopment
                                    current.developer = selected ? nil : developer
                                    roll.development = current
                                } label: {
                                    Text(developer)
                                        .font(Typo.caption)
                                        .foregroundStyle(
                                            selected ? palette.accentInk : palette.textDim)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(selected ? palette.accent : palette.sunken)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                TextField("Ou un autre", text: developmentText(\.developer))
                    .fieldStyle(palette)
            }
        }
    }

    /// Le temps que la banque publie, corrigé de la température du bain et du
    /// push/pull du rouleau. Ce n'est pas une consigne : c'est un point de
    /// départ, et la notice du film reste l'autorité.
    private var suggestedTime: Development.Result? {
        guard let development = roll.development,
              let developer = development.developer,
              let entry = (film?.devTimes ?? []).first(where: {
                  $0.developer == developer
                      && (development.dilution == nil || $0.dilution == development.dilution)
              })
        else { return nil }

        return Development.time(
            base: entry.timeSec,
            temperature: development.tempC ?? entry.tempC,
            reference: entry.tempC,
            pushPullStops: pushPull)
    }

    private func suggestionCard(_ suggestion: Development.Result) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                MicroLabel("Temps suggéré", colour: palette.accent)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    ValueText(
                        text: formatMinutes(suggestion.correctedSeconds), size: 28, weight: .bold)
                    Spacer()
                    Button("Adopter") {
                        var current = roll.development ?? Self.emptyDevelopment
                        current.timeSec = suggestion.correctedSeconds
                        roll.development = current
                    }
                    .font(Typo.ui(14, .semibold))
                    .foregroundStyle(palette.accent)
                }
                Text(explanation(suggestion))
                    .font(Typo.caption)
                    .foregroundStyle(palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(suggestion.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(Typo.caption)
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func explanation(_ suggestion: Development.Result) -> String {
        var parts = ["Base publiée : \(formatMinutes(suggestion.baseSeconds))"]
        if abs(suggestion.temperatureFactor - 1) > 0.01 {
            parts.append(suggestion.temperatureFactor > 1
                ? "allongé par un bain plus froid"
                : "raccourci par un bain plus chaud")
        }
        if abs(pushPull) > 0.01 {
            parts.append(pushPull > 0
                ? "allongé par la poussée du rouleau"
                : "raccourci par la retenue du rouleau")
        }
        return parts.joined(separator: ", ") + ". La notice du film reste l’autorité."
    }

    /// Une graduation de temps, de trois à vingt minutes, au demi-quart de
    /// minute : c'est la finesse d'une minuterie de laboratoire.
    private var developmentTimes: [Double] {
        stride(from: 180.0, through: 1_200.0, by: 15).map { $0 }
    }

    // MARK: - Coûts

    private var costs: some View {
        FieldRow(label: "Coûts") {
            VStack(alignment: .leading, spacing: 12) {
                costField("Pellicule", \.film)
                costField("Développement", \.development)
                costField("Numérisation", \.scan)
                costField("Tirages", \.prints)

                if let total = roll.costs?.total, total > 0 {
                    HStack {
                        MicroLabel("Total")
                        Spacer()
                        ValueText(
                            text: String(format: "%.2f €", total), size: 16, weight: .bold,
                            colour: palette.accent)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func costField(
        _ label: String, _ keyPath: WritableKeyPath<Model.Roll.Costs, Double?>
    ) -> some View {
        HStack {
            Text(label)
                .font(Typo.body)
                .foregroundStyle(palette.textDim)
            Spacer()
            TextField("—", text: Binding(
                get: {
                    guard let value = roll.costs?[keyPath: keyPath] else { return "" }
                    return String(format: "%g", value)
                },
                set: { text in
                    var current = roll.costs ?? Model.Roll.Costs(
                        film: nil, development: nil, scan: nil, prints: nil)
                    current[keyPath: keyPath] = Double(text.replacingOccurrences(of: ",", with: "."))
                    roll.costs = current
                }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .fieldStyle(palette)
        }
    }

    // MARK: - Liaisons

    private static let emptyDevelopment = Model.Roll.Development(
        developedByOwner: true, developer: nil, dilution: nil, timeSec: nil,
        tempC: nil, agitation: nil, developedAt: nil, notes: nil)

    private func developmentText(
        _ keyPath: WritableKeyPath<Model.Roll.Development, String?>
    ) -> Binding<String> {
        Binding(
            get: { roll.development?[keyPath: keyPath] ?? "" },
            set: { text in
                var current = roll.development ?? Self.emptyDevelopment
                current[keyPath: keyPath] = text.isEmpty ? nil : text
                roll.development = current
            })
    }

    private func developmentValue(
        _ keyPath: WritableKeyPath<Model.Roll.Development, Double?>
    ) -> Binding<Double?> {
        Binding(
            get: { roll.development?[keyPath: keyPath] },
            set: { value in
                var current = roll.development ?? Self.emptyDevelopment
                current[keyPath: keyPath] = value
                roll.development = current
            })
    }

    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func formatMinutes(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
