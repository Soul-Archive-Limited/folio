import Foundation

/// The foreground WebSocket to the account's `UserHub` (SPEC §10.5). It only ever carries
/// `{"cursor": N}` — "something changed, pull if you're behind" — never content. Keep-alive
/// pings are answered by the hub's auto-response, so they don't wake or bill it.
final class LiveSocket {
    var onCursor: ((Int64) -> Void)?
    /// Called once when the socket ends; `rejected` is true when the server refused the
    /// upgrade (401/403 — the session was signed out or the account deleted elsewhere).
    var onClose: ((_ rejected: Bool) -> Void)?

    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private var receiving: Task<Void, Never>?
    private var pinging: Task<Void, Never>?
    private var closed = false

    init(url: URL, token: String) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        task = session.webSocketTask(with: request)
    }

    func connect() {
        RequestBudget.count()
        task.resume()
        receiving = Task { [weak self] in await self?.receiveLoop() }
        pinging = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                try? await self.task.send(.string("ping"))
            }
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        receiving?.cancel()
        pinging?.cancel()
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                break
            }
            guard case .string(let text) = message, text != "pong",
                  let decoded = try? JSONDecoder().decode(SyncWire.LiveMessage.self, from: Data(text.utf8)) else { continue }
            if let cursor = decoded.cursor { onCursor?(cursor) }
        }
        guard !closed else { return }
        let status = (task.response as? HTTPURLResponse)?.statusCode
        close()
        onClose?(status == 401 || status == 403)
    }
}
