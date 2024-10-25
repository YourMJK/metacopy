//
//  ExtendedAttributes.swift
//  metacopy
//
//  Created by YourMJK on 25.10.24.
//

import Foundation


enum ExtendedAttributes {
	
	static func list(url: URL) throws -> [String] {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
			let length = listxattr(fileSystemPath, nil, 0, 0)
			guard length >= 0 else { throw POSIXError.error(errno) }
			
			// Create buffer with required size
			var namebuf = Array<CChar>(repeating: 0, count: length)
			
			// Retrieve attribute list
			let result = listxattr(fileSystemPath, &namebuf, namebuf.count, 0)
			guard result >= 0 else { throw POSIXError.error(errno) }
			
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
	
	static func read(url: URL, name: String) throws -> Data {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
			// Determine attribute size
			let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
			guard length >= 0 else { throw POSIXError.error(errno) }
			
			// Create buffer with required size
			var data = Data(count: length)
			
			// Retrieve attribute
			let result = data.withUnsafeMutableBytes { [count = data.count] in
				getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
			}
			guard result >= 0 else { throw POSIXError.error(errno) }
			return data
		}
	}
	
	static func write(url: URL, name: String, data: Data) throws {
		try url.withUnsafeFileSystemRepresentation { fileSystemPath in
			let result = data.withUnsafeBytes {
				setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
			}
			guard result >= 0 else { throw POSIXError.error(errno) }
		}
	}
	
}
