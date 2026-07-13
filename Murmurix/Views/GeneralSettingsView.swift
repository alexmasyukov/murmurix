//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

struct GeneralSettingsView: View {
    @State private var showDeleteAllConfirmation = false
    @State private var apiReachable = false

    @StateObject private var viewModel: GeneralSettingsViewModel
    @StateObject private var settingsStore: SettingsStore
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?

    init(
        viewModel: GeneralSettingsViewModel,
        settings: SettingsStorageProtocol,
        loadedModels: Binding<Set<String>>,
        onModelToggle: ((String, Bool) -> Void)? = nil,
        onLocalHotkeysChanged: (([String: Hotkey]) -> Void)? = nil,
        onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)? = nil
    ) {
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
                debugSection
                apiSection
                huggingFaceSection
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
                AppLanguage.postDidChange()
            }
        }
    }

    // MARK: - Local Models

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.debug)

            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                debugToggleRow(
                    title: L10n.focusDebugNotifications,
                    description: L10n.focusDebugNotificationsDescription,
                    isOn: $settingsStore.focusDebugNotificationsEnabled
                )

                Divider()
                    .background(AppColors.divider)
                    .padding(.vertical, Layout.Spacing.tiny)

                debugToggleRow(
                    title: L10n.alwaysPaste,
                    description: L10n.alwaysPasteDescription,
                    isOn: $settingsStore.alwaysPasteEnabled
                )
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
    }

    // MARK: - API

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.apiSectionTitle)

            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                HStack(alignment: .top, spacing: Layout.Spacing.item) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(L10n.apiServerTitle)
                                .font(Typography.label)
                                .foregroundColor(.white)
                            apiStatusBadge
                        }
                        Text(L10n.apiServerDescription)
                            .font(Typography.description)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: $settingsStore.apiServerEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if settingsStore.apiServerEnabled {
                    Divider()
                        .background(AppColors.divider)
                        .padding(.vertical, Layout.Spacing.tiny)
                    apiServerDetails
                }
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.bottom, Layout.Padding.section)
        }
        .task(id: apiStatusTaskID) {
            await refreshAPIStatus()
        }
    }

    private static let portFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 1024
        f.maximum = 65535
        f.allowsFloats = false
        f.usesGroupingSeparator = false
        return f
    }()

    private var apiStatusTaskID: String {
        "\(settingsStore.apiServerEnabled)-\(settingsStore.apiServerPort)"
    }

    private var apiStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(apiReachable ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(apiReachable ? L10n.apiServerStatusRunning : L10n.apiServerStatusStopped)
                .font(Typography.caption)
                .foregroundColor(apiReachable ? .green : .gray)
        }
    }

    private var apiServerDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Layout.Spacing.item) {
                Text(L10n.apiServerPort)
                    .font(Typography.label)
                    .foregroundColor(.white)
                TextField("", value: $settingsStore.apiServerPort, formatter: Self.portFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            VStack(alignment: .leading, spacing: 4) {
                endpointRow(method: "GET", path: "/health")
                endpointRow(method: "GET", path: "/v1/models")
                endpointRow(method: "POST", path: "/v1/transcribe?model=<name>&language=ru")
            }
        }
    }

    private func endpointRow(method: String, path: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(method)
                .font(Typography.caption.monospaced())
                .foregroundColor(method == "GET" ? .green : .orange)
                .frame(width: 36, alignment: .leading)
            Text("http://127.0.0.1:\(settingsStore.apiServerPort)\(path)")
                .font(Typography.caption.monospaced())
                .foregroundColor(.gray)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Pings the local /health endpoint so the badge reflects whether the server is
    /// actually listening (e.g. it stays "Выключено" if the port was already taken),
    /// not just the setting value.
    private func refreshAPIStatus() async {
        guard settingsStore.apiServerEnabled else {
            apiReachable = false
            return
        }
        // Give the server a moment to (re)bind after a toggle or port change.
        try? await Task.sleep(nanoseconds: 500_000_000)
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(settingsStore.apiServerPort)/health")!)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            apiReachable = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            apiReachable = false
        }
    }

    private func debugToggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: Layout.Spacing.item) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.label)
                    .foregroundColor(.white)

                Text(description)
                    .font(Typography.description)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(Text(title))
        }
    }

    // MARK: - HuggingFace token

    private var huggingFaceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: L10n.huggingFace)

            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                Text(L10n.huggingFaceTokenLabel)
                    .font(Typography.label)
                    .foregroundColor(.white)

                SecureField("hf_...", text: $settingsStore.huggingFaceToken)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                Text(L10n.huggingFaceTokenHint)
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
