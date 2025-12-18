//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
    }

    var body: some View {
        TabView {
            GeneralSettingsView(
                isDaemonRunning: $isDaemonRunning,
                onDaemonToggle: onDaemonToggle,
                onHotkeysChanged: onHotkeysChanged,
                onModelChanged: onModelChanged
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            AISettingsView()
                .tabItem {
                    Label("AI Processing", systemImage: "sparkles")
                }
        }
        .frame(minWidth: 480, minHeight: 380)
        .preferredColorScheme(.dark)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("keepDaemonRunning") private var keepDaemonRunning = true
    @AppStorage("language") private var language = "ru"
    @AppStorage("whisperModel") private var whisperModel = WhisperModel.small.rawValue

    @State private var toggleHotkey: Hotkey
    @State private var cancelHotkey: Hotkey
    @State private var installedModels: Set<String> = []
    @State private var downloadStatus: DownloadStatus = .idle

    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
        _toggleHotkey = State(initialValue: Settings.shared.loadToggleHotkey())
        _cancelHotkey = State(initialValue: Settings.shared.loadCancelHotkey())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Keyboard Shortcuts Section
                SectionHeader(title: "Keyboard Shortcuts")

                VStack(spacing: 0) {
                    HotkeyRecorderView(
                        title: "Toggle Recording",
                        description: "Starts and stops recordings",
                        hotkey: $toggleHotkey
                    )
                    .onChange(of: toggleHotkey) { _, newValue in
                        Settings.shared.saveToggleHotkey(newValue)
                        onHotkeysChanged?(newValue, cancelHotkey)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)

                    HotkeyRecorderView(
                        title: "Cancel Recording",
                        description: "Discards the active recording",
                        hotkey: $cancelHotkey
                    )
                    .onChange(of: cancelHotkey) { _, newValue in
                        Settings.shared.saveCancelHotkey(newValue)
                        onHotkeysChanged?(toggleHotkey, newValue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // Performance Section
                SectionHeader(title: "Performance")

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Keep model in memory")
                                .font(.system(size: 13))
                                .foregroundColor(.white)

                            Circle()
                                .fill(isDaemonRunning ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)

                            Text(isDaemonRunning ? "Running" : "Stopped")
                                .font(.system(size: 10))
                                .foregroundColor(isDaemonRunning ? .green : .gray)
                        }
                        Text("Faster transcription, uses ~500MB RAM")
                            .font(.system(size: 11))
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // Recognition Section
                SectionHeader(title: "Recognition")

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Language")
                            .font(.system(size: 13))
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

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Model")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Text("Larger models are more accurate but slower")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Picker("", selection: $whisperModel) {
                            ForEach(WhisperModel.allCases, id: \.rawValue) { model in
                                HStack {
                                    Text(model.displayName)
                                    if !installedModels.contains(model.rawValue) {
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
                            downloadStatus = .idle
                            // Only restart daemon if model is installed
                            if let model = WhisperModel(rawValue: newValue), model.isInstalled {
                                onModelChanged?()
                            }
                        }
                    }

                    if !installedModels.contains(whisperModel) {
                        VStack(alignment: .leading, spacing: 8) {
                            switch downloadStatus {
                            case .idle:
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Model not installed")
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Button("Download") {
                                        startDownload()
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
                                            cancelDownload()
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
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(message)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                    Spacer()
                                    Button("Retry") {
                                        startDownload()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .font(.system(size: 11))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 16)
        }
        .onAppear {
            loadInstalledModels()
        }
        .transaction { $0.animation = nil }
    }

    private func loadInstalledModels() {
        installedModels = Set(WhisperModel.allCases.filter { $0.isInstalled }.map { $0.rawValue })
    }

    private func startDownload() {
        downloadStatus = .downloading

        ModelDownloadService.shared.downloadModel(whisperModel) { status in
            downloadStatus = status

            if case .completed = status {
                // Refresh installed models list
                loadInstalledModels()
                // Restart daemon with new model
                onModelChanged?()
                // Reset status after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if case .completed = downloadStatus {
                        downloadStatus = .idle
                    }
                }
            }
        }
    }

    private func cancelDownload() {
        ModelDownloadService.shared.cancelDownload()
        downloadStatus = .idle
    }
}

// MARK: - AI Settings

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
                // Enable Toggle
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

                // API Key Section
                SectionHeader(title: "Claude API")

                VStack(alignment: .leading, spacing: 12) {
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
                    }

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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .opacity(aiEnabled ? 1 : 0.5)
                .disabled(!aiEnabled)

                // Prompt Section
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

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let result = try await testApiKey(apiKey)
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

    private func testApiKey(_ key: String) async throws -> Bool {
        let requestBody: [String: Any] = [
            "model": "claude-3-5-haiku-latest",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIPostProcessingError.invalidResponse
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIPostProcessingError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return true
        } else if httpResponse.statusCode == 401 {
            throw AIPostProcessingError.apiError("Invalid API key")
        } else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIPostProcessingError.apiError(message)
            }
            throw AIPostProcessingError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.gray)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}


#Preview {
    SettingsView(isDaemonRunning: .constant(true))
}
