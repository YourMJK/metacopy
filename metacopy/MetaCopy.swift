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
	let copyHFSCodes: Bool
	
	private let manager = FileManager.default
	private let resourceKeys: Set<URLResourceKey> = [
		.isRegularFileKey,
		.isDirectoryKey,
		.isAliasFileKey,
		.isSymbolicLinkKey,
		.mayHaveExtendedAttributesKey,
	]
	private let attributeKeysToCopy: [FileAttributeKey]
	
	
	init(inputFile: URL, outputFile: URL, copyDates: Bool, copyPermissions: Bool, copyExtendedAttributes: Bool, copyHFSCodes: Bool) {
		self.inputFile = inputFile
		self.outputFile = outputFile
		self.copyDates = copyDates
		self.copyPermissions = copyPermissions
		self.copyExtendedAttributes = copyExtendedAttributes
		self.copyHFSCodes = copyHFSCodes
		
		var attributeKeysToCopy = [FileAttributeKey]()
		func addKeys(if condition: Bool, _ newKeys: [FileAttributeKey]) {
			if condition { attributeKeysToCopy.append(contentsOf: newKeys) }
		}
		addKeys(if: copyDates, [
			.creationDate,
			.modificationDate,
		])
		addKeys(if: copyPermissions, [
			.posixPermissions,
			.ownerAccountID,
			.ownerAccountName,
			.groupOwnerAccountID,
			.groupOwnerAccountName,
		])
		addKeys(if: copyHFSCodes, [
			.hfsCreatorCode,
			.hfsTypeCode
		])
		self.attributeKeysToCopy = attributeKeysToCopy
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
			includingPropertiesForKeys: Array(resourceKeys),
			options: [.producesRelativePathURLs],
			errorHandler: errorHandler
		)
		guard let enumerator else {
			throw FileError.directoryEnumeration(url: outputFile)
		}
		
		// Enumerate contents of input directory recursively
		for case let url as URL in enumerator {
			let resourceValues = try url.resourceValues(forKeys: resourceKeys)
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
		let sourceResourceValues = try inputFile.resourceValues(forKeys: resourceKeys)
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
			let mirrorResourceValues = try mirrorURL.resourceValues(forKeys: resourceKeys)
			guard
				mirrorResourceValues.isRegularFile! == isRegularFile,
				mirrorResourceValues.isDirectory! == isDirectory,
				mirrorResourceValues.isSymbolicLink! == isSymbolicLink,
				mirrorResourceValues.isAliasFile! == isAliasFile
			else {
				throw FileError.existsWithDifferentType(url: mirrorURL)
			}
		}
		
		// Read attributes
		let attributes = try manager.attributesOfItem(atPath: sourcePath)
		var mirrorAttributes: [FileAttributeKey: Any] = [:]
		for key in attributeKeysToCopy {
			mirrorAttributes[key] = attributes[key]
		}
		
		// Create mirror
		if isSymbolicLink || isAliasFile {
			// Link
			do {
				try manager.copyItem(at: sourceURL, to: mirrorURL)
//				try manager.setAttributes(mirrorAttributes, ofItemAtPath: mirrorPath)
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
				try manager.createDirectory(at: mirrorURL, withIntermediateDirectories: false, attributes: mirrorAttributes)
			}
			catch CocoaError.fileWriteFileExists {
				// Directory exists, copy attributes
				try manager.setAttributes(mirrorAttributes, ofItemAtPath: mirrorPath)
			}
			catch {
				throw FileError.directoryCreation(url: mirrorURL, error: error)
			}
		}
		else if isRegularFile {
			// Regular file
			if !mirrorExists {
				// Create empty file
				let success = manager.createFile(atPath: mirrorPath, contents: nil, attributes: mirrorAttributes)
				guard success else {
					throw FileError.fileCreation(url: mirrorURL)
				}
			}
			else {
				// File exists, copy attributes
				try manager.setAttributes(mirrorAttributes, ofItemAtPath: mirrorPath)
			}
		}
		
		// Copy extended attributes
		if copyExtendedAttributes && sourceResourceValues.mayHaveExtendedAttributes! && !isSymbolicLink {
			do {
				for name in try Self.listExtendedAttributes(url: sourceURL) {
					let data = try Self.readExtendedAttribute(url: sourceURL, name: name)
					try Self.writeExtendedAttribute(url: mirrorURL, name: name, data: data)
				}
			}
			catch {
				throw FileError.extendedAttributesCopying(url: mirrorURL, error: error)
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
		
		static func posixError(_ err: Int32) -> NSError {
			NSError(
				domain: NSPOSIXErrorDomain,
				code: Int(err),
				userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))]
			)
		}
		
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


// MARK: - Extended Attributes

extension MetaCopy {
	
	private static func listExtendedAttributes(url: URL) throws -> [String] {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
			let length = listxattr(fileSystemPath, nil, 0, 0)
			guard length >= 0 else { throw FileError.posixError(errno) }
			
			// Create buffer with required size
			var namebuf = Array<CChar>(repeating: 0, count: length)
			
			// Retrieve attribute list
			let result = listxattr(fileSystemPath, &namebuf, namebuf.count, 0)
			guard result >= 0 else { throw FileError.posixError(errno) }
			
			// Extract attribute names
			let list = namebuf.split(separator: 0).compactMap {
				$0.withUnsafeBufferPointer {
					$0.withMemoryRebound(to: UInt8.self) {
						String(bytes: $0, encoding: .utf8)
					}
				}
			}
			return list
		}
	}
	
	private static func readExtendedAttribute(url: URL, name: String) throws -> Data {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
			// Determine attribute size
			let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
			guard length >= 0 else { throw FileError.posixError(errno) }
			
			// Create buffer with required size
			var data = Data(count: length)
			
			// Retrieve attribute
			let result = data.withUnsafeMutableBytes { [count = data.count] in
				getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
			}
			guard result >= 0 else { throw FileError.posixError(errno) }
			return data
		}
	}
	
	private static func writeExtendedAttribute(url: URL, name: String, data: Data) throws {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath in
			let result = data.withUnsafeBytes {
				setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
			}
			guard result >= 0 else { throw FileError.posixError(errno) }
		}
	}
	
}
