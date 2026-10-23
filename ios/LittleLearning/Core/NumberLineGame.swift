import Foundation

public struct ArithmeticQuestion: Codable, Equatable, Sendable {
    public let start: Int
    public let change: Int
    public var answer: Int { start + change }
    public var steps: Int { abs(change) }
    public var direction: Int { change > 0 ? 1 : -1 }
    public var symbol: String { change > 0 ? "+" : "−" }
    public var directionWord: String { change > 0 ? "右" : "左" }
    public var equation: String { "\(start) \(symbol) \(steps)" }
    public var instruction: String { "从 \(start) 出发，往\(directionWord)跳 \(steps) 格" }
    public var spokenQuestion: String { "\(start) \(change > 0 ? "加" : "减") \(steps) 等于多少？\(instruction)。" }

    public init(start: Int, change: Int) {
        precondition((0...20).contains(start) && change != 0 && (0...20).contains(start + change))
        self.start = start
        self.change = change
    }

    public static func makeRound<R: RandomNumberGenerator>(using rng: inout R) -> [Self] {
        let easy = (0...3).flatMap { a in (1...2).map { Self(start: a, change: $0) } }.shuffled(using: &rng)
        let add = (0...7).flatMap { a in (1...min(4, 10 - a)).map { Self(start: a, change: $0) } }
        let subtract = (2...10).flatMap { a in (1...min(4, a)).map { Self(start: a, change: -$0) } }
        var used = Set<String>()
        var questions: [Self] = []
        func append(_ pool: [Self], count: Int) {
            var added = 0
            for q in pool where added < count {
                let key = "\(q.start),\(q.change)"
                if used.insert(key).inserted { questions.append(q); added += 1 }
            }
        }
        append(easy, count: 2)
        append(subtract.filter { $0.start <= 5 }.shuffled(using: &rng), count: 2)
        append(add.shuffled(using: &rng), count: 2)
        append(subtract.shuffled(using: &rng), count: 2)
        return questions
    }
}

public struct NumberLineGame: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case playing, correct, complete }
    public let upperBound: Int?
    public var limit: Int { upperBound ?? 10 }
    public private(set) var questions: [ArithmeticQuestion]
    public private(set) var index: Int
    public private(set) var position: Int
    public private(set) var phase: Phase
    public private(set) var hint: String?
    public var question: ArithmeticQuestion { questions[index] }
    public var completedCount: Int { phase == .complete ? questions.count : index + (phase == .correct ? 1 : 0) }
    public var progressLabel: String { "第 \(index + 1) 题，共 \(questions.count) 题" }
    public var netSteps: Int { position - question.start }

    public init(questions: [ArithmeticQuestion],limit: Int = 10) {
        precondition([5,10,20].contains(limit) && questions.allSatisfy { (0...limit).contains($0.start) && (0...limit).contains($0.answer) })
        upperBound=limit
        precondition(!questions.isEmpty)
        self.questions = questions
        index = 0
        position = questions[0].start
        phase = .playing
    }

    public static func fresh() -> Self {
        var rng = SystemRandomNumberGenerator()
        return Self(questions: ArithmeticQuestion.makeRound(using: &rng))
    }

    @discardableResult public mutating func move(to target: Int) -> Bool {
        guard phase == .playing, (0...limit).contains(target), target != position else { return false }
        position = target
        hint = nil
        return true
    }

    @discardableResult public mutating func jump(_ direction: Int) -> Bool {
        guard direction == -1 || direction == 1 else { return false }
        return move(to: position + direction)
    }

    @discardableResult public mutating func check() -> Bool {
        guard phase == .playing else { return false }
        guard position == question.answer else {
            hint = "再数一次：从 \(question.start) 往\(question.directionWord)跳 \(question.steps) 格。"
            return false
        }
        phase = .correct
        hint = nil
        return true
    }

    public mutating func next() {
        guard phase == .correct else { return }
        guard index + 1 < questions.count else { phase = .complete; return }
        index += 1
        position = question.start
        phase = .playing
        hint = nil
    }

    public mutating func resetPosition() {
        guard phase == .playing else { return }
        position = question.start
        hint = nil
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func restore(_ data: Data) -> Self? {
        guard let game = try? JSONDecoder().decode(Self.self, from: data),
              (1...100).contains(game.questions.count), game.questions.indices.contains(game.index),
              [5,10,20].contains(game.limit), (0...game.limit).contains(game.position),
              game.questions.allSatisfy({ (0...game.limit).contains($0.start) && (-20...20).contains($0.change) && $0.change != 0 && (0...game.limit).contains($0.answer) }),
              game.phase != .complete || game.index == game.questions.count - 1,
              game.phase == .playing || game.position == game.question.answer else { return nil }
        return game
    }
}
