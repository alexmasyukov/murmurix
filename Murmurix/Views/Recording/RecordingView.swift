//
//  RecordingView.swift
//  Murmurix
//

import SwiftUI

struct RecordingView: View {
    @ObservedObject var timer: RecordingTimer
    let audioLevel: Float
    let onStop: () -> Void

    private var isSoundActive: Bool {
        audioLevel > AudioConfig.voiceActivityThreshold
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(timer.formattedTime)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, alignment: .leading)

            EqualizerView(isActive: isSoundActive)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .modifier(FloatingCapsuleStyle())
    }
}

#Preview {
    ZStack {
        Color.gray
        RecordingView(timer: RecordingTimer(), audioLevel: 0.5, onStop: {})
    }
}
