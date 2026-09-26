//
//  HallucinationFilter.swift
//  Murmurix
//

import Foundation

/// Deterministic post-filter for the filler phrases Whisper appends at the end (and,
/// rarely, the start) of a transcription over silence.
///
/// These are memorized boilerplate endings of Russian YouTube subtitles baked into
/// Whisper's training data. Whisper's own thresholds (`noSpeechThreshold`,
/// `logProbThreshold`, `compressionRatioThreshold`) do not catch them: the phrase is
/// generated *confidently* (high logprob, low no-speech probability) and it does not
/// repeat, so compression ratio stays normal. Trimming edge silence removes most of
/// them at the source (see ``SilenceTrimmer``); this filter is the second, belt-and-
/// suspenders layer. Applied to local (WhisperKit) transcription only — the cloud
/// providers steer their output with prompts and don't exhibit this failure.
enum HallucinationFilter {
    /// Known filler phrases. Matching is case-insensitive and ignores trailing
    /// punctuation, so "..."/"!" variants don't need separate entries.
    static let knownPhrases: [String] = [
        "Продолжение следует",
        "Спасибо за просмотр",
        "Спасибо за внимание",
        "Спасибо за просмотр!",
        "Субтитры сделал DimaTorzok",
        "Субтитры создавал DimaTorzok",
        "Субтитры делал DimaTorzok",
        "Субтитры сделал Dima Torzok",
        "Редактор субтитров А.Синецкая",
        "Корректор А.Кулакова",
        "Субтитры делала DimaTorzok",
        "Подписывайтесь на канал",
        "Ставьте лайки",
        "Подписывайтесь",
        "До новых встреч",
    ]

    /// Characters ignored at the tail when matching a filler phrase — the trailing
    /// punctuation/whitespace Whisper puts *after* the phrase ("Продолжение следует...").
    private static let trailingJunk = CharacterSet(charactersIn: " \t\n\r.,!?…\"'«»)]-—–")

    /// Characters trimmed off the *kept* text after a filler phrase is removed. Note it
    /// deliberately excludes sentence-ending punctuation (`. ! ? …`): the period in
    /// "Это реальный текст. Продолжение следует..." belongs to the user's sentence, not
    /// to the filler, so it must survive. Only word separators are stripped.
    private static let trailingSeparators = CharacterSet(charactersIn: " \t\n\r,:;-—–")

    /// Removes known filler phrases from the text. Two passes:
    /// 1. Interior: a phrase standing as its own sentence in the middle of the text
    ///    (Whisper hallucinates over long *pauses* too, not just the trailing
    ///    silence — the audio path deliberately leaves internal pauses untouched,
    ///    so this is the only layer that can catch those).
    /// 2. Tail: peels phrases off the very end, looser boundary rules (no sentence
    ///    punctuation required), repeated until none match.
    /// Legitimate speech that merely contains the same words mid-sentence is never
    /// touched: interior removal requires sentence boundaries on both sides.
    static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        result = strippingStandaloneInteriorPhrases(result)
        while stripTrailingPhrase(&result) {
            // keep peeling as long as the new tail is also a known phrase
        }
        return result
    }

    // MARK: - Interior (mid-text) pass

    /// Sentence-ending characters that must precede an interior filler phrase.
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "…", "\n"]

    /// Characters consumed *after* an interior phrase when removing it: its own
    /// trailing punctuation and the whitespace up to the next sentence. Deliberately
    /// excludes the comma — "Спасибо за просмотр, теперь перейдём к делу" is the
    /// user's own sentence continuing, not a standalone filler.
    private static let interiorTrailingJunk: Set<Character> = [".", "!", "?", "…", " ", "\t", "\n"]

    /// Removes every known phrase that stands as its own sentence strictly inside the
    /// text: preceded by a sentence end (or the very start) and followed, after its
    /// own punctuation, by the start of a new sentence (an uppercase letter, an
    /// opening quote/dash) or the end of text. Anything less clearly delimited is
    /// left for the tail pass or kept as real speech.
    static func strippingStandaloneInteriorPhrases(_ text: String) -> String {
        var result = text
        var removedSomething = true
        while removedSomething {
            removedSomething = false
            phraseLoop: for phrase in knownPhrases {
                var searchStart = result.startIndex
                while searchStart < result.endIndex,
                      let range = result.range(
                        of: phrase,
                        options: [.caseInsensitive],
                        range: searchStart..<result.endIndex
                      ) {
                    if let removalEnd = interiorRemovalEnd(for: range, in: result) {
                        result.removeSubrange(range.lowerBound..<removalEnd)
                        removedSomething = true
                        break phraseLoop
                    }
                    searchStart = range.upperBound
                }
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates that `range` is a standalone interior sentence and returns the end
    /// of the region to remove (phrase + its trailing punctuation/whitespace), or
    /// `nil` when the occurrence must be kept.
    private static func interiorRemovalEnd(for range: Range<String.Index>, in text: String) -> String.Index? {
        // Before: skip whitespace backwards; require start of text or a sentence end.
        var before = range.lowerBound
        while before > text.startIndex {
            let prev = text.index(before: before)
            if text[prev].isWhitespace {
                before = prev
            } else {
                break
            }
        }
        if before > text.startIndex {
            let prev = text.index(before: before)
            guard sentenceEnders.contains(text[prev]) else { return nil }
        }

        // After: consume the phrase's own punctuation and whitespace.
        var end = range.upperBound
        while end < text.endIndex, interiorTrailingJunk.contains(text[end]) {
            end = text.index(after: end)
        }
        if end == text.endIndex {
            // Trailing occurrence — leave it to the tail pass with its looser rules.
            return nil
        }
        // No punctuation or whitespace after the match means it's part of a longer
        // word, not a standalone sentence.
        guard end > range.upperBound else { return nil }
        // Next visible character must start a new sentence. A lowercase letter or a
        // comma means the surrounding sentence continues and the words are real.
        let next = text[end]
        let sentenceOpeners: Set<Character> = ["«", "\"", "'", "—", "–", "-", "(", "„"]
        guard next.isUppercase || sentenceOpeners.contains(next) else { return nil }
        return end
    }

    /// Attempts to strip a single known phrase from the tail of `text`. Returns `true`
    /// if it removed one (so the caller loops again), `false` otherwise.
    private static func stripTrailingPhrase(_ text: inout String) -> Bool {
        let trimmed = trimTrailingJunk(text)
        guard !trimmed.isEmpty else {
            text = trimmed
            return false
        }

        for phrase in knownPhrases {
            guard let range = trimmed.range(
                of: phrase,
                options: [.caseInsensitive, .backwards, .anchored]
            ) else {
                continue
            }

            // Reject partial-word matches: the char before the phrase must be a
            // boundary (start of string or a non-letter). This keeps e.g.
            // "...пересмотрел" from matching "смотрел"-style suffixes.
            if range.lowerBound != trimmed.startIndex {
                let before = trimmed[trimmed.index(before: range.lowerBound)]
                if before.isLetter { continue }
            }

            text = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: trailingSeparators)
            return true
        }

        return false
    }

    private static func trimTrailingJunk(_ text: String) -> String {
        var end = text.endIndex
        while end > text.startIndex {
            let prev = text.index(before: end)
            guard let scalar = text[prev].unicodeScalars.first,
                  text[prev].unicodeScalars.count == 1,
                  trailingJunk.contains(scalar) else {
                break
            }
            end = prev
        }
        return String(text[..<end])
    }
}
