// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FolioReaderKit",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FolioReaderKit",
            targets: ["FolioReaderKit"]),
    ],
    dependencies: [
		.package(url: "https://github.com/ZipArchive/ZipArchive.git", majorVersion: 2, minor: 1),
		.package(url: "https://github.com/cxa/MenuItemKit.git", majorVersion: 3, minor: 0),
		.package(url: "https://github.com/zoonooz/ZFDragableModalTransition.git", majorVersion: 0, minor: 6),
		.package(url: "https://github.com/tadija/AEXML.git", majorVersion: 4, minor: 2),
		.package(url: "https://github.com/ArtSabintsev/FontBlaster.git", majorVersion: 4, minor: 0),
		.package(url: "https://github.com/fantim/JSQWebViewController.git", majorVersion: 6, minor: 1),
		.package(url: "https://github.com/realm/realm-cocoa.git", majorVersion: 3, minor: 1),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FolioReaderKit",
            path: "Source",
            dependencies: []),
    ]
)
