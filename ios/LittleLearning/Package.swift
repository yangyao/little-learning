// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LittleLearning",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.executable(name: "LittleLearning", targets: ["LittleLearning"])],
    targets: [
        .target(name: "LearningCore", path: "Core"),
        .executableTarget(name: "LittleLearning", dependencies: ["LearningCore"], path: "Sources", resources: [.copy("WebGames")])
    ]
)
