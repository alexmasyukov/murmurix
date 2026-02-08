//
//  ApiKeyField.swift
//  Murmurix
//

import SwiftUI

struct ApiKeyField: View {
    let placeholder: String
    @Binding var apiKey: String
    let isTesting: Bool
    let testResult: APITestResult?
    let onKeyChanged: (String) -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
            Text("API Key")
                .font(Typography.label)
                .foregroundColor(.white)

            HStack(spacing: Layout.Spacing.item) {
                TextField(placeholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .onChange(of: apiKey) { _, newValue in
                        onKeyChanged(newValue)
                    }

                Button {
                    onTest()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(apiKey.isEmpty || isTesting)
            }

            if let result = testResult {
                TestResultBadge(result: result)
            }
        }
    }
}
