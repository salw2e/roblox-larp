// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalBloxKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SalBloxKit", targets: ["SalBloxKit"])],
    targets: [
        .target(name: "SalBloxKit"),
        .testTarget(name: "SalBloxKitTests", dependencies: ["SalBloxKit"], resources: [.copy("Fixtures")]),
    ]
)
