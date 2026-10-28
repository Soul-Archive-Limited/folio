import Foundation
import os
import Synchronization

/// HTTPS client for `https://folio.devilsense.com/api` (SPEC §10.1). Sends the session token as
/// a Bearer header, never cookies, and keeps no cache: responses are either ciphertext or
/// account details that shouldn't sit on disk.
nonisolated final class APIClient: Sendable {
    static let productionBaseURL = URL(string: "https://folio.devilsense.com/api/")!

    let baseURL: URL
    private let session: URLSession
    private let token = Mutex<String?>(nil)
    private static let logger = Logger(subsystem: "com.devilsense.folio", category: "api")

    init(baseURL: URL = APIClient.configuredBaseURL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": "Folio-iOS"]
        session = URLSession(configuration: configuration)
    }

    /// DEBUG builds can point at `wrangler dev` with `-FolioAPIBase http://localhost:8787/api/`.
    static var configuredBaseURL: URL {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "FolioAPIBase"), let url = URL(string: raw) { return url }
        #endif
        return productionBaseURL
    }

    var webSocketURL: URL {
        var components = URLComponents(url: baseURL.appending(path: "live"), resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "http" ? "ws" : "wss"
        return components?.url ?? baseURL
    }

    func setToken(_ value: String?) {
        token.withLock { $0 = value }
    }

    var currentToken: String? { token.withLock { $0 } }

    // MARK: JSON

    func send<Response: Decodable>(_ method: String, _ path: String, as type: Response.Type = Response.self) async throws(APIError) -> Response {
        try decode(await data(for: request(method, path)))
    }

    func send<Response: Decodable>(_ method: String, _ path: String, json: some Encodable, as type: Response.Type = Response.self) async throws(APIError) -> Response {
        var request = request(method, path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder.api.encode(json)
        } catch {
            throw .invalidResponse
        }
        return try decode(await data(for: request))
    }

    // MARK: Blobs

    func uploadBlob(_ id: String, data body: Data) async throws(APIError) {
        var request = request("PUT", "blobs/\(id)")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        _ = try await data(for: request)
    }

    func downloadBlob(_ id: String) async throws(APIError) -> Data {
        try await data(for: request("GET", "blobs/\(id)"))
    }

    // MARK: Plumbing

    func request(_ method: String, _ path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL) ?? baseURL)
        request.httpMethod = method
        if let token = currentToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func data(for request: URLRequest) async throws(APIError) -> Data {
        RequestBudget.count()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .offline
        }
        guard let http = response as? HTTPURLResponse else { throw .invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw .unauthorized
        case 429, 503:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            // 503 web_email_disabled isn't a temporary condition.
            if http.statusCode == 503, code != nil, retry == nil { throw .server(status: 503, code: code) }
            throw .rateLimited(retryAfter: retry)
        default:
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            Self.logger.notice("API \(http.statusCode, privacy: .public) \(code ?? "-", privacy: .public)")
            throw .server(status: http.statusCode, code: code)
        }
    }

    private func decode<Response: Decodable>(_ data: Data) throws(APIError) -> Response {
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            throw .invalidResponse
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}

nonisolated extension JSONEncoder {
    /// Base64 for `Data` (the API's `base64Text`), plain numbers for times.
    static var api: JSONEncoder { JSONEncoder() }
}

nonisolated extension JSONDecoder {
    static var api: JSONDecoder { JSONDecoder() }
}

/// An empty JSON answer (`{"ok": true}` and friends).
nonisolated struct OKResponse: Decodable, Sendable {}
