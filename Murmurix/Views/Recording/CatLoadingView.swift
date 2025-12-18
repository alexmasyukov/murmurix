//
//  CatLoadingView.swift
//  Murmurix
//
//  Loading view with animated cat for transcribing and AI processing states
//

import SwiftUI

enum LoadingState {
    case transcribing
    case processing
}

struct CatLoadingView: View {
    let state: LoadingState
    let onCancel: () -> Void

    // Cat animation config
    private let animationName = "LoadingCat"
    private let animationSpeed = 1.0

    // Keypaths for orange parts in the cat animation
    private let catColorKeypaths = [
        "Hand_outside_000_fill.**.Fill 1.Color",
        "Hand_inside_001_fill.**.Stroke 1.Color",
        "Hand_inside_002_fill.**.Stroke 1.Color",
        "circle 33.**.Stroke 1.Color",
        "Leg_outside_001_fill.**.Stroke 1.Color",
        "Leg_outside_002_fill.**.Stroke 1.Color",
        "Leg_inside_001_fill.**.Stroke 1.Color",
        "Leg_inside_002_fill.**.Stroke 1.Color",
        "Hand_inside_001_fill.**.Stroke 1.Color"
    ]

    private var colorHex: String {
        switch state {
        case .transcribing:
            return "#000"
        case .processing:
            return "#F5A623"
        }
    }

    private var showLabel: Bool {
        state == .processing
    }

    var body: some View {
        HStack(spacing: 10) {
            AnimatedLottieView(
                animationName: animationName,
                animationSpeed: animationSpeed,
                colorHex: colorHex,
                colorKeypaths: catColorKeypaths
            )
            .frame(width: 112, height: 112)

            if showLabel {
                Text("AI")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity.combined(with: .scale))
            }

            CancelButton(action: onCancel)
        }
        .modifier(FloatingCapsuleStyle())
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

#Preview("Transcribing") {
    ZStack {
        Color.gray
        CatLoadingView(state: .transcribing, onCancel: {})
    }
}

#Preview("Processing") {
    ZStack {
        Color.gray
        CatLoadingView(state: .processing, onCancel: {})
    }
}
