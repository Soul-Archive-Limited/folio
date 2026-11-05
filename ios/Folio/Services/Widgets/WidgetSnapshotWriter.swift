import os
import SwiftUI
import UIKit
import WidgetKit

/// Writes the widgets' snapshot (Batch J) after the diary changes — debounced, only when its
/// content actually changed, so WidgetKit's reload budget isn't spent on nothing. Also applies
/// ticks made on a widget (`WidgetActionQueue`).
@MainActor
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()

    private weak var store: DiaryStore?
    private var pending: Task<Void, Never>?
    private var lastWritten: Data?
    private let logger = Logger(subsystem: "com.devilsense.folio", category: "widgets")

    func start(store: DiaryStore) {
        self.store = store
        applyPendingTicks()
        writeNow()
    }

    /// After a store change: write a second later (a burst of edits writes once).
    func scheduleWrite() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            writeNow()
        }
    }

    /// Ticks made on a widget while Folio was away become ordinary local edits (they sync).
    func applyPendingTicks() {
        guard let store else { return }
        for action in WidgetActionQueue.drain() {
            guard let task = store.task(id: action.taskID), task.isCompleted != action.isDone else { continue }
            store.setCompleted(task, action.isDone)
        }
    }

    func writeNow() {
        guard let store, UIApplication.shared.isProtectedDataAvailable, let url = WidgetSnapshot.url else { return }
        let snapshot = Self.makeSnapshot(store: store)
        guard let data = snapshot.encoded(), data != lastWritten else { return }
        do {
            try AppGroup.write(data, to: url)
            lastWritten = data
            writeThumbnails(for: snapshot, store: store)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("Widget snapshot write failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    // MARK: Building

    static func makeSnapshot(store: DiaryStore) -> WidgetSnapshot {
        let details = AppGroup.showsHomeDetails || AppGroup.showsLockDetails
        let today = store.today
        let settings = store.settings()
        let name = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWeekday = settings.firstWeekday ?? store.calendar.firstWeekday
        let colors = Dictionary(uniqueKeysWithValues: store.categories().map { ($0.id, $0.color.color) })

        var greetings: [String: String] = [:]
        for (key, hour) in zip(["early", "morning", "afternoon", "evening", "night"], [5, 9, 14, 18, 22]) {
            greetings[key] = Greetings.pool(for: GreetingPeriod(hour: hour)).first?.text(name: name.isEmpty ? nil : name)
        }

        let window = [today.rawValue, today.adding(days: 1).rawValue]
        let tasks = store.allTasks()
            .filter { task in
                guard let raw = task.dayKey else { return false }
                return window.contains(raw) || (raw < today.rawValue && !task.isCompleted)
            }
            .sorted { ($0.dayKey ?? "", $0.isCompleted ? 1 : 0, $0.minutesFromMidnight ?? 9999, $0.sortIndex)
                < ($1.dayKey ?? "", $1.isCompleted ? 1 : 0, $1.minutesFromMidnight ?? 9999, $1.sortIndex) }
            .prefix(40)
            .map { task in
                let tint = task.categoryID.flatMap { colors[$0] }
                return WidgetSnapshot.Task(id: task.id, title: details ? task.title : "", dayKey: task.dayKey ?? today.rawValue,
                                           minutes: task.minutesFromMidnight, isDone: task.isCompleted,
                                           tintLight: tint.map { hex($0, .light) }, tintDark: tint.map { hex($0, .dark) })
            }

        let months = [today.monthKey, today.monthKey.adding(months: 1)].map { month in
            let markers = store.markers(for: month, firstWeekday: firstWeekday)
            let grid = month.gridDays(firstWeekday: firstWeekday)
            var days: [String: WidgetSnapshot.Day] = [:]
            for day in grid {
                guard let marker = markers[day], !marker.isEmpty else { continue }
                days[day.rawValue] = WidgetSnapshot.Day(
                    entries: marker.entryCount,
                    photo: details ? marker.thumbnailPhotoID.map { "\($0.uuidString).jpg" } : nil,
                    dots: marker.dotCategoryIDs.map { id in
                        id.flatMap { colors[$0] }.map { "\(hex($0, .light))|\(hex($0, .dark))" } ?? ""
                    },
                    openTasks: marker.openTaskCount, doneTasks: marker.doneTaskCount)
            }
            return WidgetSnapshot.Month(year: month.year, month: month.month, grid: grid.map(\.rawValue), days: days)
        }

        var onThisDay: [String: Int] = [:]
        if let year = store.greetingSummary().onThisDayYear { onThisDay[today.rawValue] = year }

        return WidgetSnapshot(writtenAt: .now, greetings: greetings, tasks: Array(tasks), months: months,
                              showsDetails: details, onThisDayYears: onThisDay)
    }

    /// The month's photo tiles: the 240 px thumbnails already stored, nothing new is made.
    private func writeThumbnails(for snapshot: WidgetSnapshot, store: DiaryStore) {
        guard let folder = WidgetSnapshot.thumbsFolder else { return }
        let wanted = Set(snapshot.months.flatMap { $0.days.values.compactMap(\.photo) })
        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? [])
        for name in existing.subtracting(wanted) { try? FileManager.default.removeItem(at: folder.appending(path: name)) }
        for name in wanted.subtracting(existing) {
            guard let id = UUID(uuidString: String(name.dropLast(4))), let photo = store.photo(id: id), !photo.thumbData.isEmpty else { continue }
            try? AppGroup.write(photo.thumbData, to: folder.appending(path: name))
        }
    }

    private static func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
