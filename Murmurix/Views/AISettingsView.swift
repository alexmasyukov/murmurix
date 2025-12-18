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
                VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                    Text("Enable AI post-processing")
                        .font(Typography.label)
                        .foregroundColor(.white)
                    Text("Fix technical terms using Claude")
                        .font(Typography.description)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $aiEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Claude API")

            VStack(alignment: .leading, spacing: Layout.Spacing.section) {
                apiKeyField
                modelPicker
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Spacing.section)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
            .opacity(aiEnabled ? 1 : AppColors.disabledOpacity)
            .disabled(!aiEnabled)
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Key")
                .font(Typography.monospaced)
                .foregroundColor(.secondary)

            HStack(spacing: Layout.Spacing.item) {
                TextField("sk-ant-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(Typography.monospaced)
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
        .font(Typography.description)
    }

    private var modelPicker: some View {
        HStack {
            Text("Model")
                .font(Typography.label)
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

            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                TextEditor(text: $viewModel.prompt)
                    .font(Typography.monospaced)
                    .scrollContentBackground(.hidden)
                    .padding(Layout.Spacing.item)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(Layout.CornerRadius.button)
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
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Spacing.section)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .opacity(aiEnabled ? 1 : AppColors.disabledOpacity)
            .disabled(!aiEnabled)
        }
    }
}
