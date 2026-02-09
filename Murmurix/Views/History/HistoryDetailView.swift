//
//  HistoryDetailView.swift
//  Murmurix
//

import SwiftUI

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    let onCopy: (String) -> Void
    let onDelete: () -> Void

    @State private var copied = false
    @State private var copyIndicatorResetTask: Task<Void, Never>?
    @AppStorage("appLanguage") private var appLanguage = "en"
    private let copyIndicatorResetDelay: TimeInterval = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            textContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            copyIndicatorResetTask?.cancel()
            copyIndicatorResetTask = nil
        }
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.formattedTime)
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 12) {
                    Label(record.formattedDuration, systemImage: "clock")
                    Label(record.language.uppercased(), systemImage: "globe")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)

            Button(action: copyText) {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? L10n.copied : L10n.copy)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var textContent: some View {
        ScrollView {
            Text(record.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    private func copyText() {
        onCopy(record.text)
        copied = true
        scheduleCopyIndicatorReset()
    }

    private func scheduleCopyIndicatorReset() {
        copyIndicatorResetTask?.cancel()
        let delayNanoseconds = UInt64(copyIndicatorResetDelay * 1_000_000_000)

        copyIndicatorResetTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            copied = false
            copyIndicatorResetTask = nil
        }
    }
}
