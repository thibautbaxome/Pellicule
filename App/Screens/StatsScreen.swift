import PelliculeCore
import SwiftUI

/// Ce que le carnet sait dire de lui-même.
///
/// Des comptes, pas des graphiques : ce qu'on se demande vraiment, c'est ce
/// que coûte une vue, quelle émulsion on emploie le plus, et combien de
/// rouleaux dorment au laboratoire.
struct StatsScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette

    private var currency: String { carnet.settings.currency }

    var body: some View {
        // Le résumé est calculé une fois par rendu et passé aux sections : le
        // recalculer dans chaque ligne parcourait le carnet dix fois.
        let summary = Statistics.summary(rolls: carnet.rolls, frames: carnet.frames) {
            carnet.film(id: $0)?.displayName
        }
        Group {
            if carnet.rolls.isEmpty {
                EmptyState(
                    title: "Rien à compter",
                    message: "Les statistiques apparaîtront avec votre premier rouleau.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headline(summary)
                        statuses(summary)
                        films(summary)
                        habits(summary)
                    }
                    .padding(16)
                }
            }
        }
        .carnetBackground(palette)
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headline(_ s: Statistics.Summary) -> some View {
        HStack(spacing: 12) {
            figure("\(s.rolls)", s.rolls > 1 ? "rouleaux" : "rouleau")
            figure("\(s.frames)", s.frames > 1 ? "vues" : "vue")
            if let perFrame = s.costPerFrame {
                figure(Fmt.money(perFrame, currency: currency), "la vue")
            } else {
                figure("—", "la vue")
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                ValueText(text: value, size: 24, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                MicroLabel(label)
            }
        }
    }

    private func statuses(_ s: Statistics.Summary) -> some View {
        FieldRow(label: "Où en sont les rouleaux") {
            VStack(spacing: 6) {
                ForEach(Model.RollStatus.allCases, id: \.self) { status in
                    if let count = s.rollsByStatus[status], count > 0 {
                        HStack {
                            Text(status.label)
                                .font(Typo.body)
                                .foregroundStyle(palette.text)
                            Spacer()
                            ValueText(text: "\(count)", size: 15, colour: palette.accent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
        }
    }

    private func films(_ s: Statistics.Summary) -> some View {
        FieldRow(label: "Pellicules employées") {
            VStack(spacing: 6) {
                ForEach(s.films) { usage in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(usage.name)
                                .font(Typo.body)
                                .foregroundStyle(palette.text)
                            Text("\(usage.rolls) rouleau\(usage.rolls > 1 ? "x" : "")")
                                .font(Typo.caption)
                                .foregroundStyle(palette.textDim)
                        }
                        Spacer()
                        ValueText(text: "\(usage.frames)", size: 15, colour: palette.accent)
                        MicroLabel(usage.frames > 1 ? "vues" : "vue")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func habits(_ s: Statistics.Summary) -> some View {
        if s.frames > 0 || s.totalCost > 0 {
            FieldRow(label: "Habitudes") {
                VStack(alignment: .leading, spacing: 8) {
                    if s.mostUsedShutter != nil || s.mostUsedAperture != nil {
                        // L'un ou l'autre suffit : un compact sans bague
                        // d'ouverture a quand même une vitesse favorite.
                        let parts = [
                            s.mostUsedShutter,
                            s.mostUsedAperture.map { "f/\($0 == $0.rounded() ? String(Int($0)) : String($0))" },
                        ].compactMap { $0 }
                        line("Réglage le plus fréquent", parts.joined(separator: " · "))
                    }
                    if s.frames > 0 {
                        line("Vues géolocalisées", "\(s.framesWithLocation) sur \(s.frames)")
                        line("Vues gardées", "\(s.framesKept) sur \(s.frames)")
                    }
                    if s.totalCost > 0 {
                        line("Dépensé", Fmt.money(s.totalCost, currency: currency))
                    }
                }
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(palette.textDim)
            Spacer()
            ValueText(text: value, size: 14)
        }
    }
}
