import Foundation

@main
struct CoreChecks {
    static func verifyInvalidSave(_ json: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: json)
        precondition(NumberLineGame.restore(data) == nil)
    }
    static func main() throws {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<1000 {
            let qs = ArithmeticQuestion.makeRound(using: &rng)
            precondition(qs.count == 8)
            precondition(Set(qs.map { "\($0.start):\($0.change)" }).count == 8)
            precondition(qs.allSatisfy { (0...10).contains($0.answer) && (1...4).contains($0.steps) })
            precondition(qs.filter { $0.change > 0 }.count == 4)
            precondition(qs.filter { $0.change < 0 }.count == 4)
            var session = NumberLineGame(questions: qs)
            for q in qs {
                precondition(session.phase == .playing && session.position == q.start)
                while session.position != q.answer { precondition(session.jump(q.direction)) }
                precondition(session.check())
                precondition(!session.check())
                precondition(!session.jump(1))
                session.next()
            }
            precondition(session.phase == .complete && session.completedCount == 8)
            session.next()
            precondition(session.completedCount == 8)
        }
        var game = NumberLineGame(questions: [.init(start: 3, change: 2), .init(start: 2, change: -2)])
        precondition(game.jump(-1))
        precondition(!game.check() && game.position == 2 && game.hint != nil)
        precondition(game.move(to: 5) && game.check())
        game.next()
        precondition(game.position == 2 && game.index == 1)
        precondition(game.move(to: 0) && !game.jump(-1))
        precondition(!game.move(to: 11) && !game.jump(3))
        game.resetPosition()
        precondition(game.position == 2)
        let data = game.encoded()!
        precondition(NumberLineGame.restore(data) == game)
        precondition(NumberLineGame.restore(Data("broken".utf8)) == nil)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["index"] = 99
        try verifyInvalidSave(json)
        json["index"] = 0; json["questions"] = [["start": 5, "change": Int.max]]
        try verifyInvalidSave(json)
        json["questions"] = [["start": 2, "change": -2]]; json["phase"] = "correct"; json["position"] = 2
        try verifyInvalidSave(json)
        print("PASS: 1,000 complete rounds (8,000 questions); retry, bounds, idempotency, persistence and corrupt-save checks.")
        try LibraryChecks.run()
        try RewardChecks.run()
        try StudyChecks.run()
        try NewGamesChecks.run()
        try FunChecks.run()
        try RulerChecks.run()
    }
}
