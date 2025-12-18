//
//  LottieView.swift
//  Murmurix
//

import SwiftUI
import Lottie

struct AnimatedLottieView: NSViewRepresentable {
    let animationName: String
    var animationSpeed: Double = 1.0
    var colorHex: String? = nil
    var colorKeypaths: [String] = []

    class Coordinator {
        var animationView: Lottie.LottieAnimationView?
        var currentColorHex: String?
        var currentKeypathsCount: Int = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let animationView = Lottie.LottieAnimationView()
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = animationSpeed
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        context.coordinator.animationView = animationView

        Task {
            do {
                let dotLottie = try await DotLottieFile.named(animationName)
                await MainActor.run {
                    animationView.loadAnimation(from: dotLottie)
                    animationView.loopMode = .loop
                    animationView.animationSpeed = animationSpeed
                    applyColors(to: animationView)
                    context.coordinator.currentColorHex = colorHex
                    context.coordinator.currentKeypathsCount = colorKeypaths.count
                    animationView.play()
                }
            } catch {
                print("Failed to load animation: \(error)")
            }
        }

        return animationView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }

        // Only update if color or keypaths changed
        if context.coordinator.currentColorHex != colorHex ||
           context.coordinator.currentKeypathsCount != colorKeypaths.count {
            applyColors(to: animationView)
            context.coordinator.currentColorHex = colorHex
            context.coordinator.currentKeypathsCount = colorKeypaths.count
        }
    }

    private func applyColors(to animationView: Lottie.LottieAnimationView) {
        guard let hex = colorHex, !colorKeypaths.isEmpty else { return }

        let lottieColor = hexToLottieColor(hex)
        let colorProvider = ColorValueProvider(lottieColor)

        for keypath in colorKeypaths {
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
