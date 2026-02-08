//
//  TestResultBadge.swift
//  Murmurix
//

import SwiftUI

struct TestResultBadge: View {
    let result: APITestResult
    var successText: String? = nil
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        HStack(spacing: 4) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(successText ?? L10n.connectionSuccessful)
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
