//
//  HistoryView.swift
//  Murmurix
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showingClearConfirmation = false

    init(viewModel: HistoryViewModel = HistoryViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            HistoryStatsView(viewModel: viewModel)
            Divider()
            contentSplitView
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

    private var contentSplitView: some View {
        HSplitView {
            listPanel
            detailPanel
        }
    }

    private var listPanel: some View {
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

            listToolbar
        }
        .frame(minWidth: 250, maxWidth: 300)
    }

    private var listToolbar: some View {
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

    @ViewBuilder
    private var detailPanel: some View {
        if let record = viewModel.selectedRecord {
            HistoryDetailView(
                record: record,
                onCopy: copyToClipboard,
                onDelete: { viewModel.deleteRecord(record) }
            )
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
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

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
