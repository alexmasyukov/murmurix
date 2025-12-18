//
//  EqualizerView.swift
//  Murmurix
//

import SwiftUI

struct EqualizerView: View {
    let isActive: Bool
    private let barCount = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                EqualizerBar(barIndex: index, isActive: isActive)
            }
        }
    }
}

struct EqualizerBar: View {
    let barIndex: Int
    let isActive: Bool

    @State private var height: CGFloat = 4
    @State private var animationTimer: Timer?

    private enum Constants {
        static let minHeight: CGFloat = 4
        static let maxHeight: CGFloat = 20
        static let activeMinHeight: CGFloat = 8
        static let barWidth: CGFloat = 3
        static let cornerRadius: CGFloat = 1.5
        static let baseInterval: Double = 0.1
        static let intervalVariation: Double = 0.015
        static let fadeOutDuration: Double = 0.5
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.white)
            .frame(width: Constants.barWidth, height: height)
            .onChange(of: isActive) { _, active in
                if active {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onAppear {
                if isActive {
                    startAnimation()
                }
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
    }

    private func startAnimation() {
        animationTimer?.invalidate()

        // Immediate first jump
        withAnimation(.easeOut(duration: Constants.baseInterval)) {
            height = CGFloat.random(in: Constants.activeMinHeight...Constants.maxHeight)
        }

        // Continue animating with slight variation per bar
        let timerInterval = Constants.baseInterval + Double(barIndex) * Constants.intervalVariation
        animationTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: timerInterval)) {
                height = CGFloat.random(in: Constants.activeMinHeight...Constants.maxHeight)
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil

        withAnimation(.easeOut(duration: Constants.fadeOutDuration)) {
            height = Constants.minHeight
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        EqualizerView(isActive: false)
        EqualizerView(isActive: true)
    }
    .padding()
    .background(Color.black)
}
