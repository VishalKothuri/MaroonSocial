// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MaroonCore", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "MaroonCore", targets: ["MaroonCore"])],
  targets: [
    .target(name: "MaroonCore"), .testTarget(name: "MaroonCoreTests", dependencies: ["MaroonCore"]),
  ])
