import Foundation

/// The season for the aura's seasonal layer (Batch I, SPEC §3.5). It comes from the month and
/// the region set on the iPhone (Settings → General → Language & Region) — never location.
nonisolated enum Season: String, CaseIterable, Identifiable, Sendable {
    case spring, summer, monsoon, autumn, winter

    var id: Self { self }

    var displayName: String {
        switch self {
        case .spring: String(localized: "spring")
        case .summer: String(localized: "summer")
        case .monsoon: String(localized: "monsoon")
        case .autumn: String(localized: "autumn")
        case .winter: String(localized: "winter")
        }
    }

    /// Climate groups by region code. Approximate by design: one season per country.
    enum Climate: Equatable, Sendable {
        /// Spring Mar–May, summer Jun–Aug, autumn Sep–Nov, winter Dec–Feb.
        case temperateNorth
        /// The same, six months later.
        case temperateSouth
        /// Summer Mar–May, monsoon Jun–Sep, post-monsoon Oct–Nov (shown as autumn), winter Dec–Feb.
        case indianSubcontinent
        /// Wet May–Oct, dry Nov–Apr (mainland Southeast Asia, West Africa, Central America, the Caribbean).
        case tropicalWetSummer
        /// Wet Nov–Mar, drier Apr–Oct (equatorial Southeast Asia, Sri Lanka, the Maldives).
        case tropicalWetWinter
    }

    static let southern: Set<String> = ["AU", "NZ", "AR", "CL", "UY", "PY", "ZA", "LS", "SZ", "NA", "BW", "BR", "FK"]
    static let indian: Set<String> = ["IN", "PK", "BD", "NP", "BT"]
    static let wetSummer: Set<String> = ["TH", "MM", "KH", "LA", "VN", "PH", "NG", "GH", "CI", "SN", "ML", "BF", "MX", "GT",
                                         "BZ", "HN", "SV", "NI", "CR", "PA", "CU", "JM", "HT", "DO", "PR", "TT", "BS"]
    static let wetWinter: Set<String> = ["SG", "MY", "ID", "BN", "LK", "MV", "TL"]

    static func climate(region: String?) -> Climate {
        guard let region = region?.uppercased() else { return .temperateNorth }
        if indian.contains(region) { return .indianSubcontinent }
        if wetSummer.contains(region) { return .tropicalWetSummer }
        if wetWinter.contains(region) { return .tropicalWetWinter }
        if southern.contains(region) { return .temperateSouth }
        return .temperateNorth
    }

    static func season(month: Int, climate: Climate) -> Season {
        switch climate {
        case .temperateNorth:
            switch month {
            case 3...5: return .spring
            case 6...8: return .summer
            case 9...11: return .autumn
            default: return .winter
            }
        case .temperateSouth:
            return season(month: (month + 5) % 12 + 1, climate: .temperateNorth)
        case .indianSubcontinent:
            switch month {
            case 3...5: return .summer
            case 6...9: return .monsoon
            case 10...11: return .autumn
            default: return .winter
            }
        case .tropicalWetSummer:
            return (5...10).contains(month) ? .monsoon : .summer
        case .tropicalWetWinter:
            return month >= 11 || month <= 3 ? .monsoon : .summer
        }
    }

    static func current(month: Int, region: String? = Locale.current.region?.identifier) -> Season {
        season(month: month, climate: climate(region: region))
    }
}

/// Profile → Appearance → Season effect: Auto, a chosen season, or Off (device-only).
nonisolated enum SeasonEffectSetting: String, CaseIterable, Identifiable, Sendable {
    case auto, spring, summer, monsoon, autumn, winter, off

    static let key = "seasonEffect"
    var id: Self { self }

    func season(month: Int, region: String? = Locale.current.region?.identifier) -> Season? {
        switch self {
        case .auto: Season.current(month: month, region: region)
        case .off: nil
        default: Season(rawValue: rawValue)
        }
    }
}
