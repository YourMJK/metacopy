// swift-tools-version: 5.7

import PackageDescription

let package = Package(
	name: "metacopy",
	platforms: [.macOS(.v13)],
	products: [
		.executable(name: "metacopy", targets: ["metacopy"]),
	],
	dependencies: [
		.package(url: "https://github.com/YourMJK/CommandLineTool", from: "1.1.0"),
	],
	targets: [
		.executableTarget(
			name: "metacopy",
			dependencies: [
				"CommandLineTool",
			],
			path: "metacopy"
		)
	]
)
