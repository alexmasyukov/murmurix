//
//  AudioDecoder.swift
//  Murmurix
//

import Foundation

enum AudioDecoderError: Error, LocalizedError {
    case emptyData
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "Audio payload was empty."
        case .unsupportedFormat(let detail):
            return "Unsupported audio format: \(detail)"
        }
    }
}

/// Decodes incoming API audio bytes to a 16 kHz mono `Float` buffer **entirely in
/// memory** — nothing is ever written to disk. The API server hands the request body
/// straight here and passes the resulting samples to WhisperKit.
///
/// Accepts:
/// - a WAV (RIFF/WAVE) with PCM int16 or IEEE float32 data, any sample rate / channel
///   count (channels are down-mixed to mono, sample rate is linearly resampled to 16 kHz);
/// - otherwise, the bytes are treated as raw little-endian Float32 mono @ 16 kHz.
///
/// Clients are expected to send 16 kHz mono for best quality; the resampler is a
/// convenience fallback, not a high-quality SRC.
enum AudioDecoder {
    static let targetSampleRate = 16_000

    static func decodeToMonoFloat16k(_ data: Data) throws -> [Float] {
        guard !data.isEmpty else { throw AudioDecoderError.emptyData }

        let bytes = [UInt8](data)
        if bytes.count >= 12,
           bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46, // "RIFF"
           bytes[8] == 0x57, bytes[9] == 0x41, bytes[10] == 0x56, bytes[11] == 0x45 { // "WAVE"
            return try decodeWav(bytes)
        }

        // Raw Float32 mono @ 16 kHz.
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }

    // MARK: - WAV

    private static func decodeWav(_ bytes: [UInt8]) throws -> [Float] {
        var sampleRate = 0
        var channels = 1
        var bitsPerSample = 16
        var audioFormat = 1 // 1 = PCM int, 3 = IEEE float
        var dataRange: Range<Int>?

        // Walk the chunks after the 12-byte RIFF/WAVE header.
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = String(bytes: bytes[offset..<offset + 4], encoding: .ascii) ?? ""
            let size = readUInt32LE(bytes, offset + 4)
            let body = offset + 8
            if id == "fmt " {
                guard body + 16 <= bytes.count else {
                    throw AudioDecoderError.unsupportedFormat("truncated fmt chunk")
                }
                // fmt layout: format(0,2) channels(2,2) sampleRate(4,4)
                //             byteRate(8,4) blockAlign(12,2) bitsPerSample(14,2)
                audioFormat = Int(readUInt16LE(bytes, body))
                channels = max(1, Int(readUInt16LE(bytes, body + 2)))
                sampleRate = Int(readUInt32LE(bytes, body + 4))
                bitsPerSample = Int(readUInt16LE(bytes, body + 14))
            } else if id == "data" {
                let end = min(body + Int(size), bytes.count)
                dataRange = body..<end
                // data is usually the last chunk we care about
                break
            }
            // Chunks are word-aligned (pad byte if size is odd).
            offset = body + Int(size) + (size % 2 == 1 ? 1 : 0)
        }

        guard sampleRate > 0 else {
            throw AudioDecoderError.unsupportedFormat("missing fmt chunk")
        }
        guard let range = dataRange, !range.isEmpty else {
            throw AudioDecoderError.unsupportedFormat("missing or empty data chunk")
        }

        let interleaved = try samplesFromData(
            bytes,
            range: range,
            audioFormat: audioFormat,
            bitsPerSample: bitsPerSample
        )
        let mono = downmixToMono(interleaved, channels: channels)
        return resampleTo16k(mono, from: sampleRate)
    }

    private static func samplesFromData(
        _ bytes: [UInt8],
        range: Range<Int>,
        audioFormat: Int,
        bitsPerSample: Int
    ) throws -> [Float] {
        switch (audioFormat, bitsPerSample) {
        case (1, 16):
            var out = [Float]()
            out.reserveCapacity(range.count / 2)
            var i = range.lowerBound
            while i + 2 <= range.upperBound {
                let raw = Int16(bitPattern: UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8))
                out.append(Float(raw) / 32768.0)
                i += 2
            }
            return out
        case (3, 32):
            var out = [Float]()
            out.reserveCapacity(range.count / 4)
            var i = range.lowerBound
            while i + 4 <= range.upperBound {
                let bits = UInt32(bytes[i]) | (UInt32(bytes[i + 1]) << 8) | (UInt32(bytes[i + 2]) << 16) | (UInt32(bytes[i + 3]) << 24)
                out.append(Float(bitPattern: bits))
                i += 4
            }
            return out
        default:
            throw AudioDecoderError.unsupportedFormat("format=\(audioFormat) bits=\(bitsPerSample) (expected PCM16 or Float32)")
        }
    }

    private static func downmixToMono(_ interleaved: [Float], channels: Int) -> [Float] {
        guard channels > 1 else { return interleaved }
        let frames = interleaved.count / channels
        var mono = [Float](repeating: 0, count: frames)
        for f in 0..<frames {
            var sum: Float = 0
            for c in 0..<channels { sum += interleaved[f * channels + c] }
            mono[f] = sum / Float(channels)
        }
        return mono
    }

    /// Linear resampling to 16 kHz. Convenience fallback only — clients should send
    /// 16 kHz to avoid it.
    private static func resampleTo16k(_ samples: [Float], from sourceRate: Int) -> [Float] {
        guard sourceRate != targetSampleRate, sourceRate > 0, !samples.isEmpty else {
            return samples
        }
        let ratio = Double(targetSampleRate) / Double(sourceRate)
        let outCount = Int(Double(samples.count) * ratio)
        guard outCount > 0 else { return samples }
        var out = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let srcPos = Double(i) / ratio
            let idx = Int(srcPos)
            let frac = Float(srcPos - Double(idx))
            let a = samples[min(idx, samples.count - 1)]
            let b = samples[min(idx + 1, samples.count - 1)]
            out[i] = a + (b - a) * frac
        }
        return out
    }

    // MARK: - Little-endian readers

    private static func readUInt16LE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }
}
