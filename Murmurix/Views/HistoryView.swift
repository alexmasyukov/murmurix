//
//  HistoryView.swift
//  Murmurix
//

import SwiftUI

class HistoryViewModel: ObservableObject {
    @Published var records: [TranscriptionRecord] = []
    @Published var selectedRecord: TranscriptionRecord?

    private let historyService: HistoryServiceProtocol

    init(historyService: HistoryServiceProtocol = HistoryService.shared) {
        self.historyService = historyService
    }

    func loadRecords() {
        let fetched = historyService.fetchAll()
        records = fetched

        // Defer selection update to next run loop to avoid multiple updates per frame
        if selectedRecord == nil, let first = fetched.first {
            DispatchQueue.main.async {
                self.selectedRecord = first
            }
        }
    }

    func clearHistory() {
        historyService.deleteAll()
        records = []
        selectedRecord = nil
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        historyService.delete(id: record.id)
        records.removeAll { $0.id == record.id }
        if selectedRecord?.id == record.id {
            selectedRecord = records.first
        }
    }

    // MARK: - Statistics

    var totalDuration: TimeInterval {
        records.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var totalCharacters: Int {
        records.reduce(0) { $0 + $1.text.count }
    }

    var totalWords: Int {
        records.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showingClearConfirmation = false

    init(viewModel: HistoryViewModel = HistoryViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats panel at top
            HistoryStatsView(viewModel: viewModel)

            Divider()

            HSplitView {
                // Left panel - list of records
                VStack(spacing: 0) {
                    List(viewModel.records, selection: $viewModel.selectedRecord) { record in
                        HistoryRowView(record: record)
                            .tag(record)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.sidebar)

                    // Bottom toolbar
                    HStack {
                        Button(action: { showingClearConfirmation = true }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.records.isEmpty)

                        Spacer()

                        Text("\(viewModel.records.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .frame(minWidth: 250, maxWidth: 300)

                // Right panel - detail view
                if let record = viewModel.selectedRecord {
                    HistoryDetailView(
                        record: record,
                        onCopy: copyToClipboard,
                        onDelete: { viewModel.deleteRecord(record) }
                    )
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
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.loadRecords()
        }
        .alert("Clear History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("Are you sure you want to delete all \(viewModel.records.count) recordings? This cannot be undone.")
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Stats Panel

struct HistoryStatsView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        HStack(spacing: 0) {
            StatItemView(
                icon: "waveform",
                value: "\(viewModel.records.count)",
                label: "recordings"
            )

            StatDivider()

            StatItemView(
                icon: "clock",
                value: viewModel.formattedTotalDuration,
                label: "total time"
            )

            StatDivider()

            StatItemView(
                icon: "text.word.spacing",
                value: "\(viewModel.totalWords)",
                label: "words"
            )

            StatDivider()

            StatItemView(
                icon: "character",
                value: formatNumber(viewModel.totalCharacters),
                label: "characters"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 24)
    }
}

struct StatItemView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
    let onDelete: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top toolbar with metadata
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
