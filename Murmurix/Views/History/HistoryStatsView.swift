//
//  HistoryStatsView.swift
//  Murmurix
//

import SwiftUI

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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Helper Views

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
