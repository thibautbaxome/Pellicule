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

    /// Sans recherche, toutes les émulsions encore fabriquées plutôt qu'une
    /// liste vide — ou tronquée, ce qui ferait croire qu'un film n'y est pas.
    private var results: [Catalog.Film] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? Catalog.films.filter { $0.discontinued != true }
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

    /// La banque entière quand on ne cherche rien : la liste est paresseuse,
    /// et n'en montrer que le début ferait croire qu'un boîtier y manque.
    private var results: [Catalog.Camera] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? Catalog.cameras
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
    /// Quand l'appelant sait déclarer un objectif à la main, l'état vide le
    /// propose ; sinon il ne promet rien qu'il ne puisse tenir.
    var onManual: (() -> Void)? = nil
    let onPick: (Catalog.Lens) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var query = ""
    @State private var allMounts = false

    /// La monture ne filtre que si la banque la connaît : une monture tapée à
    /// la main sous une variante, ou « Fixe », ferait une liste vide à jamais.
    private var usableMount: String? {
        guard let mount, mount != Catalog.fixedMountName,
              Catalog.lenses.contains(where: { $0.mount == mount })
        else { return nil }
        return mount
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var results: [Catalog.Lens] {
        let filter = allMounts ? nil : usableMount
        guard isSearching else {
            return filter == nil ? Catalog.lenses : Catalog.searchLenses("", mount: filter, limit: 200)
        }
        return Catalog.searchLenses(query, mount: filter, limit: 60)
    }

    private var emptyMessage: String {
        if let usableMount, !allMounts {
            return "Aucun objectif en monture \(usableMount) ne correspond. Élargissez à toutes les montures, ou cherchez autrement."
        }
        return "Aucun objectif de la banque ne correspond à ces mots. Essayez la marque ou la focale."
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    EmptyState(
                        title: "Rien à proposer",
                        message: emptyMessage + (onManual == nil ? "" : " Vous pouvez aussi le déclarer à la main."),
                        actionTitle: onManual == nil ? nil : "Déclarer à la main",
                        action: onManual.map { manual in { dismiss(); manual() } })
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
            .searchable(text: $query, prompt: "50mm, Nikkor, 35-70…")
            .navigationTitle(usableMount.map { "Objectifs \($0)" } ?? "Objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                if usableMount != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Un objectif adapté — un M42 sur un Pentax K — ne se
                        // trouve qu'en sortant de la monture du boîtier.
                        Button(allMounts ? "Cette monture" : "Toutes les montures") {
                            allMounts.toggle()
                        }
                    }
                }
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Choix d'un filtre.
///
/// Le facteur est ce qui compte : il dit combien de diaphragmes le filtre
/// coûte, donc de combien il faut rallonger la pose. L'effet est rappelé parce
/// qu'un débutant ne sait pas ce qu'un jaune n°8 fait à un ciel.
struct FilterPickerSheet: View {
    let onPick: (Filters.Preset?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        Text("Aucun filtre")
                            .font(Typo.body)
                            .foregroundStyle(palette.text)
                    }
                    .listRowBackground(palette.surface)
                }

                ForEach(Filters.Category.allCases, id: \.self) { category in
                    Section {
                        ForEach(Filters.presets(in: category)) { preset in
                            Button {
                                onPick(preset)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(preset.name)
                                            .font(Typo.body)
                                            .foregroundStyle(palette.text)
                                        Spacer()
                                        ValueText(
                                            text: preset.stops < 0.05
                                                ? "gratuit"
                                                : "+\(String(format: "%.1f", preset.stops)) IL",
                                            size: 13, colour: palette.accent)
                                    }
                                    Text(preset.effect)
                                        .font(Typo.caption)
                                        .foregroundStyle(palette.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .listRowBackground(palette.surface)
                        }
                    } header: {
                        MicroLabel(category.label)
                    }
                }
            }
            .listStyle(.plain)
            .carnetBackground(palette)
            .navigationTitle("Filtre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
