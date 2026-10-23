import Foundation

public struct RewardChallenge: Equatable, Sendable {
    public let id: String, title: String
    public let points: Int
}

/// Content identities never depend on the round, shuffle order, save slot, or tile order.
public enum RewardCatalog {
    public static func arithmetic(_ q: ArithmeticQuestion) -> RewardChallenge {
        .init(id:"numberLine:\(q.start):\(q.change)",title:"荷叶跳跳 · \(q.equation)",points:1)
    }
    public static func sharing(_ task: SharingTask) -> RewardChallenge {
        .init(id:"sharing:\(task.total):\(task.bowls)",title:"森林野餐 · \(task.total) ÷ \(task.bowls)",points:1)
    }
    public static func workshop(_ game: LearningGame,_ q: WorkshopQuestion) -> RewardChallenge {
        let key=(game == .characters || game == .idioms ? q.word : q.reading).precomposedStringWithCanonicalMapping
        return .init(id:"\(game.rawValue):\(key)",title:"\(game.title) · \(game == .bakery ? q.reading : q.word)",points:1)
    }
    public static func clock(_ task: ClockTask) -> RewardChallenge {
        let mode: String
        switch task.mode { case .set: mode="set";case .elapsed: mode="elapsed";case .seconds:mode="seconds";case .conversion:mode="conversion" }
        return .init(id:"clock:\(mode):\(task.start):\(task.target)",title:"滴答时钟 · \(task.prompt)",points:1)
    }
    public static func matches(_ puzzle: MatchPuzzle) -> RewardChallenge {
        .init(id:"matches:move:\(puzzle.initial)",title:"巧移火柴 · \(puzzle.initialEquation)",points:3)
    }
    public static func sorting(_ level: Int) -> RewardChallenge {
        .init(id:"sorting:level-\(level+1)",title:"果篮分拣 · 第 \(level+1) 关",points:3)
    }
    public static func puzzle(_ game: LearningGame,_ index: Int) -> RewardChallenge {
        .init(id:"\(game.rawValue):level-\(index+1)",title:"\(game.title) · 第 \(index+1) 关",points:game == .tangram || game == .delivery ? 3 : 1)
    }
    public static func ruler(_ task: RulerTask) -> RewardChallenge {
        .init(id:task.identity,title:"断尺侦探 · \(task.prompt)",points:task.mode == .explore ? 3 : 1)
    }
    public static let all: [RewardChallenge] = {
        var result: [RewardChallenge]=[]
        for start in 0...20 { for change in -20...20 where change != 0 && (0...20).contains(start+change) {
            result.append(arithmetic(.init(start:start,change:change)))
        } }
        result += SharingTask.all.map(sharing)
        for game in LearningGame.allCases where game.isWorkshop { result += WorkshopContent.questions(for:game).map { workshop(game,$0) } }
        result += RulerTask.all.map(ruler)
        result += ClockTask.all.map(clock)
        result += MatchPuzzle.all.map(matches)
        result += (0..<FruitSession.levelCount).map(sorting)
        for game in [LearningGame.tangram,.delivery,.beads] {
            let count=game == .tangram ? TangramTask.all.count : game == .delivery ? RouteTask.all.count : BeadTask.all.count
            result += (0..<count).map { puzzle(game,$0) }
        }
        return result
    }()
    public static let byID = Dictionary(uniqueKeysWithValues:all.map { ($0.id,$0) })

    public static func current(_ game: LearningGame,in progress: CollectionProgress) -> RewardChallenge? {
        switch game {
        case .numberLine: return progress.numberLine.map { arithmetic($0.question) }
        case .sharing: return sharing(progress.sharing.task)
        case .clock: return clock(progress.clock.task)
        case .matches: return matches(progress.matches.puzzle)
        case .sorting: return sorting(progress.fruits.level)
        case .tangram:return puzzle(game,progress.tangram.index)
        case .delivery:return puzzle(game,progress.delivery.index)
        case .beads:return puzzle(game,progress.beads.index)
        case .ruler:return ruler(progress.ruler.task)
        case .printing: return nil
        default:
            guard game.isWorkshop, let session=progress.words[game.rawValue] else { return nil }
            return workshop(game,WorkshopContent.questions(for:game)[session.index])
        }
    }

    /// Also reconciles older saves. Reopening or resetting a game cannot clear the award ledger.
    public static func completed(in progress: CollectionProgress) -> [RewardChallenge] {
        var result: [RewardChallenge]=[]
        if let game=progress.numberLine { result += game.questions.prefix(game.completedCount).map(arithmetic) }
        for game in LearningGame.allCases where game != .numberLine && game != .printing {
            if progress.study.selected[game.rawValue] != nil {
                // A selected group may jump over catalog slots; never award skipped questions.
                let correct: Bool
                switch game {
                case .sharing: correct=progress.sharing.phase == .correct
                case .clock: correct=progress.clock.phase == .correct
                case .matches: correct=progress.matches.phase == .correct
                case .sorting: correct=progress.fruits.isSolved
                case .tangram:correct=progress.tangram.phase == .correct
                case .delivery:correct=progress.delivery.phase == .correct
                case .beads:correct=progress.beads.phase == .correct
                case .ruler:correct=progress.ruler.phase == .correct
                default: correct=progress.words[game.rawValue]?.phase == .correct
                }
                if correct, let challenge=current(game,in:progress) { result.append(challenge) }
                continue
            }
            if game == .ruler {
                if progress.ruler.phase == .correct { result.append(ruler(progress.ruler.task)) };continue
            }
            if game.isNewPuzzle {
                let correct=game == .tangram ? progress.tangram.phase == .correct : game == .delivery ? progress.delivery.phase == .correct : progress.beads.phase == .correct
                if correct,let c=current(game,in:progress) { result.append(c) };continue
            }
            // One-time import of the old, sequential game saves.
            switch game {
            case .sharing:
                let s=progress.sharing
                result += SharingTask.all.prefix(s.index + (s.phase == .correct || s.phase == .complete ? 1 : 0)).map(sharing)
            case .clock:
                let s=progress.clock
                result += ClockTask.all.prefix(s.index + (s.phase == .correct || s.phase == .complete ? 1 : 0)).map(clock)
            case .matches:
                let s=progress.matches
                result += MatchPuzzle.all.prefix(s.index + (s.phase == .correct || s.phase == .complete ? 1 : 0)).map(matches)
            case .sorting:
                result += (0..<progress.fruits.level).map(sorting)
                if progress.fruits.isSolved { result.append(sorting(progress.fruits.level)) }
            default:
                if let s=progress.words[game.rawValue] {
                    result += WorkshopContent.questions(for:game).prefix(s.index + (s.phase == .correct || s.phase == .complete ? 1 : 0)).map { workshop(game,$0) }
                }
            }
        }
        return result
    }
}

public struct PointsEntry: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case award, redemption, refund, playTime }
    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let reference: String
    public let title: String
    public let amount: Int
}

public struct RewardLedger: Codable, Equatable, Sendable {
    public private(set) var entries: [PointsEntry] = []
    public init() {}
    public var balance: Int { entries.reduce(0) { $0 + $1.amount } }
    public var awardedIDs: Set<String> { Set(entries.filter { $0.kind == .award }.map(\.reference)) }
    public func hasAward(_ id: String) -> Bool { entries.contains { $0.kind == .award && $0.reference == id } }
    public func isRefunded(_ id: UUID) -> Bool { entries.contains { $0.kind == .refund && $0.reference == id.uuidString } }
    @discardableResult public mutating func award(_ id: String,date: Date = Date()) -> Bool {
        guard let challenge=RewardCatalog.byID[id], !hasAward(id) else { return false }
        entries.append(.init(id:UUID(),date:date,kind:.award,reference:id,title:challenge.title,amount:challenge.points)); return true
    }
    @discardableResult public mutating func redeem(title: String,points: Int,requestID: UUID,date: Date = Date()) -> Bool {
        let name=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, points > 0, points <= balance, !entries.contains(where:{$0.id == requestID}) else { return false }
        entries.append(.init(id:requestID,date:date,kind:.redemption,reference:"manual",title:name,amount:-points)); return true
    }
    @discardableResult public mutating func buyPlayTime(requestID: UUID,date: Date = Date()) -> Bool {
        guard balance >= FunTimeBank.price,!entries.contains(where:{$0.id == requestID}) else { return false }
        entries.append(.init(id:requestID,date:date,kind:.playTime,reference:"play-time:5-minutes",title:"趣味游戏 · 5分钟",amount:-FunTimeBank.price));return true
    }
    @discardableResult public mutating func refund(_ redemptionID: UUID,date: Date = Date()) -> Bool {
        guard let original=entries.first(where:{$0.id == redemptionID && $0.kind == .redemption}), !isRefunded(redemptionID) else { return false }
        entries.append(.init(id:UUID(),date:date,kind:.refund,reference:redemptionID.uuidString,title:"撤销 · \(original.title)",amount:-original.amount)); return true
    }
    public var isValid: Bool {
        var ids=Set<UUID>(), awarded=Set<String>(), refunded=Set<String>(), redemptions=[String:PointsEntry](), total=0
        for e in entries {
            guard ids.insert(e.id).inserted, e.date.timeIntervalSince1970.isFinite, !e.title.isEmpty else { return false }
            switch e.kind {
            case .award:
                guard let challenge=RewardCatalog.byID[e.reference], e.amount == challenge.points, awarded.insert(e.reference).inserted else { return false }
            case .playTime:
                guard e.amount == -FunTimeBank.price,e.reference == "play-time:5-minutes" else { return false }
            case .redemption:
                guard e.amount < 0, e.amount != Int.min, !e.reference.isEmpty else { return false }
                redemptions[e.id.uuidString]=e
            case .refund:
                guard let original=redemptions[e.reference], e.amount == -original.amount, refunded.insert(e.reference).inserted else { return false }
            }
            let (sum,overflow)=total.addingReportingOverflow(e.amount)
            guard !overflow, sum >= 0 else { return false }; total=sum
        }
        return true
    }
}

extension MatchPuzzle {
    public var initialEquation: String {
        guard let (a,b,c,plus)=Self.decode(initial) else { return "移一根" }
        return "\(a) \(plus ? "+" : "−") \(b) = \(c)"
    }
}
