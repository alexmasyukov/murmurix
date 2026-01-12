//
//  APITestResult.swift
//  Murmurix
//

import Foundation

/// Result of an API connection test
enum APITestResult: Equatable {
    case success
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}
