//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("language") private var language = Defaults.language
    @AppStorage("openaiTranscriptionModel") private var openaiTranscriptionModel = OpenAITranscriptionModel.gpt4oTranscribe.rawValue
    @AppStorage("appLanguage") private var appLanguage = "en"

    @State private var toggleCloudHotkey: Hotkey
    @State private var toggleGeminiHotkey: Hotkey
    @State private var cancelHotkey: Hotkey
    @State private var openaiApiKey: String = ""
    @State private var geminiApiKey: String = ""
    @AppStorage("geminiModel") private var geminiModel = GeminiTranscriptionModel.flash2.rawValue
    @State private var showDeleteAllConfirmation = false

    @StateObject private var viewModel = GeneralSettingsViewModel()
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)?

    init(
        loadedModels: Binding<Set<String>>,
        onModelToggle: ((String, Bool) -> Void)? = nil,
        onLocalHotkeysChanged: (([String: Hotkey]) -> Void)? = nil,
        onCloudHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)? = nil
    ) {
        self._loadedModels = loadedModels
        self.onModelToggle = onModelToggle
        self.onLocalHotkeysChanged = onLocalHotkeysChanged
        self.onCloudHotkeysChanged = onCloudHotkeysChanged
        _toggleCloudHotkey = State(initialValue: Settings.shared.loadToggleCloudHotkey())
        _toggleGeminiHotkey = State(initialValue: Settings.shared.loadToggleGeminiHotkey())
        _cancelHotkey = State(initialValue: Settings.shared.loadCancelHotkey())
        _openaiApiKey = State(initialValue: Settings.shared.openaiApiKey)
        _geminiApiKey = State(initialValue: Settings.shared.geminiApiKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                appLanguageSection
                keyboardShortcutsSection
                recognitionSection
                localModelsSection
                modelManagementSection
                cloudSettingsSection
                geminiSettingsSection
                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear {
            viewModel.onLocalHotkeysChanged = onLocalHotkeysChanged
            viewModel.loadInstalledModels()
        }
        .transaction { $0.animation = nil }
    }

    // MARK: - App Language

    private var appLanguageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.appLanguage)

            HStack {
                Spacer()

                Picker("", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
                .transaction { $0.animation = nil }
                .onChange(of: appLanguage) { _, _ in
                    NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
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

    // MARK: - Keyboard Shortcuts (Cloud + Cancel only)

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.keyboardShortcuts)

            VStack(spacing: 0) {
                HotkeyRecorderView(
                    title: L10n.cloudRecordingOpenAI,
                    description: L10n.recordWithOpenAI,
                    hotkey: $toggleCloudHotkey
                )
                .onChange(of: toggleCloudHotkey) { _, newValue in
                    viewModel.settings.saveToggleCloudHotkey(newValue)
                    onCloudHotkeysChanged?(newValue, toggleGeminiHotkey, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: L10n.geminiRecording,
                    description: L10n.recordWithGemini,
                    hotkey: $toggleGeminiHotkey
                )
                .onChange(of: toggleGeminiHotkey) { _, newValue in
                    viewModel.settings.saveToggleGeminiHotkey(newValue)
                    onCloudHotkeysChanged?(toggleCloudHotkey, newValue, cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: L10n.cancelRecording,
                    description: L10n.discardsRecording,
                    hotkey: $cancelHotkey
                )
                .onChange(of: cancelHotkey) { _, newValue in
                    viewModel.settings.saveCancelHotkey(newValue)
                    onCloudHotkeysChanged?(toggleCloudHotkey, toggleGeminiHotkey, newValue)
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

    // MARK: - Recognition

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.recognition)

            VStack(alignment: .leading, spacing: Layout.Spacing.section) {
                languagePicker
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    // MARK: - Local Models

    private var localModelsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.localModels)

            VStack(spacing: Layout.Spacing.item) {
                ForEach(WhisperModel.allCases, id: \.rawValue) { model in
                    WhisperModelCardView(
                        model: model,
                        viewModel: viewModel,
                        loadedModels: $loadedModels,
                        onModelToggle: onModelToggle
                    )
                }

            }
            .padding(.bottom, Layout.Padding.section)
        }
    }

    // MARK: - Model Management

    @ViewBuilder
    private var modelManagementSection: some View {
        if !viewModel.installedModels.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: L10n.modelManagement)

                VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                    Button {
                        showDeleteAllConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text(L10n.deleteAllModels)
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .alert(L10n.deleteAllModelsQuestion, isPresented: $showDeleteAllConfirmation) {
                        Button(L10n.cancel, role: .cancel) {}
                        Button(L10n.deleteAll, role: .destructive) {
                            Task { await viewModel.deleteAllModels() }
                        }
                    } message: {
                        Text(L10n.deleteAllModelsMessage(count: viewModel.installedModels.count))
                    }

                    Text(L10n.removesAllModelsDescription)
                        .font(Typography.description)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)
                .background(AppColors.cardBackground)
                .cornerRadius(Layout.CornerRadius.card)
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.bottom, Layout.Padding.section)
            }
        }
    }

    // MARK: - Cloud (OpenAI)

    private var cloudSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.cloudOpenAI)

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

    // MARK: - Cloud (Gemini)

    private var geminiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.cloudGemini)

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

    // MARK: - Pickers & Fields

    private var languagePicker: some View {
        HStack {
            Text(L10n.language)
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $language) {
                Text(L10n.russian).tag("ru")
                Text(L10n.english).tag("en")
                Text(L10n.autoDetect).tag("auto")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
            .transaction { $0.animation = nil }
        }
    }

    private var openaiModelPicker: some View {
        HStack {
            Text(L10n.model)
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

    private var geminiModelPicker: some View {
        HStack {
            Text(L10n.model)
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
}
