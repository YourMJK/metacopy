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
	
	static func relativePath(of dest: URL, toDirectory base: URL) -> String {
		let destComponents = dest.standardizedFileURL.pathComponents
		let baseComponents = base.standardizedFileURL.pathComponents
		var index = 0
		while index < destComponents.count && index < baseComponents.count && destComponents[index] == baseComponents[index] {
			index += 1
		}
		var relComponents = Array(repeating: "..", count: baseComponents.count - index)
		relComponents.append(contentsOf: destComponents[index...])
		return relComponents.joined(separator: "/")
	}
}
