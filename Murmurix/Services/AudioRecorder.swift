//
//  AudioRecorder.swift
//  Murmurix
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

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
            audioRecorder?.record()
            isRecording = true
            print("Recording started: \(fileURL.path)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL {
        audioRecorder?.stop()
        isRecording = false
        print("Recording stopped: \(currentRecordingURL?.path ?? "unknown")")
        return currentRecordingURL ?? URL(fileURLWithPath: "")
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
