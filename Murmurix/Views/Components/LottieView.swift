//
//  LottieView.swift
//  Murmurix
//

import SwiftUI
import Lottie

struct AnimatedLottieView: View {
    let animationName: String
    var animationSpeed: Double = 1.0
    var colorHex: String? = nil
    var colorKeypaths: [String] = []  // Custom keypaths for color replacement

    var body: some View {
        LottieView {
            try await DotLottieFile.named(animationName)
        }
        .looping()
        .animationSpeed(animationSpeed)
        .configure { animationView in
            if let hex = colorHex, !colorKeypaths.isEmpty {
                applyColor(to: animationView, hex: hex, keypaths: colorKeypaths)
            }
        }
        .id(colorHex)  // Force recreation when color changes
    }

    private func applyColor(to animationView: Lottie.LottieAnimationView, hex: String, keypaths: [String]) {
        let lottieColor = hexToLottieColor(hex)
        let colorProvider = ColorValueProvider(lottieColor)

        for keypath in keypaths {
            animationView.setValueProvider(colorProvider, keypath: AnimationKeypath(keypath: keypath))
        }
    }

    private func hexToLottieColor(_ hex: String) -> LottieColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return LottieColor(r: r, g: g, b: b, a: 1.0)
    }
}

#Preview {
    AnimatedLottieView(
        animationName: "LoadingCat",
        colorHex: "#777777",
        colorKeypaths: ["**.Fill 1.Color", "**.Stroke 1.Color"]
    )
    .frame(width: 100, height: 100)
}
