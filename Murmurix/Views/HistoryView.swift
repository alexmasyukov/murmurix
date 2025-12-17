//
//  HistoryView.swift
//  Murmurix
//

import SwiftUI

struct HistoryView: View {
    @State private var records: [TranscriptionRecord] = []
    @State private var selectedRecord: TranscriptionRecord?

    private let historyService: HistoryServiceProtocol

    init(historyService: HistoryServiceProtocol = HistoryService.shared) {
        self.historyService = historyService
    }

    var body: some View {
        HSplitView {
            // Left panel - list of records
            VStack(spacing: 0) {
                List(records, selection: $selectedRecord) { record in
                    HistoryRowView(record: record)
                        .tag(record)
                }
                .listStyle(.sidebar)

                // Bottom toolbar
                HStack {
                    Button(action: clearHistory) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(records.isEmpty)

                    Spacer()

                    Text("\(records.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 250, maxWidth: 300)

            // Right panel - detail view
            if let record = selectedRecord {
                HistoryDetailView(record: record, onCopy: copyToClipboard)
            } else {
                VStack {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a transcription")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadRecords()
        }
    }

    private func loadRecords() {
        records = historyService.fetchAll()
        if selectedRecord == nil, let first = records.first {
            selectedRecord = first
        }
    }

    private func clearHistory() {
        historyService.deleteAll()
        records = []
        selectedRecord = nil
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct HistoryRowView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(record.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(record.shortText)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    let onCopy: (String) -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with metadata
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.formattedTime)
                        .font(.headline)

                    HStack(spacing: 16) {
                        Label(record.formattedDuration, systemImage: "clock")
                        Label(record.language.uppercased(), systemImage: "globe")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    onCopy(record.text)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Text content
            ScrollView {
                Text(record.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
