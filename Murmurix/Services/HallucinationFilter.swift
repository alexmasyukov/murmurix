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

    /// Removes known filler phrases repeatedly from the tail of `text` until none match.
    /// A phrase is only stripped when it sits at the very end and is preceded by a word
    /// boundary (start of text or a non-letter), so legitimate speech that merely
    /// contains the same words mid-sentence is never touched.
    static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while stripTrailingPhrase(&result) {
            // keep peeling as long as the new tail is also a known phrase
        }
        return result
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
