//
//  ProcessingView.swift
//  Murmurix
//

import SwiftUI

struct ProcessingView: View {
    let onCancel: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(.purple)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("AI")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            CancelButton(action: onCancel)
        }
        .modifier(FloatingCapsuleStyle())
    }
}

#Preview {
    ZStack {
        Color.gray
        ProcessingView(onCancel: {})
    }
}
