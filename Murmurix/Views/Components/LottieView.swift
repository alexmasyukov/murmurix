//
//  LottieView.swift
//  Murmurix
//

import SwiftUI
import Lottie

struct ColorReplacement: Equatable {
    let colorHex: String
    let keypaths: [String]
}

struct AnimatedLottieView: NSViewRepresentable {
    let animationName: String
    var animationSpeed: Double = 1.0
    var colorReplacements: [ColorReplacement] = []

    class Coordinator {
        var animationView: Lottie.LottieAnimationView?
        var isLoaded = false
        var lastColorSignature: String = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var colorSignature: String {
        colorReplacements.map { "\($0.colorHex):\($0.keypaths.count)" }.joined(separator: "|")
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
                    context.coordinator.isLoaded = true
                    context.coordinator.lastColorSignature = colorSignature
                    animationView.play()
                }
            } catch {
                Logger.Transcription.error("Failed to load Lottie animation \(animationName): \(error.localizedDescription)")
            }
        }

        return animationView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = context.coordinator.animationView,
              context.coordinator.isLoaded else { return }

        let newSignature = colorSignature
        if context.coordinator.lastColorSignature != newSignature {
            applyColors(to: animationView)
            context.coordinator.lastColorSignature = newSignature
        }
    }

    private func applyColors(to animationView: Lottie.LottieAnimationView) {
        for replacement in colorReplacements {
            let lottieColor = hexToLottieColor(replacement.colorHex)
            let colorProvider = ColorValueProvider(lottieColor)

            for keypath in replacement.keypaths {
                animationView.setValueProvider(colorProvider, keypath: AnimationKeypath(keypath: keypath))
            }
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
        colorReplacements: [
            ColorReplacement(colorHex: "#777777", keypaths: ["**.Fill 1.Color", "**.Stroke 1.Color"])
        ]
    )
    .frame(width: 100, height: 100)
}
