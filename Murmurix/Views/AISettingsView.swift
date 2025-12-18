//
//  AISettingsView.swift
//  Murmurix
//

import SwiftUI

struct AISettingsView: View {
    @AppStorage("aiPostProcessingEnabled") private var aiEnabled = false
    @AppStorage("aiModel") private var aiModel = AIModel.haiku.rawValue

    @StateObject private var viewModel = AISettingsViewModel()

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
            viewModel.loadSettings()
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
                TextField("sk-ant-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onChange(of: viewModel.apiKey) { _, newValue in
                        viewModel.saveAPIKey(newValue)
                    }

                Button(action: { viewModel.testConnection() }) {
                    if viewModel.isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.apiKey.isEmpty || viewModel.isTesting)
            }

            if let result = viewModel.testResult {
                testResultView(result)
            }
        }
    }

    @ViewBuilder
    private func testResultView(_ result: APITestResult) -> some View {
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
                TextEditor(text: $viewModel.prompt)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                    .frame(height: 150)
                    .onChange(of: viewModel.prompt) { _, newValue in
                        viewModel.savePrompt(newValue)
                    }

                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        viewModel.resetPromptToDefault()
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
}
