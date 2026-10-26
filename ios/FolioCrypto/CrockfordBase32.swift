import Foundation

/// Crockford base32 (https://www.crockford.com/base32.html), used for the human-readable
/// recovery key. Decoding is forgiving: case-insensitive, ignores hyphens and spaces, and
/// reads O as 0 and I/L as 1.
enum CrockfordBase32 {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func encode(_ bytes: some Sequence<UInt8>) -> String {
        var output = ""
        var buffer: UInt32 = 0
        var bits = 0
        for byte in bytes {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                output.append(alphabet[Int((buffer >> UInt32(bits - 5)) & 31)])
                bits -= 5
            }
            buffer &= (1 << UInt32(bits)) - 1
        }
        if bits > 0 {
            output.append(alphabet[Int((buffer << UInt32(5 - bits)) & 31)])
        }
        return output
    }

    /// Decodes exactly `byteCount` bytes; any leftover padding bits must be zero.
    static func decode(_ text: String, byteCount: Int) -> Data? {
        var buffer: UInt32 = 0
        var bits = 0
        var output = Data()
        for character in text.uppercased() where character != "-" && !character.isWhitespace {
            guard let value = value(of: character) else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bits += 5
            if bits >= 8 {
                output.append(UInt8((buffer >> UInt32(bits - 8)) & 0xFF))
                bits -= 8
                buffer &= (1 << UInt32(bits)) - 1
            }
        }
        guard output.count == byteCount, buffer == 0 else { return nil }
        return output
    }

    private static func value(of character: Character) -> Int? {
        switch character {
        case "O": 0
        case "I", "L": 1
        default: alphabet.firstIndex(of: character)
        }
    }
}
