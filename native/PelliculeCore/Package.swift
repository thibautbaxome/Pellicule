// swift-tools-version: 6.0
import PackageDescription

// Noyau métier de Pellicule, sans aucune dépendance aux SDK Apple : il compile
// et se teste aussi bien sur Linux que sur iOS. C'est ce qui permet de valider
// tous les calculs argentiques hors de tout simulateur.
let package = Package(
    name: "PelliculeCore",
    products: [
        .library(name: "PelliculeCore", targets: ["PelliculeCore"])
    ],
    targets: [
        .target(
            name: "PelliculeCore",
            // Les banques de matériel sont engendrées depuis les sources
            // TypeScript par tools/export-catalogs.mjs, puis empaquetées ici.
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PelliculeCoreTests",
            dependencies: ["PelliculeCore"],
            // Une sauvegarde réelle, produite par la version web via
            // tools/make-backup-fixture.mjs : écrite à la main, elle dériverait
            // du format sans qu'on s'en aperçoive.
            resources: [.copy("Fixtures")]
        ),
    ]
)
