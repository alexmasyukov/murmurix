//
//  HistoryRowView.swift
//  Murmurix
//

import SwiftUI

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
