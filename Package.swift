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
		.package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.1.0"),
		.package(url: "https://github.com/cxa/MenuItemKit.git", from: "3.0.0"),
		.package(url: "https://github.com/zoonooz/ZFDragableModalTransition.git", from: "0.6.0"),
		.package(url: "https://github.com/tadija/AEXML.git", from: "4.2.0"),
		.package(url: "https://github.com/ArtSabintsev/FontBlaster.git", from: "4.0.0"),
		.package(url: "https://github.com/fantim/JSQWebViewController.git", from: "6.1.0"),
		.package(url: "https://github.com/realm/realm-cocoa.git", from: "3.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        // "ZipArchive", "MenuItemKit", "ZFDragableModalTransition", AEXML", "FontBlaster", "JSQWebViewController", "Realm"
        .target(
            name: "FolioReaderKit",
            dependencies: ["AEXML"],
            path: "Source"),
    ]
)
