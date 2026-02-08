//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("keepModelLoaded") private var keepModelLoaded = true
    @AppStorage("language") private var language = Defaults.language
    @AppStorage("whisperModel") private var whisperModel = WhisperModel.small.rawValue
    @AppStorage("openaiTranscriptionModel") private var openaiTranscriptionModel = OpenAITranscriptionModel.gpt4oTranscribe.rawValue

    @State private var toggleLocalHotkey: Hotkey
    @State private var toggleCloudHotkey: Hotkey
    @State private var toggleGeminiHotkey: Hotkey
    @State private var cancelHotkey: Hotkey
    @State private var openaiApiKey: String = ""
    @State private var geminiApiKey: String = ""
    @AppStorage("geminiModel") private var geminiModel = GeminiTranscriptionModel.flash2.rawValue
    @State private var showDeleteModelConfirmation = false
    @State private var showDeleteAllConfirmation = false

    @StateObject private var viewModel = GeneralSettingsViewModel()
    @Binding var isModelLoaded: Bool

    var onModelToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey, Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isModelLoaded: Binding<Bool>,
        onModelToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey, Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isModelLoaded = isModelLoaded
        self.onModelToggle = onModelToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
        _toggleLocalHotkey = State(initialValue: Settings.shared.loadToggleLocalHotkey())
        _toggleCloudHotkey = State(initialValue: Settings.shared.loadToggleCloudHotkey())
        _toggleGeminiHotkey = State(initialValue: Settings.shared.loadToggleGeminiHotkey())
        _cancelHotkey = State(initialValue: Settings.shared.loadCancelHotkey())
        _openaiApiKey = State(initialValue: Settings.shared.openaiApiKey)
        _geminiApiKey = State(initialValue: Settings.shared.geminiApiKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                keyboardShortcutsSection
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
                    viewModel.settings.saveToggleLocalHotkey(newValue)
                    onHotkeysChanged?(newValue, toggleCloudHotkey, toggleGeminiHotkey, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: "Cloud Recording (OpenAI)",
                    description: "Record with OpenAI cloud API",
                    hotkey: $toggleCloudHotkey
                )
                .onChange(of: toggleCloudHotkey) { _, newValue in
                    viewModel.settings.saveToggleCloudHotkey(newValue)
                    onHotkeysChanged?(toggleLocalHotkey, newValue, toggleGeminiHotkey, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: "Gemini Recording",
                    description: "Record with Google Gemini API",
                    hotkey: $toggleGeminiHotkey
                )
                .onChange(of: toggleGeminiHotkey) { _, newValue in
                    viewModel.settings.saveToggleGeminiHotkey(newValue)
                    onHotkeysChanged?(toggleLocalHotkey, toggleCloudHotkey, newValue, cancelHotkey)
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
                    viewModel.settings.saveCancelHotkey(newValue)
                    onHotkeysChanged?(toggleLocalHotkey, toggleCloudHotkey, toggleGeminiHotkey, newValue)
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

            // Cloud Gemini settings
            geminiSettingsSection
        }
    }

    private var localSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Local (Whisper)")

            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                modelPicker
                modelDownloadStatus
                modelToggle
                modelManagement
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var modelToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                HStack(spacing: Layout.Spacing.indicator) {
                    Text("Keep model in memory")
                        .font(Typography.label)
                        .foregroundColor(.white)

                    Circle()
                        .fill(isModelLoaded ? Color.green : Color.gray.opacity(AppColors.disabledOpacity))
                        .frame(width: 8, height: 8)

                    Text(isModelLoaded ? "Loaded" : "Not loaded")
                        .font(Typography.caption)
                        .foregroundColor(isModelLoaded ? .green : .gray)
                }
                Text("Faster transcription, uses ~500MB RAM")
                    .font(Typography.description)
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: $keepModelLoaded)
                .toggleStyle(.switch)
                .labelsHidden()
                .transaction { $0.animation = nil }
                .onChange(of: keepModelLoaded) { _, newValue in
                    onModelToggle?(newValue)
                }
        }
    }

    @ViewBuilder
    private var modelManagement: some View {
        if !viewModel.installedModels.isEmpty {
            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                Button {
                    showDeleteAllConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Delete all models")
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .alert("Delete all models?", isPresented: $showDeleteAllConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete all", role: .destructive) {
                        Task { await viewModel.deleteAllModels() }
                    }
                } message: {
                    Text("All \(viewModel.installedModels.count) downloaded models will be removed from disk and unloaded from memory.")
                }

                Text("Removes all downloaded models from disk and unloads from memory")
                    .font(Typography.description)
                    .foregroundColor(.gray)
            }
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
            .padding(.bottom, Layout.Padding.section)
        }
    }

    private var geminiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Cloud (Gemini)")

            VStack(alignment: .leading, spacing: Layout.Spacing.item) {
                geminiModelPicker
                geminiApiKeyField
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
        }
    }

    private var geminiModelPicker: some View {
        HStack {
            Text("Model")
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $geminiModel) {
                ForEach(GeminiTranscriptionModel.allCases, id: \.rawValue) { model in
                    Text(model.displayName).tag(model.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 240)
            .transaction { $0.animation = nil }
        }
    }

    private var geminiApiKeyField: some View {
        ApiKeyField(
            placeholder: "AI...",
            apiKey: $geminiApiKey,
            isTesting: viewModel.isTestingGemini,
            testResult: viewModel.geminiTestResult,
            onKeyChanged: { newValue in
                viewModel.settings.geminiApiKey = newValue
                viewModel.clearTestResult(for: .gemini)
            },
            onTest: {
                Task {
                    await viewModel.testGemini(apiKey: geminiApiKey)
                }
            }
        )
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
        ApiKeyField(
            placeholder: "sk-...",
            apiKey: $openaiApiKey,
            isTesting: viewModel.isTestingOpenAI,
            testResult: viewModel.openaiTestResult,
            onKeyChanged: { newValue in
                viewModel.settings.openaiApiKey = newValue
                viewModel.clearTestResult(for: .openAI)
            },
            onTest: {
                Task {
                    await viewModel.testOpenAI(apiKey: openaiApiKey)
                }
            }
        )
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
        VStack(alignment: .leading, spacing: Layout.Spacing.item) {
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
                .transaction { $0.animation = nil }
                .onChange(of: whisperModel) { _, newValue in
                    viewModel.handleModelChange(newValue)
                }
            }

            if viewModel.isModelInstalled(whisperModel) {
                HStack(spacing: Layout.Spacing.item) {
                    Button {
                        Task { await viewModel.testLocalModel() }
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isTestingLocal {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.isTestingLocal ? "Testing..." : "Test model")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isTestingLocal)

                    Button {
                        showDeleteModelConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete model")
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .alert("Delete model?", isPresented: $showDeleteModelConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteModel(whisperModel) }
                        }
                    } message: {
                        Text("Model \"\(whisperModel)\" will be removed from disk and unloaded from memory.")
                    }
                }

                if let result = viewModel.localTestResult {
                    TestResultBadge(result: result, successText: "Model works correctly")
                }
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

                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Downloading model... \(Int(progress * 100))%")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Cancel") {
                                viewModel.cancelDownload()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }

                case .compiling:
                    HStack(spacing: Layout.Spacing.item) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Compiling model for Neural Engine...")
                            .foregroundColor(.secondary)
                    }

                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Model ready!")
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
