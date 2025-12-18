//
//  GeneralSettingsView.swift
//  Murmurix
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("keepDaemonRunning") private var keepDaemonRunning = true
    @AppStorage("language") private var language = "ru"
    @AppStorage("whisperModel") private var whisperModel = WhisperModel.small.rawValue

    @State private var toggleHotkey: Hotkey
    @State private var cancelHotkey: Hotkey

    @StateObject private var viewModel = GeneralSettingsViewModel()
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
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        }
    }

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Recognition")

            VStack(alignment: .leading, spacing: 12) {
                languagePicker
                modelPicker
                modelDownloadStatus
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }

    private var languagePicker: some View {
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
    }

    private var modelPicker: some View {
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
            VStack(alignment: .leading, spacing: 8) {
                switch viewModel.downloadStatus {
                case .idle:
                    HStack(spacing: 8) {
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
                    HStack(spacing: 8) {
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
            .font(.system(size: 11))
        }
    }
}
