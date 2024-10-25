//
//  POSIXError.swift
//  metacopy
//
//  Created by YourMJK on 25.10.24.
//

import Foundation

extension POSIXError {
	static func error(_ code: Int32) -> Self {
		let userInfo = [NSLocalizedDescriptionKey: String(cString: strerror(code))]
		return Self(POSIXErrorCode(rawValue: code)!, userInfo: userInfo)
//		NSError(
//			domain: NSPOSIXErrorDomain,
//			code: Int(code),
//			userInfo: userInfo
//		)
	}
}
