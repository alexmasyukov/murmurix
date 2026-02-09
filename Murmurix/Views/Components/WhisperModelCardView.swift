//
//  WhisperModelCardView.swift
//  Murmurix
//

import SwiftUI

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
                .padding(.horizontal, Layout.Padding.standard)

            keepLoadedRow
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.vertical, Layout.Padding.vertical)

            Divider()
                .background(AppColors.divider)
                .padding(.horizontal, Layout.Padding.standard)

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
                .padding(.horizontal, Layout.Padding.standard)

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
        HotkeyRecorderView(
            title: L10n.hotkey,
            description: nil,
            hotkey: modelHotkeyBinding
        )
    }

    private var modelHotkeyBinding: Binding<Hotkey?> {
        Binding(
            get: { ms.hotkey },
            set: { newHotkey in
                viewModel.updateModelSettings(for: modelName) { ms in
                    ms.hotkey = newHotkey
                }
            }
        )
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
                    ZStack {
                        // Invisible text to reserve width
                        Text(L10n.testing)
                            .opacity(0)
                        HStack(spacing: 4) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isTesting ? L10n.testing : L10n.test)
                        }
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
