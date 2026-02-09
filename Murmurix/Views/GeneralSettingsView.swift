//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

struct GeneralSettingsView: View {
    @State private var showDeleteAllConfirmation = false

    @StateObject private var viewModel: GeneralSettingsViewModel
    @StateObject private var settingsStore: SettingsStore
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?

    init(
        settings: SettingsStorageProtocol,
        loadedModels: Binding<Set<String>>,
        onModelToggle: ((String, Bool) -> Void)? = nil,
        onLocalHotkeysChanged: (([String: Hotkey]) -> Void)? = nil,
        onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)? = nil
    ) {
        let viewModel = GeneralSettingsViewModel(settings: settings)
        let settingsStore = SettingsStore(settings: settings)
        self._loadedModels = loadedModels
        self.onModelToggle = onModelToggle
        self.onLocalHotkeysChanged = onLocalHotkeysChanged
        self.onCloudHotkeysChanged = onCloudHotkeysChanged
        _viewModel = StateObject(wrappedValue: viewModel)
        _settingsStore = StateObject(wrappedValue: settingsStore)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                languageSection
                keyboardShortcutsSection
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

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.language)

            VStack(spacing: 0) {
                appLanguagePicker
                    .padding(.horizontal, Layout.Padding.standard)
                    .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.horizontal, Layout.Padding.standard)

                languagePicker
                    .padding(.horizontal, Layout.Padding.standard)
                    .padding(.vertical, Layout.Padding.vertical)
            }
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
                    hotkey: $settingsStore.toggleCloudHotkey
                )
                .onChange(of: settingsStore.toggleCloudHotkey) { _, newValue in
                    onCloudHotkeysChanged?(newValue, settingsStore.toggleGeminiHotkey, settingsStore.cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.horizontal, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: L10n.geminiRecording,
                    description: L10n.recordWithGemini,
                    hotkey: $settingsStore.toggleGeminiHotkey
                )
                .onChange(of: settingsStore.toggleGeminiHotkey) { _, newValue in
                    onCloudHotkeysChanged?(settingsStore.toggleCloudHotkey, newValue, settingsStore.cancelHotkey)
                }
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

                Divider()
                    .background(AppColors.divider)
                    .padding(.horizontal, Layout.Padding.standard)

                HotkeyRecorderView(
                    title: L10n.cancelRecording,
                    description: L10n.discardsRecording,
                    hotkey: $settingsStore.cancelHotkey
                )
                .onChange(of: settingsStore.cancelHotkey) { _, newValue in
                    onCloudHotkeysChanged?(settingsStore.toggleCloudHotkey, settingsStore.toggleGeminiHotkey, newValue)
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

    private var appLanguagePicker: some View {
        HStack {
            Text(L10n.appLanguage)
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $settingsStore.appLanguage) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .transaction { $0.animation = nil }
            .onChange(of: settingsStore.appLanguage) { _, _ in
                NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
            }
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
            Text(L10n.recognitionLanguage)
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $settingsStore.language) {
                Text(L10n.russian).tag("ru")
                Text(L10n.english).tag("en")
                Text(L10n.autoDetect).tag("auto")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .transaction { $0.animation = nil }
        }
    }

    private var openaiModelPicker: some View {
        HStack {
            Text(L10n.model)
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            Picker("", selection: $settingsStore.openaiTranscriptionModel) {
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
            apiKey: $settingsStore.openaiApiKey,
            isTesting: viewModel.isTestingOpenAI,
            testResult: viewModel.openaiTestResult,
            onKeyChanged: { _ in
                viewModel.clearTestResult(for: .openAI)
            },
            onTest: {
                Task {
                    await viewModel.testOpenAI(apiKey: settingsStore.openaiApiKey)
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

            Picker("", selection: $settingsStore.geminiModel) {
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
            apiKey: $settingsStore.geminiApiKey,
            isTesting: viewModel.isTestingGemini,
            testResult: viewModel.geminiTestResult,
            onKeyChanged: { _ in
                viewModel.clearTestResult(for: .gemini)
            },
            onTest: {
                Task {
                    await viewModel.testGemini(apiKey: settingsStore.geminiApiKey)
                }
            }
        )
    }
}
