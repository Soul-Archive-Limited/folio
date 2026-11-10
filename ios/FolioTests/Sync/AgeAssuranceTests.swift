import Testing
@testable import Folio

@Suite("Apple age check decisions (Batch M)")
struct AgeAssuranceTests {
    @Test("18 or more is an adult", arguments: [18, 21, 65])
    func adult(lowerBound: Int) {
        #expect(AgeAssurance.decide(.shared(lowerBound: lowerBound)) == .adult)
        #expect(AgeAssurance.Decision.adult.message == nil)
    }

    @Test("Under the 18 gate, or any lower band, is not an adult", arguments: [nil, 13, 16, 17] as [Int?])
    func notAdult(lowerBound: Int?) {
        let decision = AgeAssurance.decide(.shared(lowerBound: lowerBound))
        #expect(decision == .notAdult)
        #expect(decision.message?.contains("without an account") == true)
    }

    @Test("Declining or a failure never ticks the box")
    func noAnswer() {
        #expect(AgeAssurance.decide(.declined) == .couldNotCheck(.notSetUp))
        #expect(AgeAssurance.decide(.failed(.network)) == .couldNotCheck(.network))
        #expect(AgeAssurance.decide(.failed(.notSetUp)) == .couldNotCheck(.notSetUp))
        #expect(AgeAssurance.Decision.couldNotCheck(.network).message?.contains("connection") == true)
        #expect(AgeAssurance.Decision.couldNotCheck(.notSetUp).message?.contains("age range from Apple") == true)
    }
}
