//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

enum APITestResult {
    case success
    case failure(String)
}

struct GeneralSettingsView: View {
    @AppStorage("keepDaemonRunning") private var keepDaemonRunning = true
    @AppStorage("language") private var language = "ru"
    @AppStorage("whisperModel") private var whisperModel = WhisperModel.small.rawValue
    @AppStorage("openaiTranscriptionModel") private var openaiTranscriptionModel = OpenAITranscriptionModel.gpt4oTranscribe.rawValue

    @State private var toggleLocalHotkey: Hotkey
    @State private var toggleCloudHotkey: Hotkey
    @State private var cancelHotkey: Hotkey
    @State private var openaiApiKey: String = ""
    @State private var isTestingOpenAI = false
    @State private var openaiTestResult: APITestResult?

    @StateObject private var viewModel = GeneralSettingsViewModel()
    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
        _toggleLocalHotkey = State(initialValue: Settings.shared.loadToggleLocalHotkey())
        _toggleCloudHotkey = State(initialValue: Settings.shared.loadToggleCloudHotkey())
        _cancelHotkey = State(initialValue: Settings.shared.loadCancelHotkey())
        _openaiApiKey = State(initialValue: Settings.shared.openaiApiKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                keyboardShortcutsSection
                performanceSection
                recognitionSection
                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear {
            viewModel.onModelChanged = onModelChanged
            viewModel.loadInstalledModels()
        }
        .transaction { $0.animation = nil }
    }

    // MARK: - Sections

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Keyboard Shortcuts")

            VStack(spacing: 0) {
                HotkeyRecorderView(
                    title: "Local Recording",
                    description: "Record with local Whisper model",
                    hotkey: $toggleLocalHotkey
                )
                .onChange(of: toggleLocalHotkey) { _, newValue in
                    Settings.shared.saveToggleLocalHotkey(newValue)
                    onHotkeysChanged?(newValue, toggleCloudHotkey, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: "Cloud Recording",
                    description: "Record with OpenAI cloud API",
                    hotkey: $toggleCloudHotkey
                )
                .onChange(of: toggleCloudHotkey) { _, newValue in
                    Settings.shared.saveToggleCloudHotkey(newValue)
                    onHotkeysChanged?(toggleLocalHotkey, newValue, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: "Cancel Recording",
                    description: "Discards the active recording",
                    hotkey: $cancelHotkey
                )
                .onChange(of: cancelHotkey) { _, newValue in
                    Settings.shared.saveCancelHotkey(newValue)
                    onHotkeysChanged?(toggleLocalHotkey, toggleCloudHotkey, newValue)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)
            }
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Performance")

            HStack {
                VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                    HStack(spacing: Layout.Spacing.indicator) {
                        Text("Keep model in memory")
                            .font(Typography.label)
                            .foregroundColor(.white)

                        Circle()
                            .fill(isDaemonRunning ? Color.green : Color.gray.opacity(AppColors.disabledOpacity))
                            .frame(width: 8, height: 8)

                        Text(isDaemonRunning ? "Running" : "Stopped")
                            .font(Typography.caption)
                            .foregroundColor(isDaemonRunning ? .green : .gray)
                    }
                    Text("Faster transcription, uses ~500MB RAM")
                        .font(Typography.description)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $keepDaemonRunning)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .transaction { $0.animation = nil }
                    .onChange(of: keepDaemonRunning) { _, newValue in
                        onDaemonToggle?(newValue)
                    }
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Recognition")

            VStack(alignment: .leading, spacing: Layout.Spacing.section) {
                languagePicker
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)

            // Local Whisper settings
            localSettingsSection

            // Cloud OpenAI settings
            cloudSettingsSection
        }
    }

    private var localSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Local (Whisper)")

            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                modelPicker
                modelDownloadStatus
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var cloudSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Cloud (OpenAI)")

            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                openaiModelPicker
                openaiApiKeyField
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
        }
    }

    private var openaiModelPicker: some View {
        HStack {
            Text("Model")
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $openaiTranscriptionModel) {
                ForEach(OpenAITranscriptionModel.allCases, id: \.rawValue) { model in
                    Text(model.displayName).tag(model.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 200)
            .transaction { $0.animation = nil }
        }
    }

    private var openaiApiKeyField: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
            Text("API Key")
                .font(Typography.label)
                .foregroundColor(.white)

            HStack(spacing: Layout.Spacing.item) {
                TextField("sk-...", text: $openaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .onChange(of: openaiApiKey) { _, newValue in
                        Settings.shared.openaiApiKey = newValue
                        openaiTestResult = nil
                    }

                Button(action: testOpenAIConnection) {
                    if isTestingOpenAI {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(openaiApiKey.isEmpty || isTestingOpenAI)
            }

            // Test result
            if let result = openaiTestResult {
                HStack(spacing: 4) {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connection successful")
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
    }

    private func testOpenAIConnection() {
        isTestingOpenAI = true
        openaiTestResult = nil

        Task {
            do {
                let isValid = try await OpenAITranscriptionService.shared.validateAPIKey(openaiApiKey)
                await MainActor.run {
                    openaiTestResult = isValid ? .success : .failure("Invalid API key")
                    isTestingOpenAI = false
                }
            } catch {
                await MainActor.run {
                    openaiTestResult = .failure(error.localizedDescription)
                    isTestingOpenAI = false
                }
            }
        }
    }

    private var languagePicker: some View {
        HStack {
            Text("Language")
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $language) {
                Text("Russian").tag("ru")
                Text("English").tag("en")
                Text("Auto-detect").tag("auto")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
            .transaction { $0.animation = nil }
        }
    }

    private var modelPicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                Text("Model")
                    .font(Typography.label)
                    .foregroundColor(.white)
                Text("Larger models are more accurate but slower")
                    .font(Typography.description)
                    .foregroundColor(.gray)
            }

            Spacer()

            Picker("", selection: $whisperModel) {
                ForEach(WhisperModel.allCases, id: \.rawValue) { model in
                    HStack {
                        Text(model.displayName)
                        if !viewModel.isModelInstalled(model.rawValue) {
                            Text("(not installed)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(model.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 220)
            .transaction { $0.animation = nil }
            .onChange(of: whisperModel) { _, newValue in
                viewModel.handleModelChange(newValue)
            }
        }
    }

    @ViewBuilder
    private var modelDownloadStatus: some View {
        if !viewModel.isModelInstalled(whisperModel) {
            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                switch viewModel.downloadStatus {
                case .idle:
                    HStack(spacing: Layout.Spacing.item) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Model not installed")
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Download") {
                            viewModel.startDownload(for: whisperModel)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                case .downloading:
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Downloading model...")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Cancel") {
                                viewModel.cancelDownload()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        ProgressView()
                            .progressViewStyle(.linear)
                    }

                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Download completed!")
                            .foregroundColor(.green)
                    }

                case .error(let message):
                    HStack(spacing: Layout.Spacing.item) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .foregroundColor(.red)
                            .lineLimit(2)
                        Spacer()
                        Button("Retry") {
                            viewModel.startDownload(for: whisperModel)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .font(Typography.description)
        }
    }
}
