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
        // Voice from 1.0s to 2.0s in a 5s buffer, 0.2s padding => 0.8s..2.2s.
        let range = SilenceTrimmer.voiceRange(
            activeChunks: [(startIndex: 16_000, endIndex: 32_000)],
            totalSamples: 80_000,
            sampleRate: sampleRate
        )
        #expect(range == 12_800..<35_200)
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
        // start of first (16_000) - 3_200 = 12_800; end of last (60_000) + 3_200 = 63_200
        #expect(range == 12_800..<63_200)
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
}
