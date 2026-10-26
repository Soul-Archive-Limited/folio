import Foundation
import Testing

/// Decodes `shared/crypto-vectors.json` (generated with WebCrypto by
/// `scripts/generate-crypto-vectors.mjs`).
struct CryptoVectors: Decodable {
    struct Record: Decodable {
        let recordId: String
        let recordType: String
        let nonce: String
        let plaintext: String
        let userId: String
        let ciphertextAndTag: String
    }

    struct Envelope: Decodable {
        let nonce: String
        let ciphertextAndTag: String
    }

    struct Recovery: Decodable {
        let keyBytes: String
        let keyString: String
        let keyDisplay: String
        let kekSalt: String
        let kek: String
        let envelope: Envelope
    }

    struct Base32: Decodable {
        let bytes: String
        let encoded: String
    }

    struct Link: Decodable {
        let requestId: String
        let userId: String
        let newDevicePrivateKey: String
        let newDevicePublicKey: String
        let senderPrivateKey: String
        let senderPublicKey: String
        let linkKey: String
        let nonce: String
        let ciphertextAndTag: String
    }

    let dataKey: String
    let records: [Record]
    let recovery: Recovery
    let base32: [Base32]
    let link: Link

    static func load() throws -> CryptoVectors {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "crypto-vectors", withExtension: "json"))
        return try JSONDecoder().decode(CryptoVectors.self, from: Data(contentsOf: url))
    }
}

private final class BundleToken {}

extension Data {
    init(hex: String) {
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        self = data
    }

    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
