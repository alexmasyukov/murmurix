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

    private let voiceActivityThreshold: Float = AudioConfig.voiceActivityThreshold

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
            DispatchQueue.main.async {
                completion(granted)
            }
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

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "murmurix_recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        currentRecordingURL = fileURL

        // WAV format settings - high quality for better listening
        // Whisper will downsample to 16kHz internally
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,  // CD quality for better listening
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            hadVoiceActivity = false  // Reset voice activity flag

            // Start monitoring audio levels
            startLevelMonitoring()

            Logger.Audio.info("Recording started: \(fileURL.path)")
        } catch {
            Logger.Audio.error("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL {
        stopLevelMonitoring()
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0.0
        Logger.Audio.info("Recording stopped: \(currentRecordingURL?.path ?? "unknown")")
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

            DispatchQueue.main.async {
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
