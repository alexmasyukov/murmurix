//
//  CatLoadingView.swift
//  Murmurix
//
//  Loading view with animated cat for transcribing state
//

import SwiftUI

enum LoadingState {
    case transcribing
}

struct CatLoadingView: View {
    let state: LoadingState
    let onCancel: () -> Void

    // Cat animation config
    private let animationName = "LoadingCat"
    private let animationSpeed = 2.0

    // Keypaths for gray body parts (transcribing state)
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

    // Keypaths for outline parts
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

    private var colorReplacements: [ColorReplacement] {
        [
            ColorReplacement(colorHex: "#777777", keypaths: bodyKeypaths),
            ColorReplacement(colorHex: "#777777", keypaths: outlineKeypaths)
        ]
    }

    var body: some View {
        HStack(spacing: 6) {
            AnimatedLottieView(
                animationName: animationName,
                animationSpeed: animationSpeed,
                colorReplacements: colorReplacements
            )
            .frame(width: 42, height: 42)

            CancelButton(action: onCancel)
        }
        .modifier(FloatingCapsuleStyle())
    }
}

#Preview("Transcribing") {
    ZStack {
        Color.gray
        CatLoadingView(state: .transcribing, onCancel: {})
    }
}
