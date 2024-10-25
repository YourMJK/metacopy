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
	
	@Argument(help: ArgumentHelp("The path to the input file or directory.", valueName: "input file"))
	var inputFilePath: String
	
	@Argument(help: ArgumentHelp("The path to the output file or directory.", valueName: "output file"))
	var outputFilePath: String
	
	@Flag(name: .short, help: ArgumentHelp("Recursively copy contents of directory. Input and output need to be directories."))
	var recursive: Bool = false
	
	@Flag(name: .short, help: ArgumentHelp("Skip files when encountering errors instead of canceling. Recursive mode only."))
	var ignoreErrors: Bool = false
	
	@Flag(name: .short, help: ArgumentHelp("Print relative paths of the files while they are copied. Recursive mode only."))
	var verbose: Bool = false
	
	func run() throws {
		let inputFileURL = URL(fileURLWithPath: inputFilePath)
		let outputFileURL = URL(fileURLWithPath: outputFilePath)
		
		let metaCopy = MetaCopy(inputFile: inputFileURL, outputFile: outputFileURL)
		
		// Check whether input file exists
		var inputIsDirectory = false
		guard Self.fileExists(url: inputFileURL, isDirectory: &inputIsDirectory) else {
			throw ArgumentsError.noSuchInputFile(url: inputFileURL)
		}
		
		if recursive {
			// Check whether input is directory
			guard inputIsDirectory else {
				throw ArgumentsError.noSuchInputDirectory(url: inputFileURL)
			}
			// Check whether output directory exists
			var outputIsDirectory = false
			guard Self.fileExists(url: outputFileURL, isDirectory: &outputIsDirectory), outputIsDirectory else {
				throw ArgumentsError.noSuchOutputDirectory(url: outputFileURL)
			}
			
			try metaCopy.copyContents(verbose: verbose, skipErrors: ignoreErrors)
		}
		else {
			try metaCopy.copyFile()
		}
	}
}


extension Command {
	static func fileExists(url: URL, isDirectory: inout Bool) -> Bool {
		var isDirectoryObjCBool: ObjCBool = false
		let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectoryObjCBool)
		isDirectory = isDirectoryObjCBool.boolValue
		return exists
	}
}


extension Command {
	enum ArgumentsError: LocalizedError {
		case noSuchInputFile(url: URL)
		case noSuchInputDirectory(url: URL)
		case noSuchOutputDirectory(url: URL)
		
		private static let recursiveModeNeedsDirectoriesMessage = "Input and output need to be directories in recursive mode"
		
		var errorDescription: String? {
			switch self {
				case .noSuchInputFile(let url):
					return "No such input file \"\(url.relativePath)\""
				case .noSuchInputDirectory(let url):
					return "No such input directory \"\(url.relativePath)\". \(Self.recursiveModeNeedsDirectoriesMessage)"
				case .noSuchOutputDirectory(let url):
					return "No such output directory \"\(url.relativePath)\". \(Self.recursiveModeNeedsDirectoriesMessage)"
			}
		}
	}
}
