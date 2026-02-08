//
//  HistoryView.swift
//  Murmurix
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showingClearConfirmation = false
    @AppStorage("appLanguage") private var appLanguage = "en"

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
        .alert(L10n.clearHistory, isPresented: $showingClearConfirmation) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.clearAll, role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text(L10n.clearHistoryMessage(count: viewModel.records.count))
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
                            Label(L10n.delete, systemImage: "trash")
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

            Text(L10n.itemsCount(viewModel.records.count))
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
            Text(L10n.selectTranscription)
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
