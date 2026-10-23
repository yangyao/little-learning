import Foundation

public struct MatchPuzzle: Sendable {
    public enum Rule: String, Codable, CaseIterable, Sendable {
        case add, remove, move
        public var title: String { self == .add ? "加一根" : self == .remove ? "减一根" : "移一根" }
    }
    public let initial: UInt32, solution: UInt32
    public let rule: Rule
    public static let digits: [UInt32] = [0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F]
    public static func encode(_ a: Int, _ b: Int, _ c: Int, plus: Bool) -> UInt32 {
        digits[a] | digits[b] << 7 | digits[c] << 14 | UInt32(plus ? 3 : 1) << 21
    }
    public static func decode(_ mask: UInt32) -> (Int, Int, Int, Bool)? {
        guard mask >> 23 == 0,
              let a = digits.firstIndex(of: mask & 127), let b = digits.firstIndex(of: (mask >> 7) & 127),
              let c = digits.firstIndex(of: (mask >> 14) & 127), [1,3].contains((mask >> 21) & 3) else { return nil }
        return (a,b,c,((mask >> 21) & 3) == 3)
    }
    public static func isTrue(_ mask: UInt32) -> Bool {
        guard let (a,b,c,plus) = decode(mask) else { return false }
        return (plus ? a+b : a-b) == c
    }
    public func accepts(_ mask: UInt32) -> Bool {
        let removed = (initial & ~mask).nonzeroBitCount, added = (mask & ~initial).nonzeroBitCount
        let fits = rule == .add ? (removed == 0 && added == 1) : rule == .remove ? (removed == 1 && added == 0) : (removed == 1 && added == 1)
        return fits && Self.isTrue(mask)
    }
    public static let all: [Self] = {
        var result: [Self] = []
        for rule in [Rule.move] {
            var found: [Self] = [], seen = Set<UInt32>()
            for a in 0...9 { for b in 0...9 { for plus in [true,false] {
                let c = plus ? a+b : a-b
                guard (0...9).contains(c) else { continue }
                let target = encode(a,b,c,plus:plus)
                for i in 0..<23 {
                    var candidates: [UInt32] = []
                    if rule == .add, target & (1 << i) != 0 { candidates = [target ^ (1 << i)] }
                    if rule == .remove, target & (1 << i) == 0 { candidates = [target | (1 << i)] }
                    if rule == .move, target & (1 << i) != 0 {
                        candidates = (0..<23).filter { target & (1 << $0) == 0 }.map { target ^ (1 << i) | (1 << $0) }
                    }
                    for mask in candidates where decode(mask) != nil && !isTrue(mask) {
                        if seen.insert(mask).inserted { found.append(.init(initial:mask,solution:target,rule:rule)) }
                    }
                }
            } } }
            var rng = SeededRandom(seed: UInt64(result.count + 87))
            result += found.shuffled(using:&rng).prefix(360)
        }
        return result
    }()
}

public struct MatchSession: Codable, Equatable, Sendable {
    public var index = 0
    public private(set) var mask: UInt32 = MatchPuzzle.all[0].initial
    public var selectedPart = 0
    public var selectedMatch: Int?
    public var ruleSetVersion: Int? = 2
    public var phase = PlayPhase.playing
    public var hint: String?
    public var puzzle: MatchPuzzle { MatchPuzzle.all[index] }
    public init(startAt index: Int = 0) { precondition(MatchPuzzle.all.indices.contains(index));self.index=index;mask=puzzle.initial }
    public mutating func tap(_ bit: Int) {
        guard phase == .playing, (0..<23).contains(bit) else { return }
        guard mask == puzzle.initial else { hint = "已经移动了一根，检查等式或重新摆吧。"; return }
        if mask & (1 << bit) != 0 {
            selectedMatch = selectedMatch == bit ? nil : bit; hint = nil
        } else if let from = selectedMatch { move(from:from,to:bit) }
        else { hint = "先选一根实心火柴，再放到虚线空位。" }
    }
    @discardableResult public mutating func move(from: Int,to: Int) -> Bool {
        guard phase == .playing, mask == puzzle.initial, (0..<23).contains(from), (0..<23).contains(to),
              mask & (1 << from) != 0, mask & (1 << to) == 0 else { return false }
        mask = mask ^ (1 << from) | (1 << to); selectedMatch = nil; hint = nil
        return true
    }
    public mutating func reset() { mask = puzzle.initial; selectedMatch = nil; hint = nil; phase = .playing }
    @discardableResult public mutating func check() -> Bool {
        guard phase == .playing else { return false }
        if puzzle.accepts(mask) { phase = .correct; hint = nil; return true }
        hint = "这题要\(puzzle.rule.title)，也要让等号两边一样大。"; return false
    }
    public mutating func next() {
        guard phase == .correct else { return }
        if index + 1 == MatchPuzzle.all.count { phase = .complete; return }
        index += 1; mask = puzzle.initial; phase = .playing; hint = nil; selectedPart = 0; selectedMatch = nil
    }
    public var isValid: Bool {
        guard MatchPuzzle.all.indices.contains(index), mask >> 23 == 0, (0...3).contains(selectedPart), [.playing,.correct,.complete].contains(phase) else { return false }
        let removed = (puzzle.initial & ~mask).nonzeroBitCount, added = (mask & ~puzzle.initial).nonzeroBitCount
        guard (removed == 0 && added == 0) || (removed == 1 && added == 1) else { return false }
        if let selectedMatch {
            guard phase == .playing, mask == puzzle.initial, (0..<23).contains(selectedMatch), mask & (1 << selectedMatch) != 0 else { return false }
        }
        return phase == .playing || (puzzle.accepts(mask) && (phase != .complete || index == MatchPuzzle.all.count-1))
    }
}

public struct FruitMove: Equatable, Sendable { public let from: Int, to: Int }
public struct FruitSession: Codable, Equatable, Sendable {
    public var level = 0
    public private(set) var jars: [[Int]]
    public private(set) var history: [[[Int]]] = []
    public var selected: Int?
    public var hint: String?
    public static let fruits = ["🍎","🍋","🍇","🍊","🍓","🥝","🍒"]
    public static let names = ["苹果","柠檬","葡萄","橘子","草莓","奇异果","樱桃"]
    public static let levelCount = 36
    public static func colors(for level: Int) -> Int { level < 12 ? min(7,2+level/2) : min(7,2+(level-12)/4) }
    public var colorCount: Int { Self.colors(for:level) }
    public var isSolved: Bool { Self.solved(jars) }
    public init(level: Int = 0) { precondition((0..<Self.levelCount).contains(level));self.level=level;jars=Self.generated(level:level).board }
    public static func solved(_ jars: [[Int]]) -> Bool { jars.allSatisfy { $0.isEmpty || ($0.count == 4 && Set($0).count == 1) } }
    public static func generated(level: Int) -> (board: [[Int]], solution: [FruitMove]) {
        let count = colors(for:level)
        var board = (0..<count).map { Array(repeating:$0,count:4) } + [[],[]]
        var reverse: [FruitMove] = [], rng = SeededRandom(seed:UInt64(17 + level * 7919 + (level >= 12 ? 1_000_003 : 0)))
        for _ in 0..<(60 + level * 12) {
            var choices: [FruitMove] = []
            for from in board.indices {
                guard let color = board[from].last, board[from].count == 1 || board[from].dropLast().last == color else { continue }
                for to in board.indices where from != to && board[to].count < 4 {
                    // Reverse scrambling may mix colors, but the recorded forward undo is always legal.
                    if reverse.last != FruitMove(from:to,to:from) { choices.append(.init(from:from,to:to)) }
                }
            }
            guard let move = choices.randomElement(using:&rng) else { break }
            board[move.to].append(board[move.from].removeLast()); reverse.append(move)
        }
        if solved(board) {
            // One more reversible split guarantees an unfinished opening board.
            let from = board.firstIndex(where:{ !$0.isEmpty })!, to = board.firstIndex(where:{ $0.isEmpty })!
            board[to].append(board[from].removeLast()); reverse.append(.init(from:from,to:to))
        }
        return (board, reverse.reversed().map { FruitMove(from:$0.to,to:$0.from) })
    }
    @discardableResult public mutating func move(from: Int, to: Int) -> Bool {
        guard jars.indices.contains(from), jars.indices.contains(to), from != to,
              let fruit = jars[from].last, jars[to].count < 4, jars[to].isEmpty || jars[to].last == fruit else { return false }
        history.append(jars); if history.count > 300 { history.removeFirst() }
        jars[to].append(jars[from].removeLast()); selected = nil; hint = nil; return true
    }
    public mutating func tap(_ index: Int) {
        guard jars.indices.contains(index), !isSolved else { return }
        if selected == index { selected = nil; return }
        if let from = selected {
            if !move(from:from,to:index) { hint = "只能放进空罐，或相同水果的上面。"; selected = jars[index].isEmpty ? from : index }
        } else if !jars[index].isEmpty { selected = index }
    }
    public mutating func undo() { guard let previous = history.popLast() else { return }; jars = previous; selected = nil; hint = nil }
    public mutating func reset() { jars = Self.generated(level:level).board; history = []; selected = nil; hint = nil }
    public mutating func next() { guard isSolved else { return }; level = (level + 1) % Self.levelCount; reset() }
    public var isValid: Bool {
        guard (0..<Self.levelCount).contains(level), jars.count == colorCount + 2, history.count <= 300 else { return false }
        func validBoard(_ board: [[Int]]) -> Bool {
            guard board.count == colorCount + 2, board.allSatisfy({ $0.count <= 4 && $0.allSatisfy { (0..<colorCount).contains($0) } }) else { return false }
            return (0..<colorCount).allSatisfy { color in board.flatMap{$0}.filter{$0 == color}.count == 4 }
        }
        return validBoard(jars) && history.allSatisfy(validBoard) && (selected == nil || jars.indices.contains(selected!))
    }
}

public struct PrintStamp: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public let material: Int, color: Int
    public let x: Double, y: Double, size: Double, angle: Double, opacity: Double
    public var isValid: Bool {
        (0..<4).contains(material) && (0..<6).contains(color) && [x,y,size,angle,opacity].allSatisfy(\.isFinite) && (0...1).contains(x) && (0...1).contains(y) && (0.08...0.50).contains(size) && (0...360).contains(angle) && (0.1...1).contains(opacity)
    }
}
public struct PrintWork: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var stamps: [PrintStamp]
}
public struct PrintSession: Codable, Equatable, Sendable {
    public var material = 0, color = 0, pressure = 1
    public var size = 0.22, angle = 0.0
    public private(set) var stamps: [PrintStamp] = []
    public private(set) var works: [PrintWork] = []
    public var note: String?
    public init() {}
    public mutating func stamp(x: Double, y: Double) {
        guard stamps.count < 300, x.isFinite, y.isFinite else { note = "画纸已经很丰富了，先收好作品吧。"; return }
        let stamp = PrintStamp(material:material,color:color,x:min(1,max(0,x)),y:min(1,max(0,y)),size:size,angle:angle,opacity:[0.35,0.65,0.95][pressure])
        guard stamp.isValid else { return }; stamps.append(stamp); note = nil
    }
    public mutating func undo() { if !stamps.isEmpty { stamps.removeLast() }; note = nil }
    public mutating func keep() {
        guard !stamps.isEmpty else { note = "先盖一片叶子吧。"; return }
        if works.last?.stamps != stamps { works.append(.init(stamps:stamps)); if works.count > 20 { works.removeFirst() } }
        note = "作品收好了，随时可以回来看。"
    }
    public mutating func newPaper() { if !stamps.isEmpty { keep() }; stamps = []; note = nil }
    public mutating func openWork(_ index: Int) {
        guard works.indices.contains(index) else { return }
        let target = works[index].stamps
        if !stamps.isEmpty { keep() }; stamps = target; note = nil
    }
    public var isValid: Bool {
        (0..<4).contains(material) && (0..<6).contains(color) && (0..<3).contains(pressure) && size.isFinite && (0.08...0.5).contains(size) && angle.isFinite && (0...360).contains(angle) && stamps.count <= 300 && stamps.allSatisfy(\.isValid) && works.count <= 20 && works.allSatisfy { $0.stamps.count <= 300 && $0.stamps.allSatisfy(\.isValid) }
    }
}

public struct CollectionProgress: Codable, Equatable, Sendable {
    public var sharing = SharingSession()
    public var words: [String: WorkshopSession] = Dictionary(uniqueKeysWithValues: LearningGame.allCases.filter(\.isWorkshop).map { ($0.rawValue,WorkshopSession()) })
    public var clock = ClockSession()
    public var matches = MatchSession()
    public var fruits = FruitSession()
    public var printing = PrintSession()
    public var tangram = TangramSession()
    public var delivery = RouteSession()
    public var beads = BeadSession()
    public var funTime = FunTimeBank()
    public var funArrows = ArrowEscapeSession()
    public var funAnts = AntCarrySession()
    public var study = StudyProgress()
    public var rewards = RewardLedger()
    public var numberLine: NumberLineGame?
    public init() {}
    private enum CodingKeys: String, CodingKey { case sharing, words, clock, matches, fruits, printing, rewards, numberLine, study, tangram, delivery, beads, funTime, funArrows, funAnts }
    public init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        sharing=try c.decode(SharingSession.self,forKey:.sharing)
        words=try c.decode([String:WorkshopSession].self,forKey:.words)
        clock=try c.decode(ClockSession.self,forKey:.clock)
        matches=try c.decode(MatchSession.self,forKey:.matches)
        fruits=try c.decode(FruitSession.self,forKey:.fruits)
        printing=try c.decode(PrintSession.self,forKey:.printing)
        funTime=try c.decodeIfPresent(FunTimeBank.self,forKey:.funTime) ?? .init()
        funArrows=try c.decodeIfPresent(ArrowEscapeSession.self,forKey:.funArrows) ?? .init()
        funAnts=try c.decodeIfPresent(AntCarrySession.self,forKey:.funAnts) ?? .init()
        tangram=try c.decodeIfPresent(TangramSession.self,forKey:.tangram) ?? .init()
        delivery=try c.decodeIfPresent(RouteSession.self,forKey:.delivery) ?? .init()
        beads=try c.decodeIfPresent(BeadSession.self,forKey:.beads) ?? .init()
        study=try c.decodeIfPresent(StudyProgress.self,forKey:.study) ?? .init()
        rewards=try c.decodeIfPresent(RewardLedger.self,forKey:.rewards) ?? .init()
        numberLine=try c.decodeIfPresent(NumberLineGame.self,forKey:.numberLine)
    }
    public var isValid: Bool {
        funTime.isValid(in:rewards) && funArrows.isValid && funAnts.isValid && tangram.isValid && delivery.isValid && beads.isValid && study.isValid && rewards.isValid && (numberLine == nil || numberLine?.encoded().flatMap(NumberLineGame.restore) != nil) && sharing.isValid && clock.isValid && matches.isValid && fruits.isValid && printing.isValid && LearningGame.allCases.filter(\.isWorkshop).allSatisfy {
            words[$0.rawValue]?.isValid(for:WorkshopContent.questions(for:$0)) == true
        }
    }
    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
    public static func restore(_ data: Data) -> Self? {
        guard var state = try? JSONDecoder().decode(Self.self,from:data) else { return nil }
        // Retire the long arithmetic banks without losing awards or rejecting an old save.
        let mathKey=LearningGame.numberLine.rawValue
        if let selected=state.study.selected[mathKey] {
            if let group=StudyCatalog.group(selected,for:.numberLine) {
                let reviewing=state.study.reviewing.contains(mathKey)
                let remaining=group.arithmetic.filter { !state.rewards.hasAward(RewardCatalog.arithmetic($0).id) }
                if !reviewing {
                    if remaining.isEmpty { state.study.finished.insert(mathKey) }
                    else { state.study.finished.remove(mathKey) }
                }
                if state.numberLine == nil || state.numberLine!.limit != group.limit || !state.numberLine!.questions.allSatisfy({group.arithmetic.contains($0)}) {
                    let bank=reviewing ? group.arithmetic.filter { state.rewards.hasAward(RewardCatalog.arithmetic($0).id) } : remaining
                    state.numberLine = .init(questions:bank.isEmpty ? group.arithmetic : bank,limit:group.limit)
                }
            } else if ["arithmetic-20-basic","arithmetic-20-cross"].contains(selected) {
                state.study.selected.removeValue(forKey:mathKey)
                state.study.reviewing.remove(mathKey);state.study.finished.remove(mathKey)
                let first=StudyCatalog.groups(for:.numberLine)[0]
                state.numberLine = .init(questions:first.arithmetic,limit:first.limit)
            }
        }
        // Only the matchstick puzzle pool changed; preserve every other game's progress.
        if state.matches.ruleSetVersion != 2 { state.matches = .init() }
        // Expanded catalogs keep their original prefix; old end-of-bank states remain valid.
        if state.sharing.phase == .complete && state.sharing.index < SharingTask.all.count-1 { state.sharing.phase = .correct }
        if state.clock.phase == .complete && state.clock.index < ClockTask.all.count-1 { state.clock.phase = .correct }
        if state.matches.phase == .complete && state.matches.index < MatchPuzzle.all.count-1 { state.matches.phase = .correct }
        for game in LearningGame.allCases where game.isWorkshop {
            if var session=state.words[game.rawValue], session.phase == .complete && session.index < WorkshopContent.questions(for:game).count-1 {
                session.phase = .correct;state.words[game.rawValue]=session
            }
        }
        guard state.isValid else { return nil }; return state
    }
}
