//
//  AudioRecorder.swift
//  Murmurix
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AudioRecorderProtocol {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var levelTimer: Timer?

    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "murmurix_recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        currentRecordingURL = fileURL

        // WAV format settings optimized for Whisper
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true

            // Start monitoring audio levels
            startLevelMonitoring()

            print("Recording started: \(fileURL.path)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL {
        stopLevelMonitoring()
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0.0
        print("Recording stopped: \(currentRecordingURL?.path ?? "unknown")")
        return currentRecordingURL ?? URL(fileURLWithPath: "")
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
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
            print("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
    }
}
