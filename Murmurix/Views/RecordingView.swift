//
//  RecordingView.swift
//  Murmurix
//

import SwiftUI

struct RecordingView: View {
    let isTranscribing: Bool
    let onStop: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isTranscribing ? Color.blue : Color.red)
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.6 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                if isTranscribing {
                    Image(systemName: "waveform")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
            }

            Text(isTranscribing ? "Transcribing..." : "Recording...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            if !isTranscribing {
                Button(action: onStop) {
                    Text("Stop (Cmd+Shift+S)")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 200, height: 140)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    RecordingView(isTranscribing: false, onStop: {})
}
