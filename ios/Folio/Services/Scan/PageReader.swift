import Foundation
import Vision

/// Reads scanned diary pages on the device (Batch J): Vision's text recognition, top to bottom,
/// English and Hindi where the OS supports them, plus the device's own language. Nothing is
/// sent anywhere.
nonisolated enum PageReader {
    struct Result: Sendable {
        var pages: [String]
        var text: String { pages.filter { !$0.isEmpty }.joined(separator: "\n\n") }
    }

    static func read(_ images: [Data]) async -> Result {
        var pages: [String] = []
        for image in images {
            pages.append((try? await read(image)) ?? "")
        }
        return Result(pages: pages)
    }

    static func read(_ image: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = Set(request.supportedRecognitionLanguages.map { $0.minimalIdentifier })
        var wanted: [String] = []
        for code in [Locale.current.language.minimalIdentifier, "en", "hi"] where supported.contains(code) && !wanted.contains(code) {
            wanted.append(code)
        }
        if !wanted.isEmpty { request.recognitionLanguages = wanted.map { Locale.Language(identifier: $0) } }
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image)
        // Vision's boxes are normalised with the origin at the bottom left: read top down.
        return observations
            .sorted { $0.boundingBox.origin.y + $0.boundingBox.height > $1.boundingBox.origin.y + $1.boundingBox.height }
            // A line the recogniser isn't sure of is usually a script it can't read (Hindi on
            // iOS 26): leave it out rather than fill the page with noise; the scan photo keeps it.
            .compactMap { $0.topCandidates(1).first }
            .filter { $0.confidence >= 0.4 }
            .map(\.string)
            .joined(separator: "\n")
    }
}

/// Finds the date written on a page (Batch J) — usually at the top of a diary page — to suggest
/// it as the entry's day. Numeric dates are day first except in the US; written dates go
/// through `NSDataDetector`. Devanagari digits count. Only past (or tomorrow's) dates from 1900 on.
nonisolated enum PageDateFinder {
    static func suggest(in text: String, today: DayKey, monthFirst: Bool = Locale.current.region == .unitedStates) -> DayKey? {
        let head = String(asciiDigits(text).prefix(400))
        let candidates = numericDates(in: head, monthFirst: monthFirst) + detectedDates(in: head)
        return candidates
            .sorted { $0.offset < $1.offset }
            .map(\.day)
            .first { $0.year >= 1900 && $0 <= today.adding(days: 1) }
    }

    private static func asciiDigits(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar -> Character in
            if (0x0966...0x096F).contains(scalar.value), let ascii = UnicodeScalar(scalar.value - 0x0966 + 48) { return Character(ascii) }
            return Character(scalar)
        })
    }

    private static func numericDates(in text: String, monthFirst: Bool) -> [(offset: Int, day: DayKey)] {
        let pattern = /\b(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{4}|\d{2})\b/
        return text.matches(of: pattern).compactMap { match in
            guard let a = Int(match.1), let b = Int(match.2), var year = Int(match.3) else { return nil }
            if match.3.count == 2 { year += year > 50 ? 1900 : 2000 }
            let (month, day) = monthFirst ? (a, b) : (b, a)
            guard let key = DayKey(year: year, month: month, day: day) else { return nil }
            return (text.distance(from: text.startIndex, to: match.range.lowerBound), key)
        }
    }

    private static func detectedDates(in text: String) -> [(offset: Int, day: DayKey)] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        // The detector reads dates in the device's time zone.
        let calendar = Calendar.current
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let date = match.date else { return nil }
            // A bare weekday or time ("Monday", "at 6") isn't a page date: need a number and a month word or digits.
            let matched = (text as NSString).substring(with: match.range)
            guard matched.contains(where: \.isNumber), matched.count >= 5 else { return nil }
            // All-number dates are ours (day/month order, and no rolling 31/02 into March).
            if matched.wholeMatch(of: /\s*\d{1,4}[\/.\-]\d{1,2}[\/.\-]\d{1,4}\s*/) != nil { return nil }
            return (match.range.location, DayKey(date: date, calendar: calendar))
        }
    }
}
