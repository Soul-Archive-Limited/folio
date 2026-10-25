import Foundation

/// Time-of-day bands for the greeting pool (SPEC §4.2).
enum GreetingPeriod: CaseIterable, Sendable {
    /// 04:00–06:59
    case early
    /// 07:00–11:59
    case morning
    /// 12:00–16:59
    case afternoon
    /// 17:00–20:59
    case evening
    /// 21:00–03:59
    case night

    init(hour: Int) {
        switch hour {
        case 4..<7: self = .early
        case 7..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }
}
