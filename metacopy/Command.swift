//
//  Command.swift
//  metacopy
//
//  Created by YourMJK on 23.10.24.
//

import Foundation
import CommandLineTool
import ArgumentParser

@main
struct Command: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: executableName,
		helpMessageLabelColumnWidth: 20
	)
	
	@Argument(help: ArgumentHelp("The path to the input directory.", valueName: "input directory"))
	var inputDirectoryPath: String
	
	@Argument(help: ArgumentHelp("The path to the output directory.", valueName: "output directory"))
	var outputDirectoryPath: String
	
	@Flag(name: .short, help: ArgumentHelp("Skip files when encountering errors instead of canceling."))
	var ignoreErrors: Bool = false
	
	@Flag(name: .short, help: ArgumentHelp("Print relative paths of the files while they are copied."))
	var verbose: Bool = false
	
	func run() throws {
		let inputDirectoryURL = URL(fileURLWithPath: inputDirectoryPath, isDirectory: true)
		let outputDirectoryURL = URL(fileURLWithPath: outputDirectoryPath, isDirectory: true)
		
		if !FileManager.default.fileExists(atPath: outputDirectoryPath) {
			throw ArgumentsError.noSuchOutputDirectory(path: outputDirectoryPath)
		}
		
		let metaCopy = MetaCopy(
			inputDir: inputDirectoryURL,
			outputDir: outputDirectoryURL,
			verbose: verbose,
			skipErrors: ignoreErrors
		)
		try metaCopy.copyContents()
	}
}


extension Command {
	enum ArgumentsError: LocalizedError {
		case noSuchOutputDirectory(path: String)
		
		var errorDescription: String? {
			switch self {
				case .noSuchOutputDirectory(let path):
					return "No such output directory \"\(path)\""
			}
		}
	}
}
