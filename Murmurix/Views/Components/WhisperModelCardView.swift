//
//  WhisperModelCardView.swift
//  Murmurix
//

import SwiftUI
import Carbon

struct WhisperModelCardView: View {
    let model: WhisperModel
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?

    @State private var showDeleteConfirmation = false
    @AppStorage("appLanguage") private var appLanguage = "en"

    private var modelName: String { model.rawValue }
    private var isInstalled: Bool { viewModel.isModelInstalled(modelName) }
    private var isLoaded: Bool { loadedModels.contains(modelName) }
    private var ms: WhisperModelSettings { viewModel.modelSettings(for: modelName) }
    private var isTesting: Bool { viewModel.testingModels.contains(modelName) }
    private var testResult: APITestResult? { viewModel.localTestResults[modelName] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

            Divider()
                .background(AppColors.divider)
                .padding(.leading, Layout.Padding.standard)

            keepLoadedRow
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

            Divider()
                .background(AppColors.divider)
                .padding(.leading, Layout.Padding.standard)

            modelFileRow
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

            if let result = testResult {
                TestResultBadge(result: result, successText: L10n.modelWorksCorrectly)
                    .padding(.horizontal, Layout.Padding.standard)
                    .padding(.bottom, Layout.Padding.vertical)
            }

            Divider()
                .background(AppColors.divider)
                .padding(.leading, Layout.Padding.standard)

            hotkeyRow
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(Layout.CornerRadius.card)
        .padding(.horizontal, Layout.Padding.standard)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                Text(model.shortName)
                    .font(Typography.label)
                    .foregroundColor(.white)
                Text(L10n.whisperModelDescription(model))
                    .font(Typography.description)
                    .foregroundColor(.gray)
            }

            Spacer()

            if isInstalled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(L10n.installed)
                        .font(Typography.label)
                        .foregroundColor(.green)
                }
            } else {
                Text(L10n.notInstalled)
                    .font(Typography.label)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Hotkey

    private var hotkeyRow: some View {
        HStack {
            Text(L10n.hotkey)
                .font(Typography.label)
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Button(action: { startRecordingHotkey() }) {
                    HStack(spacing: 4) {
                        if isRecordingHotkey {
                            Text(L10n.pressKeys)
                                .font(Typography.monospaced)
                                .foregroundColor(.gray)
                        } else if let hotkey = ms.hotkey {
                            ForEach(hotkey.displayParts, id: \.self) { part in
                                KeyCapView(text: part)
                            }
                        } else {
                            Text(L10n.notSet)
                                .font(Typography.monospaced)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.item)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.button)
                            .fill(isRecordingHotkey ? Color.accentColor.opacity(0.3) : AppColors.divider)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.button)
                            .stroke(isRecordingHotkey ? Color.accentColor : AppColors.subtleBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if ms.hotkey != nil {
                    Button(action: { clearHotkey() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @State private var isRecordingHotkey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    private func startRecordingHotkey() {
        if isRecordingHotkey {
            stopRecordingHotkey()
            return
        }
        isRecordingHotkey = true
        GlobalHotkeyManager.isRecordingHotkey = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleHotkeyEvent(event)
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleHotkeyEvent(event)
        }
    }

    private func handleHotkeyEvent(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(Carbon.cmdKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(Carbon.optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(Carbon.controlKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(Carbon.shiftKey) }

        DispatchQueue.main.async {
            let newHotkey = Hotkey(keyCode: keyCode, modifiers: carbonModifiers)
            self.viewModel.updateModelSettings(for: self.modelName) { ms in
                ms.hotkey = newHotkey
            }
            self.stopRecordingHotkey()
        }
    }

    private func stopRecordingHotkey() {
        isRecordingHotkey = false
        GlobalHotkeyManager.isRecordingHotkey = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func clearHotkey() {
        viewModel.updateModelSettings(for: modelName) { ms in
            ms.hotkey = nil
        }
    }

    // MARK: - Keep Loaded Toggle

    private var keepLoadedRow: some View {
        HStack {
            HStack(spacing: Layout.Spacing.indicator) {
                Text(L10n.keepInMemory)
                    .font(Typography.label)
                    .foregroundColor(.white)

                if ms.keepLoaded {
                    Circle()
                        .fill(isLoaded ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { ms.keepLoaded },
                set: { newValue in
                    viewModel.updateModelSettings(for: modelName) { ms in
                        ms.keepLoaded = newValue
                    }
                    onModelToggle?(modelName, newValue)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .transaction { $0.animation = nil }
        }
    }

    // MARK: - Model File Row

    @ViewBuilder
    private var modelFileRow: some View {
        if isInstalled {
            HStack(spacing: Layout.Spacing.item) {
                Text(L10n.modelFile)
                    .font(Typography.label)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    Task { await viewModel.testModel(modelName) }
                } label: {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isTesting ? L10n.testing : L10n.test)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text(L10n.delete)
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .alert(L10n.deleteModel, isPresented: $showDeleteConfirmation) {
                    Button(L10n.cancel, role: .cancel) {}
                    Button(L10n.delete, role: .destructive) {
                        Task { await viewModel.deleteModel(modelName) }
                    }
                } message: {
                    Text(L10n.deleteModelMessage(modelName))
                }
            }
        } else {
            let status = viewModel.downloadStatus(for: modelName)
            switch status {
            case .idle:
                HStack(spacing: Layout.Spacing.item) {
                    Text(L10n.modelFile)
                        .font(Typography.label)
                        .foregroundColor(.white)
                    Spacer()
                    Button(L10n.download) {
                        viewModel.startDownload(for: modelName)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.downloading(progress: Int(progress * 100)))
                            .font(Typography.description)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(L10n.cancel) {
                            viewModel.cancelDownload(for: modelName)
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
                    Text(L10n.compiling)
                        .font(Typography.description)
                        .foregroundColor(.secondary)
                }

            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L10n.ready)
                        .font(Typography.description)
                        .foregroundColor(.green)
                }

            case .error(let message):
                HStack(spacing: Layout.Spacing.item) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(Typography.description)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button(L10n.retry) {
                        viewModel.startDownload(for: modelName)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}
