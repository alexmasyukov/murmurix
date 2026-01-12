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
    private var timer: Timer?
    private weak var audioRecorder: (any AudioRecorderProtocol)?

    init(audioRecorder: any AudioRecorderProtocol) {
        self.audioRecorder = audioRecorder
        startObserving()
    }

    private func startObserving() {
        timer = Timer.scheduledTimer(withTimeInterval: AudioConfig.meterUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.level = recorder.audioLevel
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// Observable state for cat loading animation
class CatLoadingState: ObservableObject {
    @Published var state: LoadingState = .transcribing
}

class RecordingWindowController: NSWindowController {
    private var audioRecorder: any AudioRecorderProtocol
    private var onStop: () -> Void
    private var onCancelTranscription: (() -> Void)?
    private let recordingTimer = RecordingTimer()
    private var audioLevelObserver: AudioLevelObserver!
    private var catLoadingState: CatLoadingState?

    init(audioRecorder: any AudioRecorderProtocol, onStop: @escaping () -> Void, onCancelTranscription: (() -> Void)? = nil) {
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

        let loadingState = CatLoadingState()
        loadingState.state = .transcribing
        self.catLoadingState = loadingState

        let contentView = CatLoadingContentView(
            loadingState: loadingState,
            onCancel: { [weak self] in
                self?.onCancelTranscription?()
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = .clear
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = [.intrinsicContentSize]
        }
        window?.contentView = hostingView
        updateWindowSize()
    }

    private func updateWindowSize() {
        guard let window = window, let hostingView = window.contentView as? NSHostingView<CatLoadingContentView> else { return }
        let size = hostingView.fittingSize
        let origin = CGPoint(
            x: window.frame.midX - size.width / 2,
            y: window.frame.midY - size.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        WindowPositioner.positionTopCenter(window)
    }

    private func recenterWindow() {
        guard let window = window else { return }
        WindowPositioner.positionTopCenter(window)
    }

    override func showWindow(_ sender: Any?) {
        if let window = window {
            WindowPositioner.positionTopCenter(window)
        }
        super.showWindow(sender)
    }

    override func close() {
        recordingTimer.stop()
        catLoadingState = nil
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

// SwiftUI wrapper for cat loading animation
struct CatLoadingContentView: View {
    @ObservedObject var loadingState: CatLoadingState
    let onCancel: () -> Void

    var body: some View {
        CatLoadingView(state: loadingState.state, onCancel: onCancel)
    }
}
