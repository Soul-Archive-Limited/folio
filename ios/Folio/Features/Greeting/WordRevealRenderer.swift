import SwiftUI

/// Reveals text word by word, each word going from blurred and clear to sharp and
/// opaque (SPEC §4.2: 40 ms per word). Drawing-only, so wrapping, Dynamic Type and
/// VoiceOver all see one ordinary `Text`.
struct WordRevealRenderer: TextRenderer, Animatable {
    /// Seconds since the reveal began.
    var elapsed: Double

    static let perWord: Double = 0.04
    static let wordDuration: Double = 0.28
    static let maxBlur: Double = 8

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    static func totalDuration(wordCount: Int) -> Double {
        Double(max(wordCount - 1, 0)) * perWord + wordDuration
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                let index = run[WordIndexAttribute.self]?.index ?? 0
                let progress = min(max((elapsed - Double(index) * Self.perWord) / Self.wordDuration, 0), 1)
                var copy = context
                copy.opacity = progress
                if progress < 1 {
                    copy.addFilter(.blur(radius: (1 - progress) * Self.maxBlur))
                }
                copy.draw(run)
            }
        }
    }

    /// Builds a `Text` whose words carry `WordIndexAttribute`s.
    static func text(_ string: String) -> (text: Text, wordCount: Int) {
        let words = string.split(separator: " ", omittingEmptySubsequences: true)
        var result = Text(verbatim: "")
        for (index, word) in words.enumerated() {
            let piece = Text(verbatim: index == words.count - 1 ? String(word) : "\(word) ")
                .customAttribute(WordIndexAttribute(index: index))
            result = Text("\(result)\(piece)")
        }
        return (result, words.count)
    }
}
