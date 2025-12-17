//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey) -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
    }

    var body: some View {
        TabView {
            GeneralSettingsView(
                isDaemonRunning: $isDaemonRunning,
                onDaemonToggle: onDaemonToggle,
                onHotkeysChanged: onHotkeysChanged
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

    @State private var toggleHotkey: Hotkey
    @State private var cancelHotkey: Hotkey

    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey) -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
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

                VStack(alignment: .leading, spacing: 8) {
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
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @AppStorage("aiPostProcessingEnabled") private var aiEnabled = false
    @AppStorage("aiModel") private var aiModel = AIModel.haiku.rawValue

    @State private var apiKey: String = ""
    @State private var prompt: String = ""

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

                        TextField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
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
        }
        .onChange(of: prompt) { _, newValue in
            Settings.shared.aiPrompt = newValue
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
