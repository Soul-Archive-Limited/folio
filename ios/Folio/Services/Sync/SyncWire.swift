import Foundation

/// `/api/sync` shapes (SPEC §10.5, api/src/routes/sync.ts). Ciphertext and nonce are base64.
nonisolated enum SyncWire {
    static let maxChangesPerPush = 200
    /// The Worker refuses bodies over 1 MB; stay well under with base64 and JSON overhead.
    static let maxPushBytes = 700_000

    struct Change: Encodable, Sendable {
        let id: UUID
        let type: String
        let ciphertext: String
        let nonce: String
        let clientUpdatedAt: Int64
        let baseVersion: Int64?
        let deleted: Bool

        /// Approximate JSON size, for batching under the body limit.
        var approximateBytes: Int { ciphertext.utf8.count + nonce.utf8.count + 160 }
    }

    struct Push: Encodable, Sendable {
        let changes: [Change]
    }

    struct Accepted: Decodable, Sendable {
        let id: UUID
        let version: Int64
    }

    struct PushResult: Decodable, Sendable {
        let accepted: [Accepted]
        let conflicts: [Remote]
        let cursor: Int64
    }

    /// A record as the server has it.
    struct Remote: Decodable, Sendable {
        let id: UUID
        let type: String
        let version: Int64
        let ciphertext: String
        let nonce: String
        let clientUpdatedAt: Int64
        let deleted: Bool
    }

    struct PullResult: Decodable, Sendable {
        let changes: [Remote]
        let cursor: Int64
        let hasMore: Bool
    }

    /// `{"cursor": N}` from the live socket, or `{"link": id}` when a link was approved.
    struct LiveMessage: Decodable, Sendable {
        let cursor: Int64?
        let link: String?
    }
}

extension Date {
    /// Milliseconds since 1970, the API's `clientUpdatedAt`.
    nonisolated var millisecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    nonisolated init(millisecondsSince1970 value: Int64) {
        self.init(timeIntervalSince1970: Double(value) / 1000)
    }
}
