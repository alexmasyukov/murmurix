//
//  RecordingView.swift
//  Murmurix
//

import SwiftUI
import Combine

class RecordingTimer: ObservableObject {
    @Published var elapsedSeconds: Int = 0
    private var timer: Timer?

    func start() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

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

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white)
            .frame(width: 3, height: height)
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
        // Quick start - 0.1 sec
        let interval = 0.1

        animationTimer?.invalidate()

        // Immediate first jump
        withAnimation(.easeOut(duration: 0.1)) {
            height = CGFloat.random(in: 8...20)
        }

        // Continue animating with slight variation per bar
        let timerInterval = interval + Double(barIndex) * 0.015
        animationTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: timerInterval)) {
                height = CGFloat.random(in: 8...20)
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil

        // Slow fade out - 0.5 sec
        withAnimation(.easeOut(duration: 0.5)) {
            height = 4
        }
    }
}

// MARK: - Recording View (with equalizer)

struct RecordingView: View {
    @ObservedObject var timer: RecordingTimer
    let audioLevel: Float
    let onStop: () -> Void

    // Sound detected if above threshold
    private var isSoundActive: Bool {
        audioLevel > 0.33
    }

    private var timeString: String {
        let minutes = timer.elapsedSeconds / 60
        let seconds = timer.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Timer on the left - fixed width to prevent jumping
            Text(timeString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, alignment: .leading)

            // Equalizer - triggered by sound detection
            EqualizerView(isActive: isSoundActive)

            // Stop button on the right
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
        )
    }
}

// MARK: - Transcribing View (pulsing dots + cancel)

struct TranscribingView: View {
    let onCancel: () -> Void
    @State private var dotAnimation = false

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .scaleEffect(dotAnimation ? 1.0 : 0.5)
                        .opacity(dotAnimation ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: dotAnimation
                        )
                }
            }

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
        )
        .onAppear { dotAnimation = true }
    }
}

// MARK: - Processing View (AI post-processing with sparkle animation)

struct ProcessingView: View {
    let onCancel: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            // Sparkle icon with rotation
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

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
        )
    }
}

#Preview("Recording") {
    ZStack {
        Color.gray
        RecordingView(timer: RecordingTimer(), audioLevel: 0.5, onStop: {})
    }
}

#Preview("Transcribing") {
    ZStack {
        Color.gray
        TranscribingView(onCancel: {})
    }
}

#Preview("Processing") {
    ZStack {
        Color.gray
        ProcessingView(onCancel: {})
    }
}
