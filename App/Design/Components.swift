import SwiftUI

/// Briques communes à tous les écrans.
///
/// Elles portent le motif structurant du projet : la perforation 135. Il sert
/// de filet, de bord de carte, de séparateur — partout où une interface
/// ordinaire mettrait une ligne grise.

/// Filet perforé, à la place d'un séparateur.
struct SprocketRule: View {
    var holes: Int = 22

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<holes, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(palette.line)
                    .frame(width: 7, height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Carte : la surface sur laquelle se pose toute information du carnet.
struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Une carte qui se presse : elle s'enfonce d'un cheveu sous le doigt, comme
/// un déclencheur, et revient. C'est ce qui distingue un élément qu'on peut
/// toucher d'un simple bloc d'information.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Bouton principal d'un écran : ambré, plein, cible large.
struct PrimaryButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.ui(16, .semibold))
            .foregroundStyle(palette.accentInk)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(palette.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Bouton secondaire : contour seul, pour ne pas concurrencer le principal.
/// Une action destructrice passe `tint: palette.danger` — un `.foregroundStyle`
/// posé à l'extérieur du bouton ne traverse pas le style.
struct SecondaryButtonStyle: ButtonStyle {
    let palette: Palette
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.ui(16, .medium))
            .foregroundStyle(tint ?? palette.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(configuration.isPressed ? palette.raised : palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(palette.lineStrong, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Mise en forme des nombres à la française, partagée par tous les écrans :
/// une virgule décimale, et pas de « 1.0 » là où « 1 » suffit. Les ouvertures
/// restent écrites comme sur la bague — « f/5.6 » —, ce sont des noms.
enum Fmt {
    /// Un écart en diaphragmes : « 0,5 », « 1 », « 1,5 ».
    static func stops(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Un écart signé : « +1 », « −0,5 », « 0 ».
    static func signedStops(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0" }
        return (value > 0 ? "+" : "−") + stops(abs(value))
    }

    /// Un montant dans la devise du carnet : « 12,50 € ».
    static func money(_ value: Double, currency: String) -> String {
        value.formatted(.currency(code: currency).locale(Locale(identifier: "fr_FR")))
    }

    /// Une graduation qui contient à coup sûr la valeur courante : une bague
    /// dont la position actuelle ne serait pas gravée n'afficherait rien.
    static func including<T: Comparable & Hashable>(_ current: T?, in values: [T]) -> [T] {
        guard let current, !values.contains(current) else { return values }
        return (values + [current]).sorted()
    }
}

/// Graduation déroulée d'une bague d'objectif ou d'un barillet de vitesses.
///
/// Le natif apporte ici ce que le navigateur ne savait pas faire : l'inertie du
/// défilement iOS et un cran haptique à chaque valeur. Sur le terrain, c'est ce
/// qui permet de changer de vitesse sans quitter la scène des yeux.
struct ScaleDial<Value: Hashable>: View {
    let values: [Value]
    let label: (Value) -> String
    @Binding var selection: Value?

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        let isSelected = value == selection
                        Button {
                            selection = isSelected ? nil : value
                        } label: {
                            Text(label(value))
                                .font(Typo.value(15, isSelected ? .bold : .regular))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? palette.accentInk : palette.textDim)
                                .frame(minWidth: 62, minHeight: 44)
                                .background(isSelected ? palette.accent : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .id(value)

                        // Le trait de graduation entre deux valeurs, comme sur
                        // la bague elle-même.
                        Rectangle()
                            .fill(palette.line)
                            .frame(width: 1, height: 16)
                    }
                }
            }
            .background(palette.sunken)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 1))
            .sensoryFeedback(.selection, trigger: selection)
            .onAppear {
                if let selection { proxy.scrollTo(selection, anchor: .center) }
            }
            // La valeur choisie vient au centre, comme le cran d'une bague
            // sous le repère : touchée au bord, elle restait à moitié cachée.
            .onChange(of: selection) { _, selection in
                guard let selection else { return }
                withAnimation(.snappy) { proxy.scrollTo(selection, anchor: .center) }
            }
        }
    }
}

/// Écran vide : dire ce qui manque et proposer le geste, plutôt qu'afficher
/// une liste vide sans explication.
struct EmptyState: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            SprocketRule(holes: 8)
                .frame(width: 100)
            Text(title)
                .font(Typo.heading)
                .foregroundStyle(palette.text)
            Text(message)
                .font(Typo.body)
                .foregroundStyle(palette.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(palette: palette))
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Champ de saisie sur fond sombre : les champs système jurent avec la palette.
struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MicroLabel(label)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Fond de l'application, appliqué à un écran entier.
    ///
    /// L'expansion forcée n'est pas décorative : sans elle, la teinte ne peint
    /// que derrière le contenu, et le reste de l'écran garde le fond du
    /// système. Sur le thème sombre cela passait presque inaperçu ; en papier
    /// crème, une bande claire au milieu d'un écran blanc ne passe pas.
    func carnetBackground(_ palette: Palette) -> some View {
        self
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.bg.ignoresSafeArea())
            .toolbarBackground(palette.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(palette.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    /// Habillage d'un champ de texte pour le sortir du style système.
    func fieldStyle(_ palette: Palette) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(palette.sunken)
            .foregroundStyle(palette.text)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 1))
    }
}
