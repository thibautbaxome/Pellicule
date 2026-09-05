import PelliculeCore
import SwiftUI

/// Choix dans les banques livrées.
///
/// La recherche est celle du noyau : insensible à la casse et aux accents, et
/// acceptant les mots dans le désordre, pour que « minolta 300 » trouve le
/// X-300 et « voigtlander » le Voigtländer.

struct FilmPickerSheet: View {
    let onPick: (Catalog.Film) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var query = ""

    /// Sans recherche, les émulsions courantes plutôt qu'une liste vide.
    private var results: [Catalog.Film] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? Array(Catalog.films.filter { $0.discontinued != true }.prefix(30))
            : Catalog.searchFilms(query, limit: 40)
    }

    var body: some View {
        NavigationStack {
            List(results) { film in
                Button {
                    onPick(film)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(film.displayName)
                            .font(Typo.body)
                            .foregroundStyle(palette.text)
                        HStack(spacing: 8) {
                            ValueText(text: "\(Int(film.iso)) ISO", size: 12, colour: palette.accent)
                            MicroLabel(film.type.label)
                            if film.discontinued == true {
                                MicroLabel("Arrêtée", colour: palette.textFaint)
                            }
                        }
                    }
                }
                .listRowBackground(palette.surface)
            }
            .listStyle(.plain)
            .carnetBackground(palette)
            .searchable(text: $query, prompt: "Tri-X, Portra, HP5…")
            .navigationTitle("Pellicule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct CameraPickerSheet: View {
    let onPick: (Catalog.Camera) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var query = ""

    private var results: [Catalog.Camera] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? Array(Catalog.cameras.prefix(30))
            : Catalog.searchCameras(query, limit: 40)
    }

    var body: some View {
        NavigationStack {
            List(results) { camera in
                Button {
                    onPick(camera)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(camera.displayName)
                            .font(Typo.body)
                            .foregroundStyle(palette.text)
                        HStack(spacing: 8) {
                            MicroLabel(camera.type.label)
                            MicroLabel(camera.mount, colour: palette.accent)
                            if let fastest = camera.shutterFastest,
                               let slowest = camera.shutterSlowest {
                                ValueText(
                                    text: "\(slowest) – \(fastest)", size: 12,
                                    colour: palette.textDim)
                            }
                            if let years = camera.years {
                                MicroLabel(years)
                            }
                        }
                    }
                }
                .listRowBackground(palette.surface)
            }
            .listStyle(.plain)
            .carnetBackground(palette)
            .searchable(text: $query, prompt: "Minolta X-300, Nikon FM2…")
            .navigationTitle("Boîtier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct LensPickerSheet: View {
    /// Monture du boîtier déclaré : sans elle on montrerait des objectifs
    /// impossibles à visser.
    var mount: String?
    let onPick: (Catalog.Lens) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var query = ""

    private var results: [Catalog.Lens] {
        Catalog.searchLenses(query, mount: mount, limit: 40)
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    EmptyState(
                        title: "Rien à proposer",
                        message: mount == nil
                            ? "Cherchez par marque ou par focale, ou déclarez l’objectif à la main."
                            : "Aucun objectif de la banque ne se monte en \(mount ?? "") avec ces mots. Vous pouvez le déclarer à la main.")
                } else {
                    List(results) { lens in
                        Button {
                            onPick(lens)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(lens.brand) \(lens.name)")
                                    .font(Typo.body)
                                    .foregroundStyle(palette.text)
                                HStack(spacing: 8) {
                                    ValueText(
                                        text: lens.focalLabel, size: 12, colour: palette.accent)
                                    ValueText(
                                        text: "f/\(trimmed(lens.maxAperture))", size: 12,
                                        colour: palette.textDim)
                                    MicroLabel(lens.mount)
                                }
                            }
                        }
                        .listRowBackground(palette.surface)
                    }
                    .listStyle(.plain)
                }
            }
            .carnetBackground(palette)
            .searchable(text: $query, prompt: "50mm, Nikkor, zoom…")
            .navigationTitle("Objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
