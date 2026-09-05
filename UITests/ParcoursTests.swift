import XCTest

/// Parcours de bout en bout dans le simulateur.
///
/// C'est le seul œil dont dispose ce projet sur son interface : elle s'écrit
/// dans un environnement sans macOS, donc sans simulateur. Ce parcours tient
/// lieu de regard — il échoue si un écran ne s'affiche pas, et il produit une
/// capture à chaque étape, qui sont ensuite publiées et relues.
///
/// Il traverse le geste réel dans son ordre : déclarer un boîtier, charger une
/// pellicule, noter une vue. Un écran qu'on ne peut pas atteindre par ce chemin
/// n'est pas atteignable par un photographe non plus.
final class ParcoursTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-carnet-neuf"]
        app.launch()
    }

    /// Quel que soit le sort du parcours, l'écran tel qu'il était à la fin.
    /// Sur échec, c'est la capture la plus utile : elle montre où ça a bloqué,
    /// là où le message d'erreur ne dit que ce qui manquait.
    override func tearDownWithError() throws {
        capture("99-etat-final")
    }

    /// Le parcours complet, en une seule fonction : chaque étape dépend de la
    /// précédente, et les découper obligerait à rejouer les mêmes gestes.
    func testParcoursComplet() throws {
        // MARK: Démarrage
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "l’application n’a pas affiché sa barre d’onglets : elle a probablement planté au lancement")
        capture("01-demarrage")

        XCTAssertTrue(
            app.staticTexts["Aucun rouleau"].exists,
            "un carnet vierge doit expliquer par où commencer")

        // MARK: Déclarer un boîtier
        tapTab("Matériel")
        capture("02-materiel-vide")

        tap(button: "Chercher mon boîtier")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "la banque doit être cherchable")
        search.tap()
        // Mots dans le désordre et sans le tiret : la recherche doit suivre.
        search.typeText("minolta 300")

        let x300 = app.staticTexts["Minolta X-300"]
        XCTAssertTrue(
            x300.waitForExistence(timeout: 10),
            "« minolta 300 » doit trouver le X-300")
        capture("03-banque-boitiers")
        x300.tap()

        XCTAssertTrue(
            app.staticTexts["Minolta X-300"].waitForExistence(timeout: 10),
            "le boîtier choisi doit apparaître dans le matériel")
        XCTAssertTrue(
            app.staticTexts["1s – 1/1000"].exists,
            "la plage de vitesses du boîtier doit être reprise de la banque")
        capture("04-materiel")

        // Le boîtier s'ouvre et se corrige : sans cela une entrée fausse le
        // resterait pour toujours.
        app.staticTexts["Minolta X-300"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Plage de vitesses"].waitForExistence(timeout: 10),
            "la fiche du boîtier doit exposer sa plage de vitesses")
        capture("04b-boitier-edition")
        tap(button: "Annuler")

        // MARK: Charger une pellicule
        tapTab("Rouleaux")
        tap(button: "Charger une pellicule")
        capture("05-chargement")

        tap(button: "Choisir dans la banque")
        let filmSearch = app.searchFields.firstMatch
        XCTAssertTrue(filmSearch.waitForExistence(timeout: 10))
        filmSearch.tap()
        filmSearch.typeText("tri-x")

        let triX = app.staticTexts["Kodak Tri-X 400"]
        XCTAssertTrue(triX.waitForExistence(timeout: 10))
        triX.tap()

        XCTAssertTrue(
            app.staticTexts["Exposée à"].waitForExistence(timeout: 10),
            "le choix d’une pellicule doit ouvrir la sensibilité employée")
        capture("06-chargement-rempli")

        // Pousser d'un diaphragme : l'application doit dire ce que cela
        // implique au développement, sans qu'on ait à le demander.
        if app.buttons["800"].exists {
            app.buttons["800"].tap()
            capture("07-pousse")
        }

        tap(button: "Charger")

        // MARK: Le rouleau
        let card = app.staticTexts["Kodak Tri-X 400"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 10),
            "le rouleau chargé doit apparaître dans la liste")
        capture("08-liste-rouleaux")
        card.tap()

        XCTAssertTrue(
            app.buttons["Noter une vue"].waitForExistence(timeout: 10),
            "un rouleau ouvert doit proposer de noter une vue")
        capture("09-rouleau")

        // MARK: Noter une vue
        tap(button: "Noter une vue")
        XCTAssertTrue(
            app.staticTexts["Vitesse"].waitForExistence(timeout: 10),
            "la saisie doit commencer par la vitesse")
        capture("10-vue-vierge")

        // Les graduations sont bornées par le matériel : le X-300 plafonne à
        // 1/1000, donc 1/2000 ne doit pas être proposé.
        XCTAssertTrue(app.buttons["1/1000"].exists, "le X-300 monte au 1/1000")
        XCTAssertFalse(
            app.buttons["1/2000"].exists,
            "le X-300 ne monte pas au 1/2000 : la graduation ne doit pas le proposer")

        app.buttons["1/125"].tap()
        if app.buttons["f/8"].exists { app.buttons["f/8"].tap() }
        capture("11-vue-reglee")

        // Les détails repliés : filtre, position, mesure. Le filtre passe par la
        // banque, avec le coût de chacun.
        tap(button: "Plus de détails")
        XCTAssertTrue(
            app.staticTexts["Filtre"].waitForExistence(timeout: 10),
            "les détails doivent proposer le filtre")
        app.swipeUp()
        capture("11b-vue-details")
        tap(button: "Aucun")
        XCTAssertTrue(
            app.staticTexts["Rouge n°25"].waitForExistence(timeout: 10),
            "la banque de filtres doit s’ouvrir")
        capture("11c-filtres")
        app.staticTexts["Rouge n°25"].tap()
        XCTAssertTrue(
            app.staticTexts["Rouge n°25"].waitForExistence(timeout: 10),
            "le filtre choisi doit apparaître sur la vue")

        tap(button: "Enregistrer")
        XCTAssertTrue(
            app.staticTexts["1/125   f/8"].waitForExistence(timeout: 10),
            "la vue enregistrée doit s’afficher avec son couple")
        capture("12-rouleau-une-vue")

        // La fiche du rouleau : archive, laboratoire, développement, coûts.
        tap(button: "Actions")
        tap(button: "Le rouleau")
        XCTAssertTrue(
            app.staticTexts["Référence d’archive"].waitForExistence(timeout: 10),
            "la fiche du rouleau doit exposer la référence d’archive")
        capture("12b-rouleau-fiche")
        app.switches.firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Révélateur"].waitForExistence(timeout: 10),
            "développer soi-même ouvre le journal de développement")
        app.swipeUp()
        capture("12c-developpement")
        tap(button: "Annuler")

        // Vers les scans : sans fichier choisi, l'écran explique et attend.
        tap(button: "Actions")
        tap(button: "Vers les scans")
        XCTAssertTrue(
            app.buttons["Choisir les fichiers"].waitForExistence(timeout: 10),
            "l’export doit commencer par le choix des scans")
        capture("12d-vers-les-scans")
        tap(button: "Fermer")

        // MARK: L'assistant
        tapTab("Assistant")
        XCTAssertTrue(
            app.staticTexts["Ce que je veux faire"].waitForExistence(timeout: 10),
            "l’assistant doit partir de l’intention")
        capture("13-assistant")

        // Le rouleau chargé doit alimenter l’assistant sans qu’on le ressaisisse.
        XCTAssertTrue(
            app.staticTexts["Kodak Tri-X 400"].exists,
            "l’assistant doit raisonner sur le rouleau en cours")

        // Le posemètre. Un simulateur n'a pas de caméra : l'application doit
        // le dire franchement plutôt que d'afficher un chiffre sans fondement.
        tap(button: "Mesurer avec la caméra")
        XCTAssertTrue(
            app.staticTexts["Pas de caméra"].waitForExistence(timeout: 15),
            "sans caméra, le posemètre doit le dire au lieu d’inventer une mesure")
        capture("13b-posemetre-sans-camera")
        tap(button: "Fermer")

        // Changer d’intention doit changer le conseil, pas seulement l’étiquette.
        tap(button: "Paysage")
        capture("14-assistant-paysage")
        tap(button: "Pose longue")
        capture("15-assistant-pose-longue")

        // MARK: Réglages et statistiques
        tapTab("Réglages")
        capture("16-reglages")

        tap(button: "Statistiques")
        XCTAssertTrue(
            app.staticTexts["Pellicules employées"].waitForExistence(timeout: 10),
            "les statistiques doivent lister les pellicules")
        capture("16b-statistiques")
        app.navigationBars.buttons.firstMatch.tap()

        // MARK: Les thèmes

        tap(button: "Papier")
        capture("17-theme-papier")

        tap(button: "Chambre noire")
        capture("18-theme-chambre-noire")

        tap(button: "Sombre")
    }

    // MARK: - Outils

    private func tapTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(
            tab.waitForExistence(timeout: 10), "onglet « \(name) » introuvable",
            file: file, line: line)
        tab.tap()
    }

    private func tap(button label: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(
            button.waitForExistence(timeout: 10), "bouton « \(label) » introuvable",
            file: file, line: line)
        button.tap()
    }

    /// Les captures survivent au succès du test : ce sont elles qu'on regarde,
    /// le test réussît-il.
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
