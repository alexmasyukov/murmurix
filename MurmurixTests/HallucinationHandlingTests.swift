import Testing
@testable import Murmurix

// Covers the two layers that suppress Whisper's trailing-silence hallucinations:
// the deterministic phrase post-filter (HallucinationFilter) and the pure
// silence-trim geometry (SilenceTrimmer.voiceRange).

struct HallucinationFilterTests {

    @Test func stripsTrailingFillerWithEllipsis() {
        let result = HallucinationFilter.clean("Это реальный текст. Продолжение следует...")
        #expect(result == "Это реальный текст.")
    }

    @Test func stripsTrailingFillerWithoutPunctuationSeparator() {
        let result = HallucinationFilter.clean("Привет мир Спасибо за просмотр")
        #expect(result == "Привет мир")
    }

    @Test func stripsMultipleStackedFillerPhrases() {
        let result = HallucinationFilter.clean("Настоящий текст. Спасибо за просмотр. Продолжение следует...")
        #expect(result == "Настоящий текст.")
    }

    @Test func stripsSubtitleAuthorCredit() {
        let result = HallucinationFilter.clean("Мой доклад окончен. Субтитры сделал DimaTorzok")
        #expect(result == "Мой доклад окончен.")
    }

    @Test func isCaseInsensitive() {
        let result = HallucinationFilter.clean("Текст. СПАСИБО ЗА ПРОСМОТР!")
        #expect(result == "Текст.")
    }

    @Test func returnsEmptyWhenTextIsOnlyHallucination() {
        let result = HallucinationFilter.clean("Продолжение следует...")
        #expect(result.isEmpty)
    }

    @Test func leavesCleanTextUntouched() {
        let text = "Обычное осмысленное предложение без мусора."
        #expect(HallucinationFilter.clean(text) == text)
    }

    @Test func doesNotStripPhraseThatIsNotAtTheEnd() {
        // The filler words appear mid-sentence, not as a trailing tag — must be kept.
        let text = "Спасибо за просмотр, теперь перейдём к делу"
        #expect(HallucinationFilter.clean(text) == text)
    }

    @Test func doesNotTouchLegitimateSentenceContainingThePhraseWords() {
        let text = "Я хочу сказать спасибо за просмотр моего доклада"
        #expect(HallucinationFilter.clean(text) == text)
    }

    // MARK: - Interior (mid-text) filler removal
    // Whisper hallucinates over long *pauses* mid-dictation too; the audio path
    // deliberately leaves internal pauses alone, so the text filter must catch these.

    @Test func stripsStandaloneFillerInTheMiddle() {
        let result = HallucinationFilter.clean(
            "Странноватая тема. Продолжение следует... Давай сделаем холодный старт."
        )
        #expect(result == "Странноватая тема. Давай сделаем холодный старт.")
    }

    @Test func stripsMultipleInteriorFillers() {
        let result = HallucinationFilter.clean(
            "Первая мысль. Продолжение следует... Вторая мысль. Спасибо за просмотр! Третья мысль."
        )
        #expect(result == "Первая мысль. Вторая мысль. Третья мысль.")
    }

    @Test func stripsInteriorFillerAtTextStart() {
        let result = HallucinationFilter.clean("Продолжение следует... Привет, начнём работу.")
        #expect(result == "Привет, начнём работу.")
    }

    @Test func keepsInteriorPhraseFollowedByLowercase() {
        // Lowercase continuation means the user's own sentence goes on — keep it.
        let text = "Тема закрыта. Продолжение следует и будет интересным."
        #expect(HallucinationFilter.clean(text) == text)
    }

    @Test func keepsInteriorPhraseWithoutSentenceBoundaryBefore() {
        let text = "Я хочу сказать спасибо за просмотр моего доклада. Дальше по делу."
        #expect(HallucinationFilter.clean(text) == text)
    }

    @Test func keepsInteriorPhraseFollowedByComma() {
        let text = "Вот так. Спасибо за просмотр, теперь перейдём к делу. Конец."
        #expect(HallucinationFilter.clean(text) == text)
    }

    @Test func handlesEmptyInput() {
        #expect(HallucinationFilter.clean("") == "")
    }

    @Test func handlesWhitespaceOnlyInput() {
        #expect(HallucinationFilter.clean("   \n ") == "")
    }
}

struct SilenceTrimmerTests {
    private let sampleRate = AudioConfig.whisperSampleRate // 16_000

    @Test func voiceRangePadsAroundSingleSegment() {
        // Voice from 1.0s to 2.0s in a 5s buffer: 0.2s leading pad => 0.8s,
        // 0.5s trailing pad => 2.5s.
        let range = SilenceTrimmer.voiceRange(
            activeChunks: [(startIndex: 16_000, endIndex: 32_000)],
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(range == 12_800..<40_000)
    }

    @Test func voiceRangeSpansFromFirstToLastSegment() {
        let range = SilenceTrimmer.voiceRange(
            activeChunks: [
                (startIndex: 16_000, endIndex: 20_000),
                (startIndex: 50_000, endIndex: 60_000)
            ],
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        // start of first (16_000) - 3_200 = 12_800; end of last (60_000) + 8_000 = 68_000
        #expect(range == 12_800..<68_000)
    }

    @Test func minEdgeCutKeepsTailWhenTrailingSilenceIsShort() {
        // Hotkey pressed right after the last word: only 0.5s of buffer lies beyond
        // the padded range — under the 1s minimum, so the tail is kept whole and a
        // quiet last word misjudged by VAD survives.
        let guarded = SilenceTrimmer.applyMinEdgeCut(
            to: 0..<72_000,
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(guarded == 0..<80_000)
    }

    @Test func minEdgeCutStillTrimsLongSilentTail() {
        // 3s of silence beyond the padded range — over the 1s minimum, trim applies.
        let guarded = SilenceTrimmer.applyMinEdgeCut(
            to: 0..<32_000,
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(guarded == 0..<32_000)
    }

    @Test func minEdgeCutGuardsEachEdgeIndependently() {
        // Leading cut is 2s (kept), trailing cut is 0.5s (dropped).
        let guarded = SilenceTrimmer.applyMinEdgeCut(
            to: 32_000..<72_000,
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(guarded == 32_000..<80_000)
    }

    @Test func minEdgeCutKeepsShortLeadingSilence() {
        // Leading cut of 0.9s — just under the minimum, start kept at 0.
        let guarded = SilenceTrimmer.applyMinEdgeCut(
            to: 14_400..<48_000,
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(guarded == 0..<48_000)
    }

    @Test func voiceRangeClampsPaddingToBufferBounds() {
        let range = SilenceTrimmer.voiceRange(
            activeChunks: [(startIndex: 1_000, endIndex: 79_000)],
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(range == 0..<80_000)
    }

    @Test func voiceRangeIsNilWhenNoVoiceDetected() {
        let range = SilenceTrimmer.voiceRange(
            activeChunks: [],
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(range == nil)
    }

    @Test func shortRecordingsAreNotTrimmed() {
        // 1s single-word dictation — must be left untouched.
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 16_000, sampleRate: sampleRate) == false)
        // Exactly at the 2.5s threshold — still not trimmed (boundary is exclusive).
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 40_000, sampleRate: sampleRate) == false)
    }

    @Test func longerRecordingsAreTrimmed() {
        // 2.6s — just over the threshold, trimming applies.
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 41_600, sampleRate: sampleRate) == true)
        // 60s long recording.
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 960_000, sampleRate: sampleRate) == true)
    }

    @Test func shouldTrimHandlesDegenerateInput() {
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 0, sampleRate: sampleRate) == false)
        #expect(SilenceTrimmer.shouldTrim(sampleCount: 16_000, sampleRate: 0) == false)
    }

    // MARK: - Hysteresis (two-threshold) edge detection
    // Phrase endings decay in volume: the last word often clears only the soft
    // threshold, and a single hard threshold would trim it as "silence".

    @Test func voicedFrameRangeExtendsTrailingEdgeThroughQuietSpeech() {
        // Frames: silence, loud speech, trailing quiet speech (soft only), silence.
        let hard = [false, true, true, false, false, false]
        let soft = [false, true, true, true, true, false]
        let range = SilenceTrimmer.voicedFrameRange(hard: hard, soft: soft, maxExtensionFrames: 30)
        #expect(range == 1..<5)
    }

    @Test func voicedFrameRangeExtendsLeadingEdgeThroughQuietSpeech() {
        // Quiet attack of the first word before it clears the hard threshold.
        let hard = [false, false, true, true, false]
        let soft = [false, true, true, true, false]
        let range = SilenceTrimmer.voicedFrameRange(hard: hard, soft: soft, maxExtensionFrames: 30)
        #expect(range == 1..<4)
    }

    @Test func voicedFrameRangeCapsExtensionAgainstSteadyNoise() {
        // Steady background noise clears the soft threshold everywhere; the cap
        // keeps trimming useful.
        let hard = [false, false, false, true, false, false, false, false]
        let soft = [Bool](repeating: true, count: 8)
        let range = SilenceTrimmer.voicedFrameRange(hard: hard, soft: soft, maxExtensionFrames: 2)
        // Hard frame at 3, cap 2 per edge: start 3→1, end 3→5 (half-open 1..<6).
        #expect(range == 1..<6)
    }

    @Test func voicedFrameRangeNilWithoutHardSpeech() {
        let soft = [true, true, true]
        let hard = [false, false, false]
        #expect(SilenceTrimmer.voicedFrameRange(hard: hard, soft: soft, maxExtensionFrames: 30) == nil)
    }

    @Test func voicedFrameRangeStopsExtensionAtRealSilence() {
        // A genuine pause (below soft) before the hotkey press: no extension.
        let hard = [true, true, false, false]
        let soft = [true, true, false, false]
        let range = SilenceTrimmer.voicedFrameRange(hard: hard, soft: soft, maxExtensionFrames: 30)
        #expect(range == 0..<2)
    }
}
