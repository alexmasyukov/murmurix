//
//  RecordingWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI
import Combine

// Wrapper to observe audioLevel changes
class AudioLevelObserver: ObservableObject {
    @Published var level: Float = 0
    private var cancellable: AnyCancellable?

    init(audioRecorder: AudioRecorder) {
        cancellable = audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLevel in
                self?.level = newLevel
            }
    }
}

class RecordingWindowController: NSWindowController {
    private var audioRecorder: AudioRecorder
    private var onStop: () -> Void
    private var onCancelTranscription: (() -> Void)?
    private let recordingTimer = RecordingTimer()
    private var audioLevelObserver: AudioLevelObserver!

    init(audioRecorder: AudioRecorder, onStop: @escaping () -> Void, onCancelTranscription: (() -> Void)? = nil) {
        self.audioRecorder = audioRecorder
        self.onStop = onStop
        self.onCancelTranscription = onCancelTranscription

        // Dynamic Island style window - borderless, transparent
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 48),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        super.init(window: window)

        audioLevelObserver = AudioLevelObserver(audioRecorder: audioRecorder)
        setupContentView()
        recordingTimer.start()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView() {
        let contentView = RecordingContentView(
            timer: recordingTimer,
            audioLevelObserver: audioLevelObserver,
            onStop: onStop
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = .clear
        window?.contentView = hostingView
    }

    func showTranscribing() {
        recordingTimer.stop()
        let contentView = TranscribingView(onCancel: { [weak self] in
            self?.onCancelTranscription?()
        })
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = .clear
        window?.contentView = hostingView

        // Re-center window for slightly wider TranscribingView
        if let screen = NSScreen.main, let window = window {
            window.layoutIfNeeded()
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - windowFrame.height - 10
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    override func showWindow(_ sender: Any?) {
        // Position at top center of screen (like Dynamic Island)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window?.frame ?? .zero
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - windowFrame.height - 10
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        super.showWindow(sender)
    }

    override func close() {
        recordingTimer.stop()
        super.close()
    }
}

// SwiftUI wrapper that observes audioLevel
struct RecordingContentView: View {
    @ObservedObject var timer: RecordingTimer
    @ObservedObject var audioLevelObserver: AudioLevelObserver
    let onStop: () -> Void

    var body: some View {
        RecordingView(
            timer: timer,
            audioLevel: audioLevelObserver.level,
            onStop: onStop
        )
    }
}
