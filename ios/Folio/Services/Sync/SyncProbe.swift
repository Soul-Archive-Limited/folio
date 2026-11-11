#if DEBUG
import Foundation
import UIKit

/// The live sync test matrix's iPhone side (Batch L, DEBUG builds only, `-FolioSyncProbe YES`).
/// A host script writes commands to `Documents/probe-in.txt` (one per line); the probe runs them
/// as ordinary local edits and appends timestamped events to `Documents/sync-probe.log`:
/// `cmd` when an edit is made, `pushed` when the server accepts it, `applied` when a change from
/// another device lands, `blob-up` / `blob-down` for photo bytes and `ping` for the live socket.
/// Only test records (titles and names starting "SYNC") are named in the log; anything else is
/// logged by id, so it never writes diary text. Never compiled into Release.
@MainActor
enum SyncProbe {
    static let enabled = UserDefaults.standard.bool(forKey: "FolioSyncProbe")
    /// `sync.pause`: every API request fails as if there were no network, until `sync.resume`.
    nonisolated(unsafe) static var offline = false
    private static var timer: Timer?
    private static let documents = URL.documentsDirectory
    private static var inbox: URL { documents.appending(path: "probe-in.txt") }
    private static var logFile: URL { documents.appending(path: "sync-probe.log") }

    static func start(store: DiaryStore, sync: SyncEngine) {
        guard enabled, timer == nil else { return }
        log("probe-start", "")
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { poll(store: store, sync: sync) }
        }
    }

    nonisolated static func log(_ event: String, _ detail: String) {
        let line = "\(Int64(Date().timeIntervalSince1970 * 1000)) \(event) \(detail)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = URL.documentsDirectory.appending(path: "sync-probe.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    /// A summary of a decrypted record, naming only test records.
    nonisolated static func summary(type: String, id: String, deleted: Bool, plaintext: Data?) -> String {
        guard let plaintext, let object = (try? JSONSerialization.jsonObject(with: plaintext)) as? [String: Any] else {
            return "\(type) \(id.prefix(8)) deleted=\(deleted)"
        }
        let label = (object["title"] as? String) ?? (object["name"] as? String) ?? (object["displayName"] as? String) ?? ""
        guard label.hasPrefix("SYNC") || type == "settings" else { return "\(type) \(id.prefix(8))" }
        var parts = ["\(type) \(id.prefix(8)) \"\(label)\""]
        for key in ["isCompleted", "mood", "avatar", "appearance", "writingFont", "dayKey", "parentID", "repeatRule"] {
            if let value = object[key] { parts.append("\(key)=\(value)") }
        }
        if let place = object["place"] as? [String: Any], let name = place["name"] { parts.append("place=\(name)") }
        if object["trashedAt"] != nil { parts.append("trashed") }
        return parts.joined(separator: " ")
    }

    private static func poll(store: DiaryStore, sync: SyncEngine) {
        guard let text = try? String(contentsOf: inbox, encoding: .utf8), !text.isEmpty else { return }
        try? FileManager.default.removeItem(at: inbox)
        for line in text.split(separator: "\n").map(String.init) where !line.isEmpty {
            run(line, store: store, sync: sync)
        }
    }

    private static func entry(_ title: String, in store: DiaryStore) -> Entry? {
        store.allEntries().first { $0.title == title } ?? store.trashedEntries().first { $0.title == title }
    }

    private static func task(_ title: String, in store: DiaryStore) -> TaskItem? {
        store.allTasks(includingSubtasks: true).first { $0.title == title }
    }

    private static func pair(_ argument: String) -> (String, String)? {
        guard let arrow = argument.range(of: "=>") else { return nil }
        return (String(argument[..<arrow.lowerBound]), String(argument[arrow.upperBound...]))
    }

    private static func run(_ line: String, store: DiaryStore, sync: SyncEngine) {
        let command = line.split(separator: " ", maxSplits: 1).map(String.init)
        let name = command[0], argument = command.count > 1 ? command[1] : ""
        log("cmd", "\(name) \(argument)")
        switch name {
        case "entry.create": _ = try? store.createEntry(title: argument, body: "Probe page.", day: store.today)
        case "entry.rename":
            if let (old, new) = pair(argument), let e = entry(old, in: store) { try? store.updateEntry(e, title: new, body: e.bodyMarkdown, categoryID: e.categoryID) }
        case "entry.trash": if let e = entry(argument, in: store) { store.trash(e) }
        case "entry.restore": if let e = entry(argument, in: store) { store.restoreFromTrash(e) }
        case "entry.mood":
            if let (title, value) = pair(argument), let e = entry(title, in: store) { store.setMood(e, Int(value).flatMap(Mood.init(rawValue:))) }
        case "entry.place":
            // "entry.place <title>|<name>|<lat>|<lon>" — an empty name removes it (Batch N).
            let parts = argument.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 2, let e = entry(parts[0], in: store) {
                let place = parts[1].isEmpty ? nil : Place(name: parts[1], latitude: parts.count > 2 ? Double(parts[2]) : nil,
                                                           longitude: parts.count > 3 ? Double(parts[3]) : nil)
                store.setPlace(e, place)
            }
        case "entry.photo.add", "entry.photo.replace":
            guard let e = entry(argument, in: store), let photo = samplePhoto(hue: name.hasSuffix("replace") ? 0.6 : 0.08) else { break }
            if name.hasSuffix("replace"), let old = e.orderedPhotos.first { store.delete(old) }
            _ = try? store.addPhoto(photo, to: e)
        case "entry.photo.remove": if let e = entry(argument, in: store), let old = e.orderedPhotos.first { store.delete(old) }
        case "task.create": _ = try? store.createTask(title: argument, day: store.today)
        case "task.tick": if let t = task(argument, in: store) { store.setCompleted(t, true) }
        case "task.untick": if let t = task(argument, in: store) { store.setCompleted(t, false) }
        case "task.repeat":
            if let t = task(argument, in: store) { store.setRepeat(t, RepeatRule(frequency: .daily)) }
        case "task.subtask":
            if let (parent, child) = pair(argument), let t = task(parent, in: store) { _ = try? store.addSubtask(title: child, to: t) }
        case "category.create": _ = try? store.createCategory(name: argument, color: .ocean)
        case "category.rename":
            if let (old, new) = pair(argument), let c = store.categories().first(where: { $0.name == old }) {
                try? store.updateCategory(c, name: new, color: c.color, symbol: c.symbol)
            }
        case "settings.name": store.updateSettings { $0.displayName = argument }
        case "settings.avatar": store.updateSettings { $0.avatar = argument; $0.avatarPhoto = nil }
        case "settings.appearance": store.updateSettings { $0.appearance = argument }
        case "sync.pause": offline = true; sync.stop()
        case "sync.resume": offline = false; sync.enterForeground()
        default: log("cmd-unknown", name)
        }
    }

    /// A small generated photo (a coloured gradient), processed like any picked photo.
    private static func samplePhoto(hue: CGFloat) -> ProcessedPhoto? {
        let size = CGSize(width: 900, height: 675)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1).cgColor,
                          UIColor(hue: hue + 0.1, saturation: 0.6, brightness: 0.55, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return try? PhotoProcessor().processSynchronously(data)
    }
}
#endif
