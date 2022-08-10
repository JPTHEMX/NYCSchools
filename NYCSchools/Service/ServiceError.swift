//
//  ServiceError.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

enum ServiceError: Error {
    case jsonParse
    case requestFail
    case components
    case urlCreation
    case urlResponseData
}

extension ServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .jsonParse:
            return "JSON parse data"
        case .requestFail:
            return "Request failed"
        case .components:
            return "Cannot create URLComponents"
        case .urlCreation:
            return "Cannot create URL"
        case .urlResponseData:
            return "Did not receive data"
        }
    }
}
