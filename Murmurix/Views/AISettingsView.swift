//
//  AISettingsView.swift
//  Murmurix
//

import SwiftUI

struct AISettingsView: View {
    @AppStorage("aiPostProcessingEnabled") private var aiEnabled = false
    @AppStorage("aiModel") private var aiModel = AIModel.haiku.rawValue

    @State private var apiKey: String = ""
    @State private var prompt: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                postProcessingToggle
                apiKeySection
                promptSection
                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear {
            apiKey = Settings.shared.claudeApiKey
            prompt = Settings.shared.aiPrompt
        }
        .onChange(of: apiKey) { _, newValue in
            Settings.shared.claudeApiKey = newValue
            testResult = nil
        }
        .onChange(of: prompt) { _, newValue in
            Settings.shared.aiPrompt = newValue
        }
    }

    // MARK: - Sections

    private var postProcessingToggle: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Post-Processing")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable AI post-processing")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    Text("Fix technical terms using Claude")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $aiEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Claude API")

            VStack(alignment: .leading, spacing: 12) {
                apiKeyField
                modelPicker
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .opacity(aiEnabled ? 1 : 0.5)
            .disabled(!aiEnabled)
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Key")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))

                Button(action: testConnection) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(apiKey.isEmpty || isTesting)
            }

            if let result = testResult {
                testResultView(result)
            }
        }
    }

    @ViewBuilder
    private func testResultView(_ result: TestResult) -> some View {
        HStack(spacing: 4) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connection successful")
                    .foregroundColor(.green)
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 11))
    }

    private var modelPicker: some View {
        HStack {
            Text("Model")
                .font(.system(size: 13))
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $aiModel) {
                ForEach(AIModel.allCases, id: \.rawValue) { model in
                    Text(model.displayName).tag(model.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 140)
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Prompt")

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $prompt)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                    .frame(height: 150)

                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        prompt = Settings.defaultAIPrompt
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .opacity(aiEnabled ? 1 : 0.5)
            .disabled(!aiEnabled)
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let result = try await AnthropicAPIClient.shared.validateAPIKey(apiKey)
                await MainActor.run {
                    isTesting = false
                    testResult = result ? .success : .failure("Invalid response")
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }
}
