import PelliculeCore
import SwiftUI

/// Un rouleau et ses vues.
///
/// L'écran est fait pour le terrain : le compteur de poses et le bouton de
/// saisie sont toujours atteignables au pouce, le reste défile.
struct RollScreen: View {
    @Bindable var carnet: Carnet
    let rollId: String

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var editedFrame: Model.Frame?
    @State private var isConfirmingDeletion = false

    private var roll: Model.Roll? { carnet.roll(id: rollId) }
    private var film: Model.FilmStock? { roll.flatMap { carnet.film(id: $0.filmStockId) } }
    private var camera: Model.Camera? { roll.flatMap { carnet.camera(id: $0.cameraId) } }
    private var frames: [Model.Frame] { carnet.frames(ofRoll: rollId) }

    var body: some View {
        Group {
            if let roll {
                content(roll: roll)
            } else {
                // Le rouleau vient d'être supprimé : la vue reste montée le
                // temps de la disparition de la navigation.
                Color.clear
            }
        }
        .carnetBackground(palette)
        .navigationTitle(roll?.label ?? film?.displayName ?? "Rouleau")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editedFrame) { frame in
            FrameSheet(carnet: carnet, frame: frame)
        }
    }

    @ViewBuilder
    private func content(roll: Model.Roll) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(roll: roll)
                SprocketRule()
                if frames.isEmpty {
                    EmptyState(
                        title: "Pellicule vierge",
                        message: "Notez votre première vue dès que vous l’avez prise : les réglages se reprennent ensuite d’une vue à l’autre.")
                } else {
                    ForEach(frames) { frame in
                        Button {
                            editedFrame = frame
                        } label: {
                            FrameRow(carnet: carnet, frame: frame)
                        }
                        .buttonStyle(.plain)
                    }
                }
                statusPicker(roll: roll)
                dangerZone(roll: roll)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if roll.status.isOpen {
                Button {
                    editedFrame = carnet.makeFrame(inRoll: rollId)
                } label: {
                    Label("Noter une vue", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
                .padding(16)
                .background(palette.bg)
            }
        }
    }

    private func header(roll: Model.Roll) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let film {
                            Text(film.displayName)
                                .font(Typo.heading)
                                .foregroundStyle(palette.text)
                        }
                        if let camera {
                            Text(camera.name)
                                .font(Typo.caption)
                                .foregroundStyle(palette.textDim)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        ValueText(text: "\(frames.count)", size: 30, weight: .bold)
                        MicroLabel("sur \(roll.exposures)")
                    }
                }

                HStack(spacing: 12) {
                    MicroLabel("135")
                    ValueText(text: "\(Int(roll.shotIso)) ISO", size: 13, colour: palette.accent)
                    if let film {
                        let stops = roll.pushPullStops(boxIso: film.iso)
                        if abs(stops) > 0.01 {
                            MicroLabel(
                                stops > 0 ? "Poussée" : "Retenue", colour: palette.accent)
                        }
                    }
                }
            }
        }
    }

    /// Le cycle de vie du rouleau, du boîtier à l'archive. C'est ce suivi qui
    /// permet de savoir, trois semaines plus tard, ce qui est parti au labo.
    private func statusPicker(roll: Model.Roll) -> some View {
        FieldRow(label: "Où en est ce rouleau") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Model.RollStatus.allCases, id: \.self) { status in
                        Button {
                            var updated = roll
                            updated.status = status
                            updated.updatedAt = Carnet.timestamp(Date())
                            if !status.isOpen, updated.finishedAt == nil {
                                updated.finishedAt = updated.updatedAt
                            }
                            carnet.save(updated)
                        } label: {
                            Text(status.label)
                                .font(Typo.caption)
                                .foregroundStyle(
                                    status == roll.status ? palette.accentInk : palette.textDim)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    status == roll.status ? palette.accent : palette.sunken)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func dangerZone(roll: Model.Roll) -> some View {
        Button("Supprimer ce rouleau", role: .destructive) {
            isConfirmingDeletion = true
        }
        .buttonStyle(SecondaryButtonStyle(palette: palette))
        .foregroundStyle(palette.danger)
        .padding(.top, 20)
        .confirmationDialog(
            "Supprimer ce rouleau et ses \(frames.count) vue\(frames.count > 1 ? "s" : "") ?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                carnet.delete(rollId: rollId)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les vues notées disparaîtront avec lui. C’est sans retour.")
        }
    }
}

/// Une vue dans la liste : le numéro, puis le couple vitesse/ouverture, lus
/// comme sur une planche contact.
struct FrameRow: View {
    let carnet: Carnet
    let frame: Model.Frame

    @Environment(\.palette) private var palette

    private var exposure: String {
        let shutter = frame.shutter ?? "—"
        let aperture = frame.aperture.map { value in
            value == value.rounded() ? "f/\(Int(value))" : "f/\(value)"
        } ?? "—"
        return "\(shutter)   \(aperture)"
    }

    var body: some View {
        HStack(spacing: 12) {
            ValueText(
                text: String(format: "%02d", frame.number), size: 15, weight: .bold,
                colour: palette.accent)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                ValueText(text: exposure, size: 15)
                if let subject = frame.subject, !subject.isEmpty {
                    Text(subject)
                        .font(Typo.caption)
                        .foregroundStyle(palette.textDim)
                        .lineLimit(1)
                } else if let lens = frame.lensId.flatMap({ carnet.lens(id: $0) }) {
                    Text(lens.name)
                        .font(Typo.caption)
                        .foregroundStyle(palette.textFaint)
                        .lineLimit(1)
                }
            }

            Spacer()

            if frame.location != nil {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1))
    }
}
