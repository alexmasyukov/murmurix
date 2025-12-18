//
//  TranscribingView.swift
//  Murmurix
//

import SwiftUI

struct TranscribingView: View {
    let onCancel: () -> Void
    @State private var dotAnimation = false

    var body: some View {
        HStack(spacing: 10) {
            PulsingDotsView(isAnimating: $dotAnimation)

            CancelButton(action: onCancel)
        }
        .modifier(FloatingCapsuleStyle())
        .onAppear { dotAnimation = true }
    }
}

struct PulsingDotsView: View {
    @Binding var isAnimating: Bool
    private let dotCount = 3

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        TranscribingView(onCancel: {})
    }
}
