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
        .target(name: "PelliculeCore"),
        .testTarget(name: "PelliculeCoreTests", dependencies: ["PelliculeCore"]),
    ]
)
