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

    private var summary: Statistics.Summary {
        Statistics.summary(rolls: carnet.rolls, frames: carnet.frames) {
            carnet.film(id: $0)?.displayName
        }
    }

    var body: some View {
        ScrollView {
            if carnet.rolls.isEmpty {
                EmptyState(
                    title: "Rien à compter",
                    message: "Les statistiques apparaîtront avec votre premier rouleau.")
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    statuses
                    films
                    habits
                }
                .padding(16)
            }
        }
        .carnetBackground(palette)
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headline: some View {
        let s = summary
        return HStack(spacing: 12) {
            figure("\(s.rolls)", s.rolls > 1 ? "rouleaux" : "rouleau")
            figure("\(s.frames)", s.frames > 1 ? "vues" : "vue")
            if let perFrame = s.costPerFrame {
                figure(String(format: "%.2f €", perFrame), "la vue")
            } else {
                figure("—", "la vue")
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                ValueText(text: value, size: 24, weight: .bold)
                    .contentTransition(.numericText())
                MicroLabel(label)
            }
        }
    }

    private var statuses: some View {
        FieldRow(label: "Où en sont les rouleaux") {
            VStack(spacing: 6) {
                ForEach(Model.RollStatus.allCases, id: \.self) { status in
                    if let count = summary.rollsByStatus[status], count > 0 {
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

    private var films: some View {
        FieldRow(label: "Pellicules employées") {
            VStack(spacing: 6) {
                ForEach(summary.films) { usage in
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
    private var habits: some View {
        let s = summary
        if s.mostUsedShutter != nil || s.mostUsedAperture != nil || s.totalCost > 0 {
            FieldRow(label: "Habitudes") {
                VStack(alignment: .leading, spacing: 8) {
                    if let shutter = s.mostUsedShutter, let aperture = s.mostUsedAperture {
                        line("Réglage le plus fréquent",
                             "\(shutter) · f/\(aperture == aperture.rounded() ? String(Int(aperture)) : String(aperture))")
                    }
                    if s.frames > 0 {
                        line("Vues géolocalisées", "\(s.framesWithLocation) sur \(s.frames)")
                        line("Vues gardées", "\(s.framesKept) sur \(s.frames)")
                    }
                    if s.totalCost > 0 {
                        line("Dépensé", String(format: "%.2f €", s.totalCost))
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
