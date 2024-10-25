//
//  MetaCopy.swift
//  metacopy
//
//  Created by YourMJK on 23.10.24.
//

import Foundation
import CommandLineTool


struct MetaCopy {
	let inputFile: URL
	let outputFile: URL
	let copyDates: Bool
	let copyPermissions: Bool
	let copyExtendedAttributes: Bool
	let copyFlags: Bool
	let copyHFSCodes: Bool
	
	private let manager = FileManager.default
	private let resourceKeysToRead: Set<URLResourceKey>
	private let resourceKeysToComp: Set<URLResourceKey>
	private let resourceKeysToCopy: Set<URLResourceKey>
	private let attributeKeysToCopy: [FileAttributeKey]
	
	
	init(inputFile: URL, outputFile: URL, copyDates: Bool, copyPermissions: Bool, copyExtendedAttributes: Bool, copyFlags: Bool, copyHFSCodes: Bool) {
		self.inputFile = inputFile
		self.outputFile = outputFile
		self.copyDates = copyDates
		self.copyPermissions = copyPermissions
		self.copyExtendedAttributes = copyExtendedAttributes
		self.copyFlags = copyFlags
		self.copyHFSCodes = copyHFSCodes
		
		func addKeys<T>(to keys: inout Set<T>, if condition: Bool, _ newKeys: Set<T>) {
			if condition { keys.formUnion(newKeys) }
		}
		var attributeKeysToCopy: Set<FileAttributeKey> = []
		var resourceKeysToCopy: Set<URLResourceKey> = []
		let resourceKeysToComp: Set<URLResourceKey> = [
			.isRegularFileKey,
			.isDirectoryKey,
			.isAliasFileKey,
			.isSymbolicLinkKey,
			.mayHaveExtendedAttributesKey,
		]
		
		// Dates
		addKeys(to: &attributeKeysToCopy, if: copyDates, [
			.creationDate,
			.modificationDate,
		])
		// Permissions
		addKeys(to: &attributeKeysToCopy, if: copyPermissions, [
			.posixPermissions,
			.ownerAccountID,
			.ownerAccountName,
			.groupOwnerAccountID,
			.groupOwnerAccountName,
		])
		// Flags
		addKeys(to: &resourceKeysToCopy, if: copyFlags, [
			.isHiddenKey,
			.isUserImmutableKey,
		])
		// HFS codes
		addKeys(to: &attributeKeysToCopy, if: copyHFSCodes, [
			.hfsCreatorCode,
			.hfsTypeCode,
		])
		
		self.resourceKeysToRead = resourceKeysToComp.union(resourceKeysToCopy)
		self.resourceKeysToComp = resourceKeysToComp
		self.resourceKeysToCopy = resourceKeysToCopy
		self.attributeKeysToCopy = Array(attributeKeysToCopy)
	}
	
	
	func copyContents(verbose: Bool, skipErrors: Bool) throws {
		var enumeratorError: (url: URL, error: Error)?
		let errorHandler: ((URL, Error) -> Bool) = { url, error in
			enumeratorError = (url, error)
			// Don't continue enumeration
			return false
		}
		
		let enumerator = manager.enumerator(
			at: inputFile,
			includingPropertiesForKeys: Array(resourceKeysToRead),
			options: [.producesRelativePathURLs],
			errorHandler: errorHandler
		)
		guard let enumerator else {
			throw FileError.directoryEnumeration(url: outputFile)
		}
		
		// Enumerate contents of input directory recursively
		for case let url as URL in enumerator {
			let resourceValues = try url.resourceValues(forKeys: resourceKeysToRead)
			let relativePath = url.relativePath
			let sourceURL = inputFile.appending(path: relativePath)
			let mirrorURL = outputFile.appending(path: relativePath)
			
			do {
				try copyFile(sourceURL: sourceURL, mirrorURL: mirrorURL, sourceResourceValues: resourceValues)
				
				// Print relative path
				if verbose {
					stdout(relativePath)
				}
			}
			catch {
				if skipErrors {
					stderr("Skipping file:  \(error.localizedDescription)")
				}
				else {
					throw error
				}
			}
		}
		
		if let enumeratorError {
			throw FileError.directoryEnumerationAtURL(url: enumeratorError.url, error: enumeratorError.error)
		}
	}
	
	func copyFile() throws {
		let sourceResourceValues = try inputFile.resourceValues(forKeys: resourceKeysToRead)
		try copyFile(sourceURL: inputFile, mirrorURL: outputFile, sourceResourceValues: sourceResourceValues)
	}
	
	
	private func copyFile(sourceURL: URL, mirrorURL: URL, sourceResourceValues: URLResourceValues) throws {
		let sourcePath = sourceURL.path(percentEncoded: false)
		let mirrorPath = mirrorURL.path(percentEncoded: false)
		
		let isRegularFile = sourceResourceValues.isRegularFile!
		let isDirectory = sourceResourceValues.isDirectory!
		let isSymbolicLink = sourceResourceValues.isSymbolicLink!
		let isAliasFile = sourceResourceValues.isAliasFile!
		
		// Check for unsupported input file
		guard isRegularFile || isDirectory || isSymbolicLink || isAliasFile else {
			throw FileError.unsupportedFileType(url: sourceURL)
		}
		
		// Check whether mirror already exists and types match
		let mirrorExists = (try? mirrorURL.checkResourceIsReachable()) ?? false
		if mirrorExists {
			let mirrorResourceValues = try mirrorURL.resourceValues(forKeys: resourceKeysToComp)
			guard
				mirrorResourceValues.isRegularFile! == isRegularFile,
				mirrorResourceValues.isDirectory! == isDirectory,
				mirrorResourceValues.isSymbolicLink! == isSymbolicLink,
				mirrorResourceValues.isAliasFile! == isAliasFile
			else {
				throw FileError.existsWithDifferentType(url: mirrorURL)
			}
		}
		
		// Read attributes and resource values
		let sourceAttributes = try manager.attributesOfItem(atPath: sourcePath)
		var newMirrorAttributes: [FileAttributeKey: Any] = [:]
		for key in attributeKeysToCopy {
			newMirrorAttributes[key] = sourceAttributes[key]
		}
		let newMirrorResourceValues = try sourceURL.resourceValues(forKeys: resourceKeysToCopy)
		
		// Create mirror
		if isSymbolicLink || isAliasFile {
			// Link
			do {
				try manager.copyItem(at: sourceURL, to: mirrorURL)
				if !isSymbolicLink {
					// Is alias, copy attributes
					try manager.setAttributes(newMirrorAttributes, ofItemAtPath: mirrorPath)
				}
//				try manager.setAttributes(newMirrorAttributes, ofItemAtPath: mirrorPath)  // Tries to set attributes on resolved symlink path
			}
			catch CocoaError.fileWriteFileExists {
				// TODO: Check whether contents are equal
			}
			catch {
				throw FileError.linkCopying(url: mirrorURL, error: error)
			}
		}
		else if isDirectory {
			// Directory
			do {
				// Create directory
				try manager.createDirectory(at: mirrorURL, withIntermediateDirectories: false, attributes: newMirrorAttributes)
			}
			catch CocoaError.fileWriteFileExists {
				// Directory exists, copy attributes
				try manager.setAttributes(newMirrorAttributes, ofItemAtPath: mirrorPath)
			}
			catch {
				throw FileError.directoryCreation(url: mirrorURL, error: error)
			}
		}
		else if isRegularFile {
			// Regular file
			if !mirrorExists {
				// Create empty file
				let success = manager.createFile(atPath: mirrorPath, contents: nil, attributes: newMirrorAttributes)
				guard success else {
					throw FileError.fileCreation(url: mirrorURL)
				}
			}
			else {
				// File exists, copy attributes
				try manager.setAttributes(newMirrorAttributes, ofItemAtPath: mirrorPath)
			}
		}
		
		// Copy extended attributes
		if copyExtendedAttributes && sourceResourceValues.mayHaveExtendedAttributes! && !isSymbolicLink {
			do {
				for name in try ExtendedAttributes.list(url: sourceURL) {
					let data = try ExtendedAttributes.read(url: sourceURL, name: name)
					try ExtendedAttributes.write(url: mirrorURL, name: name, data: data)
				}
			}
			catch {
				throw FileError.extendedAttributesCopying(url: mirrorURL, error: error)
			}
		}
		
		// Copy resource values
		if copyFlags {
			do {
				var mirrorURL = mirrorURL
				try mirrorURL.setResourceValues(newMirrorResourceValues)
			}
			catch {
				throw FileError.flagsCopying(url: mirrorURL, error: error)
			}
		}
	}
	
}


extension MetaCopy {
	enum FileError: LocalizedError {
		case directoryEnumeration(url: URL)
		case directoryEnumerationAtURL(url: URL, error: Error)
		case unsupportedFileType(url: URL)
		case existsWithDifferentType(url: URL)
		case directoryCreation(url: URL, error: Error)
		case fileCreation(url: URL)
		case linkCopying(url: URL, error: Error)
		case extendedAttributesCopying(url: URL, error: Error)
		case flagsCopying(url: URL, error: Error)
		
		var errorDescription: String? {
			let (description, url, error): (String, URL?, Error?) = {
				switch self {
					case .directoryEnumeration(let url):
						return ("Couldn't enumerate directory at", url, nil)
					case .directoryEnumerationAtURL(let url, let error):
						return ("Enumeration failed at", url, error)
					case .unsupportedFileType(let url):
						return ("Unsupported file type of", url, nil)
					case .existsWithDifferentType(let url):
						return ("File \"\(url.relativePath)\" already exists but with different type", nil, nil)
					case .directoryCreation(let url, let error):
						return ("Couldn't create directory", url, error)
					case .fileCreation(let url):
						return ("Couldn't create file", url, nil)
					case .linkCopying(let url, let error):
						return ("Couldn't copy symlink or alias to", url, error)
					case .extendedAttributesCopying(let url, let error):
						return ("Couldn't copy extended attributes to", url, error)
					case .flagsCopying(let url, let error):
						return ("Couldn't copy flags to", url, error)
				}
			}()
			var message = description
			if let url {
				message.append(" \"\(url.relativePath)\"")
			}
			if let error {
				message.append(":  \(error.localizedDescription)")
			}
			return message
		}
	}
}
