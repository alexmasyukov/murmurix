//
//  SilenceTrimmer.swift
//  Murmurix
//

import Foundation
import WhisperKit

/// Trims leading/trailing silence from recorded audio before it reaches WhisperKit.
///
/// Why this exists: WhisperKit only runs its built-in VAD chunker — the part that
/// splits on pauses and stops ~1s early to dodge end-of-clip hallucinations — for
/// audio **longer than 30 seconds**. See `VADAudioChunker.chunkAll`, which returns
/// short audio as a single unmodified chunk, and `WhisperKit.transcribe`, which only
/// invokes the chunker when `audioArray.count > windowSamples`. A typical dictation
/// is shorter than 30s, so it goes into the decoder whole — trailing silence included.
/// On that silent tail Whisper happily emits memorized YouTube-subtitle filler
/// ("Продолжение следует...", "Спасибо за просмотр"). Trimming the edges ourselves
/// removes the very ground those hallucinations grow on.
///
/// Internal pauses are **left untouched** — we only cut the edges, so punctuation and
/// the natural structure of speech survive.
enum SilenceTrimmer {
    /// Audio kept around the speech so we don't clip the attack of the first syllable
    /// or the decay of the last one.
    static let edgePaddingSeconds: Double = 0.2

    /// Extra headroom at the tail. Phrase endings in natural speech decay in volume,
    /// and EnergyVAD compares each 100ms frame against an *absolute* RMS threshold
    /// (0.02) — the last quiet word routinely falls below it and gets marked as
    /// silence. A symmetric 0.2s pad then cuts into real speech. The tail pad is
    /// therefore wider than the leading one; a half-second of leftover silence is
    /// far too short for Whisper to hallucinate on.
    static let trailingPaddingSeconds: Double = 0.5

    /// An edge is only trimmed when it removes at least this much audio. The whole
    /// point of trimming is killing multi-second silent tails that breed
    /// hallucinations; shaving fractions of a second gains nothing and — when VAD
    /// misjudged a quiet word — actively destroys speech. In the most common flow
    /// (hotkey pressed right after the last word) the tail silence is well under
    /// this, so nothing is cut at all.
    static let minEdgeCutSeconds: Double = 1.0

    /// Two-threshold (hysteresis) VAD. Speech is *found* with the hard threshold
    /// (EnergyVAD's default 0.02), but the edges are then *extended* through frames
    /// that clear the soft threshold. Phrase endings decay in volume: the last
    /// word of a sentence often meters between these two values, and with a single
    /// hard threshold it reads as silence — so a pause before the hotkey press
    /// put it inside the trimmed region. The soft threshold sits above a quiet
    /// room's noise floor, so real silence still ends the extension.
    static let hardEnergyThreshold: Float = 0.02
    static let softEnergyThreshold: Float = 0.008

    /// Cap on how far an edge can be extended through soft-threshold frames, so
    /// steady background noise (fan, street) can't defeat trimming entirely.
    static let maxSoftExtensionSeconds: Double = 3.0

    /// VAD frame length in seconds (EnergyVAD's default).
    static let vadFrameSeconds: Double = 0.1

    /// Recordings at or below this length are passed through untouched. Single-word
    /// dictations are often under ~2.5s, and on such a short clip EnergyVAD can easily
    /// mis-bound the one word and trim away most of it, leaving nothing for the decoder
    /// (symptom: a one-word recording transcribes to empty). Trailing-silence
    /// hallucinations are a long-recording problem anyway, so there's nothing to gain
    /// from trimming here.
    static let minTrimDurationSeconds: Double = 2.5

    /// Whether a buffer of `sampleCount` samples is long enough to trim. Pure and
    /// testable without loading WhisperKit.
    static func shouldTrim(
        sampleCount: Int,
        sampleRate: Int,
        minDurationSeconds: Double = minTrimDurationSeconds
    ) -> Bool {
        guard sampleCount > 0, sampleRate > 0 else { return false }
        return Double(sampleCount) / Double(sampleRate) > minDurationSeconds
    }

    /// Trims edge silence. If no voice is detected (VAD finds no active segments) the
    /// array is returned unchanged — deciding "this is silence" is left to the layers
    /// above (the `hadVoiceActivity` gate and Whisper's own thresholds).
    static func trim(
        _ samples: [Float],
        sampleRate: Int = 16000
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }
        // Leave short recordings (single-word dictations) completely alone.
        guard shouldTrim(sampleCount: samples.count, sampleRate: sampleRate) else {
            return samples
        }

        let frameLength = Float(vadFrameSeconds)
        let hardFrames = EnergyVAD(
            sampleRate: sampleRate, frameLength: frameLength, energyThreshold: hardEnergyThreshold
        ).voiceActivity(in: samples)
        let softFrames = EnergyVAD(
            sampleRate: sampleRate, frameLength: frameLength, energyThreshold: softEnergyThreshold
        ).voiceActivity(in: samples)
        let maxExtensionFrames = Int(maxSoftExtensionSeconds / vadFrameSeconds)
        guard let frameRange = voicedFrameRange(
            hard: hardFrames,
            soft: softFrames,
            maxExtensionFrames: maxExtensionFrames
        ) else {
            return samples
        }

        let frameSamples = Int(vadFrameSeconds * Double(sampleRate))
        let activeChunk = (
            startIndex: frameRange.lowerBound * frameSamples,
            endIndex: min(samples.count, frameRange.upperBound * frameSamples)
        )
        guard let range = voiceRange(
            activeChunks: [activeChunk],
            totalSamples: samples.count,
            sampleRate: sampleRate
        ) else {
            return samples
        }
        let guarded = applyMinEdgeCut(
            to: range,
            totalSamples: samples.count,
            sampleRate: sampleRate
        )
        // Nothing to gain if the range already spans the whole buffer.
        guard guarded.lowerBound > 0 || guarded.upperBound < samples.count else {
            return samples
        }
        return Array(samples[guarded])
    }

    /// Pure hysteresis core: the frame range from the first to the last frame that
    /// clears the hard threshold, with each edge extended outward through frames
    /// that clear the soft threshold (up to `maxExtensionFrames` per edge).
    /// Returns `nil` when no frame clears the hard threshold.
    static func voicedFrameRange(
        hard: [Bool],
        soft: [Bool],
        maxExtensionFrames: Int
    ) -> Range<Int>? {
        guard hard.count == soft.count,
              let firstHard = hard.firstIndex(of: true),
              let lastHard = hard.lastIndex(of: true) else {
            return nil
        }

        var start = firstHard
        var extended = 0
        while start > 0, soft[start - 1], extended < maxExtensionFrames {
            start -= 1
            extended += 1
        }

        var end = lastHard
        extended = 0
        while end + 1 < soft.count, soft[end + 1], extended < maxExtensionFrames {
            end += 1
            extended += 1
        }

        return start..<(end + 1)
    }

    /// Per-edge guard: an edge cut smaller than `minEdgeCutSeconds` is dropped and
    /// that edge is kept whole. Pure and testable.
    static func applyMinEdgeCut(
        to range: Range<Int>,
        totalSamples: Int,
        sampleRate: Int,
        minEdgeCutSeconds: Double = minEdgeCutSeconds
    ) -> Range<Int> {
        let minCut = Int(minEdgeCutSeconds * Double(sampleRate))
        let start = range.lowerBound >= minCut ? range.lowerBound : 0
        let end = (totalSamples - range.upperBound) >= minCut ? range.upperBound : totalSamples
        return start..<end
    }

    /// Pure, testable core: the sample range from the start of the first voiced segment
    /// to the end of the last one, padded by `edgePaddingSeconds` at the front and
    /// `trailingPaddingSeconds` at the back, clamped to the buffer. Returns `nil` when
    /// there are no active segments.
    static func voiceRange(
        activeChunks: [(startIndex: Int, endIndex: Int)],
        totalSamples: Int,
        sampleRate: Int,
        edgePaddingSeconds: Double = edgePaddingSeconds,
        trailingPaddingSeconds: Double = trailingPaddingSeconds
    ) -> Range<Int>? {
        guard let first = activeChunks.first, let last = activeChunks.last else {
            return nil
        }
        let leadingPadding = Int(edgePaddingSeconds * Double(sampleRate))
        let trailingPadding = Int(trailingPaddingSeconds * Double(sampleRate))
        let start = max(0, first.startIndex - leadingPadding)
        let end = min(totalSamples, last.endIndex + trailingPadding)
        guard start < end else { return nil }
        return start..<end
    }
}
