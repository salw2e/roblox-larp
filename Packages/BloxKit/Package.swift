// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BloxKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BloxKit", targets: ["BloxKit"])],
    targets: [
        .target(name: "BloxKit"),
        .testTarget(name: "BloxKitTests", dependencies: ["BloxKit"], resources: [.copy("Fixtures")]),
    ]
)
