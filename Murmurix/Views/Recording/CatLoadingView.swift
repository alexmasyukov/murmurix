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
    private let animationSpeed = 2.0

    // Keypaths for orange body parts
    private let bodyKeypaths = [
        // Hands
        "Hand_outside_000_fill.Shape 1.Fill 1.Color",
        "Hand_inside_001_fill.Group 1.Stroke 1.Color",
        "Hand_inside_002_fill.Group 1.Stroke 1.Color",
        // Circle
        "circle 33.Group 1.Stroke 1.Color",
        // Legs
        "Leg_outside_001_fill.Group 1.Stroke 1.Color",
        "Leg_outside_002_fill.Group 1.Stroke 1.Color",
        "Leg_inside_001_fill.Group 1.Stroke 1.Color",
        "Leg_inside_002_fill.Group 1.Stroke 1.Color",
        // Body
        "Body_002_square_fill.Group 1.Stroke 1.Color",
        "Body_002_round_fill.Group 1.Stroke 1.Color",
        // Tail
        "Tail_002_fill.Group 1.Stroke 1.Color",
        // Ears
        "ears.Shape 1.Fill 1.Color"
    ]

    // Keypaths for black outline parts
    private let outlineKeypaths = [
        "Hand_outside_000_stroke.Shape 1.Stroke 1.Color",
        "Hand_outside_001_stroke.Group 1.Stroke 1.Color",
        "Hand_outside_002_stroke.Group 1.Stroke 1.Color",
        "circle 31.Group 1.Stroke 1.Color",
        "Leg_outside_001_stroke.Group 1.Stroke 1.Color",
        "Leg_outside_002_stroke.Group 1.Stroke 1.Color",
        "Leg_inside_003_stroke.Group 1.Stroke 1.Color",
        "Leg_inside_004_stroke.Group 1.Stroke 1.Color",
        "Body_001_square_stroke.Group 1.Stroke 1.Color",
        "Body_001_round_stroke.Group 1.Stroke 1.Color",
        "Tail_001_stroke.Group 1.Stroke 1.Color",
        "ears.Shape 1.Stroke 1.Color",
        "mouth.Shape 1.Stroke 1.Color",
        "eyes.Shape 1.Fill 1.Color",
        "eyes.Shape 2.Fill 1.Color"
    ]

    private var colorHex: String {
        switch state {
        case .transcribing:
            return "#777777"
        case .processing:
            return "#CB7C5E"
        }
    }

    private var colorKeypaths: [String] {
        switch state {
        case .transcribing:
            return bodyKeypaths + outlineKeypaths  // All grey
        case .processing:
            return bodyKeypaths  // Only body orange, outline stays default
        }
    }

    private var showLabel: Bool {
        state == .processing
    }

    var body: some View {
        HStack(spacing: 6) {
            AnimatedLottieView(
                animationName: animationName,
                animationSpeed: animationSpeed,
                colorHex: colorHex,
                colorKeypaths: colorKeypaths
            )
            .frame(width: 42, height: 42)
           
            if showLabel {
                Text("Claude")
                    .font(.system(size: 12, weight: .medium))
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
