import CryptoKit
import Foundation
import UIKit

/// One-time values for the sign-in flows (SPEC §10.2). None of them is stored.
nonisolated enum SignInSecrets {
    /// 32 random bytes, base64url without padding (43 characters).
    static func randomToken(byteCount: Int = 32) -> String {
        SymmetricKey(size: SymmetricKeySize(bitCount: byteCount * 8)).withUnsafeBytes { Data($0) }.base64URLEncoded
    }

    /// Sign in with Apple: the app keeps the raw nonce and gives Apple its SHA-256 (hex);
    /// the Worker checks the token's `nonce` claim against SHA-256 of what the app sends.
    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Google on iOS (DECISIONS 161): the challenge is base64url(SHA-256(verifier)).
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    /// The name shown in Profile → Devices: model and OS (`DeviceInfo`).
    @MainActor static var deviceName: String {
        DeviceInfo.name
    }
}

nonisolated extension Data {
    var base64URLEncoded: String {
        base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
    }

    init?(base64URLEncoded text: String) {
        var base64 = text.replacing("-", with: "+").replacing("_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
