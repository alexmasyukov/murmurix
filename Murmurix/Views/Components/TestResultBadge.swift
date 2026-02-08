//
//  TestResultBadge.swift
//  Murmurix
//

import SwiftUI

struct TestResultBadge: View {
    let result: APITestResult
    var successText = "Connection successful"

    var body: some View {
        HStack(spacing: 4) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(successText)
                    .foregroundColor(.green)
            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
            }
        }
        .font(Typography.description)
    }
}
