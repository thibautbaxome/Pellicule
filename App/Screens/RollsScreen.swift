import PelliculeCore
import SwiftUI

struct RollsScreen: View {
    @Bindable var carnet: Carnet

    @Environment(\.palette) private var palette
    @State private var isLoadingRoll = false
    @State private var isPickingCamera = false

    /// Un boîtier archivé ne reçoit plus de rouleau : c'est le même critère
    /// que celui du chargement, sans quoi la feuille s'ouvrirait sur rien.
    private var hasUsableCamera: Bool { carnet.cameras.contains { !$0.archived } }

    var body: some View {
        NavigationStack {
            Group {
                if carnet.rolls.isEmpty {
                    if hasUsableCamera {
                        EmptyState(
                            title: "Aucun rouleau",
                            message: "Chargez une pellicule pour commencer à consigner vos vues.",
                            actionTitle: "Charger une pellicule",
                            action: { isLoadingRoll = true })
                    } else {
                        // Le premier écran d'un débutant : le geste qui manque
                        // doit être sous le doigt, pas dans un autre onglet.
                        EmptyState(
                            title: "Aucun rouleau",
                            message: "Commencez par déclarer le boîtier avec lequel vous photographiez ; vous chargerez ensuite votre première pellicule.",
                            actionTitle: "Chercher mon boîtier",
                            action: { isPickingCamera = true })
                    }
                } else {
                    rollList
                }
            }
            .carnetBackground(palette)
            .navigationTitle("Rouleaux")
            .toolbar {
                if hasUsableCamera {
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
            .sheet(isPresented: $isPickingCamera) {
                CameraPickerSheet { entry in
                    carnet.save(carnet.makeCamera(from: entry))
                }
            }
            // Une destination par valeur : le rouleau ouvert change de section
            // quand on le marque terminé, et un lien à destination fermée serait
            // retiré avec sa section — l'écran se refermerait sous le doigt.
            .navigationDestination(for: String.self) { rollId in
                RollScreen(carnet: carnet, rollId: rollId)
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
            .animation(.snappy, value: carnet.rolls.count)
        }
    }

    private func section(_ title: String, rolls: [Model.Roll]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(title)
                .padding(.top, 6)
            ForEach(rolls) { roll in
                let count = carnet.frames(ofRoll: roll.id).count
                NavigationLink(value: roll.id) {
                    RollCard(carnet: carnet, roll: roll)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(roll.label ?? carnet.film(id: roll.filmStockId)?.displayName ?? "Rouleau")
                .accessibilityHint("\(count) vue\(count > 1 ? "s" : "") sur \(roll.exposures), \(roll.status.label)")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

extension Model.Roll {
    /// L'écart à la sensibilité de la boîte, dit comme au laboratoire :
    /// « Poussée +1 », « Retenue −0,5 ». Le même libellé partout.
    func pushPullLabel(boxIso: Double) -> String? {
        let stops = pushPullStops(boxIso: boxIso)
        guard abs(stops) > 0.05 else { return nil }
        return (stops > 0 ? "Poussée " : "Retenue ") + Fmt.signedStops(stops)
    }
}

/// Carte de rouleau, traitée comme l'étiquette d'une boîte de film : un liseré
/// coloré par type d'émulsion, la mention de l'émulsion en capitales, et le
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
                    if let film {
                        MicroLabel(film.type.label)
                    }
                    ValueText(
                        text: "\(Int(roll.shotIso)) ISO", size: 13, colour: palette.textDim)
                    if let film, let pushPull = roll.pushPullLabel(boxIso: film.iso) {
                        MicroLabel(pushPull, colour: palette.accent)
                    }
                    Spacer()
                    ValueText(
                        text: "\(shotCount)/\(roll.exposures)", size: 16, weight: .bold,
                        colour: shotCount > roll.exposures ? palette.accent : palette.text)
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
