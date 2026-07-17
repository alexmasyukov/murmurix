//
//  AudioRecorder.swift
//  Murmurix
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AudioRecorderProtocol {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var hadVoiceActivity = false

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var levelTimer: Timer?

    /// A recorder built and prepared ahead of the hotkey press. See `prepare()`.
    private var preparedRecorder: AVAudioRecorder?
    private var preparedURL: URL?

    private let voiceActivityThreshold: Float = AudioConfig.voiceActivityThreshold

    // WAV format settings - high quality for better listening
    // Whisper will downsample to 16kHz internally
    private static let recorderSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44100,  // CD quality for better listening
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
    ]

    // MARK: - Permission Handling

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    var permissionStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            self.runOnMain {
                completion(granted)
            }
        }
    }

    private func makeRecordingURL() -> URL {
        let fileName = "murmurix_recording_\(Date().timeIntervalSince1970).wav"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    /// Builds and primes the recorder for the *next* recording, so the hotkey press
    /// only has to call `record()`. Creating the AVAudioRecorder and letting
    /// `record()` do the file + audio-queue setup itself costs ~80ms of speech that
    /// is simply never captured; pre-primed, the same call returns in ~25ms.
    /// `prepareToRecord()` does not open the input, so no microphone indicator
    /// appears and nothing is captured until `record()` is actually called.
    func prepare() {
        guard permissionStatus == .granted, preparedRecorder == nil else { return }

        let url = makeRecordingURL()
        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.recorderSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord() else {
                Logger.Audio.error("prepareToRecord() failed; falling back to cold start")
                try? FileManager.default.removeItem(at: url)
                return
            }
            preparedRecorder = recorder
            preparedURL = url
        } catch {
            Logger.Audio.error("Failed to prepare recorder: \(error)")
        }
    }

    func startRecording() {
        // Check permission first
        guard permissionStatus == .granted else {
            if permissionStatus == .notDetermined {
                requestPermission { [weak self] granted in
                    if granted {
                        self?.startRecording()
                    } else {
                        Logger.Audio.error("Microphone permission denied")
                    }
                }
            } else {
                Logger.Audio.error("Microphone permission denied. Please enable in System Settings > Privacy > Microphone")
            }
            return
        }

        // Use the recorder primed after the last recording; only build one here if
        // the warm-up never ran (first launch before prepare(), or it failed).
        let fileURL = preparedURL ?? makeRecordingURL()
        let warm = preparedRecorder
        preparedRecorder = nil
        preparedURL = nil
        currentRecordingURL = fileURL

        do {
            if let warm {
                audioRecorder = warm
            } else {
                audioRecorder = try AVAudioRecorder(url: fileURL, settings: Self.recorderSettings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = true
            }
            // AVAudioRecorder.record() returns false when AVFoundation cannot
            // open the input stream — most often this happens when TCC says
            // the app is allowed but the underlying audio plumbing is stale
            // after the .app bundle was replaced in /Applications/. Symptom:
            // mic indicator never appears and meter values stay at zero.
            // Without checking the return value we'd happily log "Recording
            // started" and the user would see no waveform with no error.
            let recordStart = Date()
            let started = audioRecorder?.record() ?? false
            let recordLatencyMs = Date().timeIntervalSince(recordStart) * 1000
            guard started else {
                Logger.Audio.error("AVAudioRecorder.record() returned false — TCC state may be stale. Reset Microphone for Murmurix in System Settings.")
                audioRecorder = nil
                currentRecordingURL = nil
                return
            }
            isRecording = true
            hadVoiceActivity = false  // Reset voice activity flag

            // Start monitoring audio levels
            startLevelMonitoring()

            Logger.Audio.info("Recording started in \(String(format: "%.0f", recordLatencyMs))ms (warm: \(warm != nil)): \(fileURL.path)")
        } catch {
            Logger.Audio.error("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL {
        stopLevelMonitoring()
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        audioLevel = 0.0
        Logger.Audio.info("Recording stopped: \(currentRecordingURL?.path ?? "unknown")")

        // Prime the next recorder once this turn of the run loop is done, so the
        // warm-up cost lands between recordings instead of inside stop().
        DispatchQueue.main.async { [weak self] in self?.prepare() }

        return currentRecordingURL ?? URL(fileURLWithPath: "")
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: AudioConfig.meterUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }

            recorder.updateMeters()

            // Get average power in dB (range: -160 to 0)
            let avgPower = recorder.averagePower(forChannel: 0)

            // Convert to 0-1 range with some smoothing
            // -50 dB = silence, 0 dB = max
            let normalizedLevel = max(0, (avgPower + 50) / 50)

            self.runOnMain {
                // Smooth the transition
                self.audioLevel = self.audioLevel * 0.3 + normalizedLevel * 0.7

                // Track voice activity
                if self.audioLevel > self.voiceActivityThreshold {
                    self.hadVoiceActivity = true
                }
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            Task { @MainActor in
                block()
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.Audio.error("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            Logger.Audio.error("Recording encode error: \(error)")
        }
    }
}
