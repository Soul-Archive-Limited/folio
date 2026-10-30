import Testing
@testable import Folio

@Suite("Season from month and region (Batch I, SPEC §3.5)")
struct SeasonTests {
    @Test("Temperate north", arguments: [(1, Season.winter), (3, .spring), (5, .spring), (6, .summer), (8, .summer), (9, .autumn), (11, .autumn), (12, .winter)])
    func north(month: Int, season: Season) {
        #expect(Season.current(month: month, region: "GB") == season)
        #expect(Season.current(month: month, region: "US") == season)
    }

    @Test("Southern hemisphere is flipped", arguments: [(1, Season.summer), (4, .autumn), (7, .winter), (10, .spring), (12, .summer)])
    func south(month: Int, season: Season) {
        #expect(Season.current(month: month, region: "AU") == season)
        #expect(Season.current(month: month, region: "NZ") == season)
    }

    @Test("Indian subcontinent", arguments: [(2, Season.winter), (3, .summer), (5, .summer), (6, .monsoon), (9, .monsoon), (10, .autumn), (11, .autumn), (12, .winter)])
    func india(month: Int, season: Season) {
        #expect(Season.current(month: month, region: "IN") == season)
        #expect(Season.current(month: month, region: "BD") == season)
    }

    @Test("Tropical wet and dry")
    func tropical() {
        #expect(Season.current(month: 7, region: "TH") == .monsoon)
        #expect(Season.current(month: 1, region: "TH") == .summer)
        #expect(Season.current(month: 12, region: "SG") == .monsoon)
        #expect(Season.current(month: 6, region: "SG") == .summer)
    }

    @Test("No region falls back to temperate north")
    func unknown() {
        #expect(Season.current(month: 7, region: nil) == .summer)
    }

    @Test("The setting: Auto, a chosen season, Off")
    func setting() {
        #expect(SeasonEffectSetting.auto.season(month: 10, region: "IN") == .autumn)
        #expect(SeasonEffectSetting.winter.season(month: 7, region: "IN") == .winter)
        #expect(SeasonEffectSetting.off.season(month: 7, region: "IN") == nil)
    }
}
