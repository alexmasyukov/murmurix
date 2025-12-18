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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            textContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Text(copied ? "Copied!" : "Copy")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
