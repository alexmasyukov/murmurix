//
//  AudioTestUtility.swift
//  Murmurix
//

import Foundation

/// Utility for creating test audio files
enum AudioTestUtility {

    /// Creates a silent WAV file for testing purposes
    /// - Parameters:
    ///   - url: File URL to write to
    ///   - duration: Duration in seconds (default 0.1)
    ///   - sampleRate: Sample rate in Hz (default 16000)
    static func createSilentWavFile(at url: URL, duration: Double = 0.1, sampleRate: Int = 16000) throws {
        let data = createWavData(duration: duration, sampleRate: sampleRate)
        try data.write(to: url)
    }

    /// Creates a temporary test audio file URL
    static func createTemporaryTestAudioURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
    }

    /// Generates minimal WAV data in memory
    /// - Parameters:
    ///   - duration: Duration in seconds (default 0.1)
    ///   - sampleRate: Sample rate in Hz (default 16000)
    /// - Returns: WAV file data
    static func createWavData(duration: Double = 0.1, sampleRate: Int = 16000) -> Data {
        let numSamples = Int(Double(sampleRate) * duration)
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(numSamples * Int(numChannels) * Int(bitsPerSample / 8))
        let fileSize = 36 + dataSize

        var wav = Data()

        // RIFF header
        wav.append(Data("RIFF".utf8))
        wav.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wav.append(Data("WAVE".utf8))

        // fmt chunk
        wav.append(Data("fmt ".utf8))
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // PCM format
        wav.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = numChannels * (bitsPerSample / 8)
        wav.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        wav.append(Data("data".utf8))
        wav.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // Silence (zeros)
        wav.append(Data(count: Int(dataSize)))

        return wav
    }
}
