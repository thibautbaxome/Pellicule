// swift-tools-version: 6.0
import PackageDescription

// Noyau métier de Pellicule, sans aucune dépendance aux SDK Apple : il compile
// et se teste aussi bien sur Linux que sur iOS. C'est ce qui permet de valider
// tous les calculs argentiques hors de tout simulateur.
let package = Package(
    name: "PelliculeCore",
    // Sans cette déclaration, Xcode compile le paquet pour iOS 12 quelle que
    // soit la cible de l'application, et `@Observable` — qui date d'iOS 17 —
    // n'existe pas. Aucun effet sur Linux, où ces versions ne veulent rien dire.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PelliculeCore", targets: ["PelliculeCore"])
    ],
    targets: [
        .target(
            name: "PelliculeCore",
            // Les banques de matériel — boîtiers, objectifs, pellicules — sont
            // de simples fichiers JSON édités à la main, empaquetés avec le
            // module. C'est la contribution la plus utile au projet.
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PelliculeCoreTests",
            dependencies: ["PelliculeCore"],
            // Une sauvegarde et un export réellement produits par les boutons de
            // l'application, et non écrits pour l'occasion : une fixture rédigée
            // à la main dériverait du format sans qu'on s'en aperçoive.
            resources: [.copy("Fixtures")]
        ),
    ]
)
