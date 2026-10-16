//
//  AvroKeyboard
//
//  Copyright (c) 2026 Saiful Islam. All rights reserved.
//

import Foundation

/// Full old style (typewriter) typing for the fixed layouts, as in Avro Keyboard for Windows.
///
/// Vowel signs and the reph are typed in the order they are drawn: ি, ে and ৈ before their
/// consonant, and the reph after the consonant it sits on. This puts the text back in
/// logical (Unicode) order, so `ে` `ক` gives কে and `ক` `র্` gives র্ক.
///
/// It works on what each key of the current word typed, and is replayed from the start
/// whenever the word changes, so removing the last key is simply typing one key fewer.
enum OldStyleTyping {
    /// The text `units` type in old style order, each unit being what one key typed.
    ///
    /// A prebase vowel sign still waiting for its consonant is left at the end, as typed.
    static func reorder(_ units: [String]) -> String {
        var text: [Unicode.Scalar] = []
        var pending: Unicode.Scalar?

        for unit in units {
            let scalars = Array(unit.unicodeScalars)
            guard let first = scalars.first else { continue }

            if let kar = pending {
                if scalars.count == 1, prebase.contains(first) {
                    // The same sign twice types it on its own; another one replaces it.
                    if first == kar {
                        text.append(kar)
                        pending = nil
                    } else {
                        pending = first
                    }
                } else if scalars == [hasanta] {
                    // The consonant before it joins the next one, which takes the sign.
                    text.append(hasanta)
                } else if scalars == reph {
                    insertReph(into: &text)
                    text.append(kar)
                    pending = nil
                } else if kar == eKar, scalars == [aaKar] {
                    text.append(oKar)
                    pending = nil
                } else if kar == eKar, scalars == [auLengthMark] {
                    text.append(auKar)
                    pending = nil
                } else {
                    text += scalars
                    text.append(kar)
                    pending = nil
                }
                continue
            }

            if scalars.count == 1, prebase.contains(first) {
                pending = first
            } else if scalars == [hasanta] {
                // A prebase sign moves on to the end of the conjunct.
                if let last = text.last, prebase.contains(last) {
                    pending = text.removeLast()
                }
                text.append(hasanta)
            } else if scalars == reph {
                insertReph(into: &text)
            } else if scalars == [aaKar] || scalars == [auLengthMark] {
                appendLengthMark(first, to: &text)
            } else if isPhala(scalars), let last = text.last, kars.contains(last) {
                // ্র, ্য and র‍্য belong before the vowel sign of their consonant.
                text.removeLast()
                text += scalars
                text.append(last)
            } else {
                text += scalars
            }
        }

        if let kar = pending {
            text.append(kar)
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: text)
        return result
    }

    // MARK: - Rules

    /// Adds া or ৗ, joining it to a ে before it (with or without a chandrabindu) to make ো
    /// or ৌ, and া to অ to make আ.
    private static func appendLengthMark(_ mark: Unicode.Scalar, to text: inout [Unicode.Scalar]) {
        let joined = mark == aaKar ? oKar : auKar
        if text.last == eKar {
            text[text.count - 1] = joined
        } else if text.count >= 2, text.last == chandrabindu, text[text.count - 2] == eKar {
            text[text.count - 2] = joined
        } else if mark == aaKar, text.last == letterA {
            text[text.count - 1] = letterAA
        } else {
            text.append(mark)
        }
    }

    /// Puts a reph before the conjunct it was typed after, which may end in a vowel sign
    /// and a chandrabindu, or adds it as is when there is no consonant to carry it.
    private static func insertReph(into text: inout [Unicode.Scalar]) {
        var index = text.count - 1
        if index >= 0, text[index] == chandrabindu {
            index -= 1
        }
        if index >= 0, kars.contains(text[index]) {
            index -= 1
        }
        guard index >= 0, isConsonant(text[index]) else {
            text += reph
            return
        }
        // Walk back over the rest of the conjunct.
        while index >= 2, text[index - 1] == hasanta, isConsonant(text[index - 2]) {
            index -= 2
        }
        text.insert(contentsOf: reph, at: index)
    }

    // MARK: - Characters

    private static let hasanta: Unicode.Scalar = "\u{09CD}"
    private static let reph: [Unicode.Scalar] = ["\u{09B0}", hasanta]
    private static let chandrabindu: Unicode.Scalar = "\u{0981}"
    private static let letterA: Unicode.Scalar = "\u{0985}"
    private static let letterAA: Unicode.Scalar = "\u{0986}"
    private static let aaKar: Unicode.Scalar = "\u{09BE}"
    private static let eKar: Unicode.Scalar = "\u{09C7}"
    private static let oKar: Unicode.Scalar = "\u{09CB}"
    private static let auKar: Unicode.Scalar = "\u{09CC}"
    private static let auLengthMark: Unicode.Scalar = "\u{09D7}"
    private static let zwj: Unicode.Scalar = "\u{200D}"

    /// The vowel signs drawn before their consonant: ি, ে and ৈ.
    private static let prebase: Set<Unicode.Scalar> = ["\u{09BF}", "\u{09C7}", "\u{09C8}"]

    /// Every vowel sign: া ি ী ু ূ ৃ ে ৈ ো ৌ.
    private static let kars: Set<Unicode.Scalar> = [
        "\u{09BE}", "\u{09BF}", "\u{09C0}", "\u{09C1}", "\u{09C2}",
        "\u{09C3}", "\u{09C7}", "\u{09C8}", "\u{09CB}", "\u{09CC}",
    ]

    /// ক to হ, ড় ঢ় য়, and khanda ta.
    private static func isConsonant(_ scalar: Unicode.Scalar) -> Bool {
        (0x0995...0x09B9).contains(scalar.value) || [0x09CE, 0x09DC, 0x09DD, 0x09DF].contains(scalar.value)
    }

    /// A hasanta and a consonant typed by one key, like ্র and ্য, optionally after a
    /// joiner as in র‍্য.
    private static func isPhala(_ scalars: [Unicode.Scalar]) -> Bool {
        let rest = scalars.first == zwj ? Array(scalars.dropFirst()) : scalars
        return rest.count >= 2 && rest[0] == hasanta && isConsonant(rest[1])
    }
}
