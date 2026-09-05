import PelliculeCore
import SwiftUI

struct RollsScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette
    @State private var isLoadingRoll = false

    var body: some View {
        NavigationStack {
            Group {
                if carnet.rolls.isEmpty {
                    if carnet.cameras.isEmpty {
                        EmptyState(
                            title: "Aucun rouleau",
                            message: "Déclarez d’abord un boîtier dans l’onglet Matériel, puis chargez votre première pellicule.")
                    } else {
                        EmptyState(
                            title: "Aucun rouleau",
                            message: "Chargez une pellicule pour commencer à consigner vos vues.",
                            actionTitle: "Charger une pellicule",
                            action: { isLoadingRoll = true })
                    }
                } else {
                    rollList
                }
            }
            .carnetBackground(palette)
            .navigationTitle("Rouleaux")
            .toolbar {
                if !carnet.cameras.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isLoadingRoll = true
                        } label: {
                            Label("Charger une pellicule", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isLoadingRoll) {
                LoadRollSheet(carnet: carnet)
            }
        }
    }

    private var rollList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !carnet.openRolls.isEmpty {
                    section("Dans un boîtier", rolls: carnet.openRolls)
                }
                if !carnet.closedRolls.isEmpty {
                    section("Terminés", rolls: carnet.closedRolls)
                }
            }
            .padding(16)
        }
    }

    private func section(_ title: String, rolls: [Model.Roll]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(title)
                .padding(.top, 6)
            ForEach(rolls) { roll in
                NavigationLink {
                    RollScreen(carnet: carnet, rollId: roll.id)
                } label: {
                    RollCard(carnet: carnet, roll: roll)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Carte de rouleau, traitée comme l'étiquette d'une boîte de film : un liseré
/// coloré par type d'émulsion, la mention du format en capitales, et le
/// compteur de poses en cadran.
struct RollCard: View {
    let carnet: Carnet
    let roll: Model.Roll

    @Environment(\.palette) private var palette

    private var film: Model.FilmStock? { carnet.film(id: roll.filmStockId) }
    private var camera: Model.Camera? { carnet.camera(id: roll.cameraId) }
    private var shotCount: Int { carnet.frames(ofRoll: roll.id).count }

    /// Le liseré reprend le code couleur des boîtes : argenté pour le noir et
    /// blanc, doré pour le négatif couleur, bleu pour la diapositive.
    private var emulsionColour: Color {
        switch film?.type {
        case .blackAndWhite: Color(hex: 0xB9B2A4)
        case .colourNegative: Color(hex: 0xE0A23C)
        case .slide: Color(hex: 0x6E93C4)
        case nil: palette.line
        }
    }

    private var pushPull: String? {
        guard let film else { return nil }
        let stops = roll.pushPullStops(boxIso: film.iso)
        guard abs(stops) > 0.01 else { return nil }
        let rounded = (stops * 10).rounded() / 10
        return stops > 0 ? "PUSH +\(trimmed(rounded))" : "PULL \(trimmed(rounded))"
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(emulsionColour)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(roll.label ?? film?.displayName ?? "Rouleau")
                        .font(Typo.heading)
                        .foregroundStyle(palette.text)
                    Spacer()
                    MicroLabel(roll.status.label, colour: palette.accent)
                }

                if roll.label != nil, let film {
                    Text(film.displayName)
                        .font(Typo.caption)
                        .foregroundStyle(palette.textDim)
                }

                HStack(spacing: 10) {
                    MicroLabel("135")
                    ValueText(
                        text: "\(Int(roll.shotIso)) ISO", size: 13, colour: palette.textDim)
                    if let pushPull {
                        MicroLabel(pushPull, colour: palette.accent)
                    }
                    Spacer()
                    ValueText(
                        text: "\(shotCount)/\(roll.exposures)", size: 16, weight: .bold)
                }

                if let camera {
                    Text(camera.name)
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                }
            }
            .padding(14)
        }
        .background(palette.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
