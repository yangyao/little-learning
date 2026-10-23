import Foundation

public enum FunGame: String, Codable, CaseIterable, Identifiable, Sendable {
    case arrows, ants, bubbles, watermelon
    public static let allCases: [FunGame] = [.bubbles,.watermelon]
    public var isWebGame: Bool { self == .bubbles || self == .watermelon }
    public var id: String { rawValue }
    public var title: String { switch self { case .arrows: return "箭头大逃脱";case .ants: return "森林搬运队";case .bubbles: return "泡泡龙";case .watermelon: return "合成大西瓜" } }
    public var subtitle: String { switch self { case .arrows: return "找对顺序，让箭头飞出去";case .ants: return "派出小蚂蚁，搬空彩色图案";case .bubbles: return "瞄准发射，消除同色泡泡";case .watermelon: return "让相同水果碰在一起，合出大西瓜" } }
    public var symbol: String { self == .bubbles ? "bubbles.and.sparkles.fill" : self == .watermelon ? "circle.lefthalf.filled" : self == .arrows ? "arrow.up.right" : "ant.fill" }
}

public struct FunTimeBank: Codable, Equatable, Sendable {
    public static let price = 5
    public static let purchaseMilliseconds = 300_000
    public private(set) var spentMilliseconds = 0
    public init() {}
    public func remaining(in ledger: RewardLedger) -> Int {
        max(0,ledger.entries.filter {$0.kind == .playTime}.count * Self.purchaseMilliseconds-spentMilliseconds)
    }
    public func isValid(in ledger: RewardLedger) -> Bool {
        spentMilliseconds >= 0 && spentMilliseconds <= ledger.entries.filter {$0.kind == .playTime}.count * Self.purchaseMilliseconds
    }
    @discardableResult public mutating func consume(_ milliseconds: Int,in ledger: RewardLedger) -> Int {
        let used=min(max(0,milliseconds),remaining(in:ledger));spentMilliseconds += used;return used
    }
}

/// Runtime-only monotonic meter. A stopped app never accrues an offline bill.
public struct FunTimeMeter: Sendable {
    private var mark: Double?
    public init() {}
    public mutating func start(at uptime: Double) { mark=uptime.isFinite ? uptime : nil }
    public mutating func stop() { mark=nil }
    public func elapsed(at uptime: Double) -> Int {
        guard let mark,uptime.isFinite,uptime >= mark else { return 0 }
        let elapsed=(uptime-mark)*1000
        return elapsed >= Double(Int.max/2) ? Int.max/2 : Int(elapsed.rounded(.down))
    }
    public mutating func take(at uptime: Double) -> Int {
        let value=elapsed(at:uptime)
        if value > 0,let mark { self.mark=mark+Double(value)/1000 }
        return value
    }
}

public struct EscapeArrow: Sendable {
    public let id: Int, cells: [GridPoint]
    public var head: GridPoint { cells.last! }
    public var direction: GridPoint { let previous=cells[cells.count-2];return .init(head.x-previous.x,head.y-previous.y) }
    public func ray(size: Int) -> Set<GridPoint> {
        var point=GridPoint(head.x+direction.x,head.y+direction.y),result=Set<GridPoint>()
        while (0..<size).contains(point.x),(0..<size).contains(point.y) {
            result.insert(point);point = .init(point.x+direction.x,point.y+direction.y)
        }
        return result
    }
}
public struct ArrowEscapeTask: Sendable {
    public let index: Int, size: Int, arrows: [EscapeArrow]
    public var solution: [Int] { arrows.map(\.id).reversed() }
    public func canRemove(_ id: Int,removed: Set<Int>) -> Bool {
        guard arrows.indices.contains(id),!removed.contains(id) else { return false }
        let ray=arrows[id].ray(size:size)
        return arrows.filter {!removed.contains($0.id) && $0.id != id}.allSatisfy { ray.isDisjoint(with:$0.cells) }
    }
    // Stable seeds and insertion order are part of saved levels. Reverse insertion is a proven solution.
    public static let all: [Self] = (0..<48).map { level in
        let size=level < 12 ? 6 : level < 28 ? 7 : 8
        let desired=level < 6 ? 5 : level < 12 ? 7 : level < 28 ? 10 : 14
        var rng=SeededRandom(seed:UInt64(48_739+level*97_531)),used=Set<GridPoint>(),arrows=[EscapeArrow]()
        let directions=[GridPoint(1,0),GridPoint(0,1),GridPoint(-1,0),GridPoint(0,-1)]
        for _ in 0..<3000 {
            if arrows.count == desired { break }
            let all=(0..<(size*size)).shuffled(using:&rng)
            guard let start=all.map({GridPoint($0%size,$0/size)}).first(where:{!used.contains($0)}) else { break }
            var path=[start]
            let length=[2,3,3,4,4,5].shuffled(using:&rng)[0]
            for _ in 1..<length {
                let p=path.last!
                let options=directions.shuffled(using:&rng).map {GridPoint(p.x+$0.x,p.y+$0.y)}.filter {
                    (0..<size).contains($0.x) && (0..<size).contains($0.y) && !used.contains($0) && !path.contains($0)
                }
                guard let next=options.first else { break };path.append(next)
            }
            guard path.count >= 2 else { continue }
            let arrow=EscapeArrow(id:arrows.count,cells:path),ray=EscapeArrow(id:0,cells:path).ray(size:size)
            guard ray.isDisjoint(with:used),ray.isDisjoint(with:path) else { continue }
            arrows.append(arrow);used.formUnion(path)
        }
        return .init(index:level,size:size,arrows:arrows)
    }
}
public struct ArrowEscapeSession: Codable, Equatable, Sendable {
    public private(set) var level = 0
    public private(set) var removed: [Int] = []
    public private(set) var hint: String?
    public private(set) var blocked: Int?
    public init() {}
    public var task: ArrowEscapeTask { ArrowEscapeTask.all[level] }
    public var isSolved: Bool { removed.count == task.arrows.count }
    @discardableResult public mutating func tap(_ id: Int) -> Bool {
        guard task.arrows.indices.contains(id),!removed.contains(id) else { return false }
        guard task.canRemove(id,removed:Set(removed)) else { blocked=id;hint="前面有别的箭头，先帮它让出路。";return false }
        removed.append(id);blocked=nil;hint=nil;return true
    }
    public mutating func reset() { removed=[];hint=nil;blocked=nil }
    public mutating func next() { guard isSolved else { return };level=(level+1)%ArrowEscapeTask.all.count;reset() }
    public var isValid: Bool {
        guard ArrowEscapeTask.all.indices.contains(level),removed.count <= task.arrows.count,blocked == nil || task.arrows.indices.contains(blocked!) else { return false }
        var seen=Set<Int>()
        for id in removed { guard task.canRemove(id,removed:seen) else { return false };seen.insert(id) }
        return true
    }
}

public struct AntWorker: Sendable {
    public let id: Int, color: Int, capacity: Int
}
public struct AntMove: Identifiable, Equatable, Sendable {
    public let id: Int, cell: Int, color: Int, slot: Int
}
public struct AntLoad: Codable, Equatable, Sendable {
    public let worker: Int
    public var collected: Int
}
public struct AntBoardState: Codable, Equatable, Sendable {
    public var removed: Set<Int> = []
    public var used = [0,0,0]
    public var slots: [AntLoad?] = [nil,nil,nil]
    public init() {}
}
public struct AntCarryTask: Sendable {
    public static let width = 10
    public let index: Int, title: String, pixels: [Int?], workers: [AntWorker], queues: [[Int]], solution: [Int]
    public var pixelCount: Int { pixels.compactMap {$0}.count }
    public func exposed(removed: Set<Int>) -> [Int] {
        (0..<Self.width).compactMap { x in
            (0..<Self.width).reversed().map {$0*Self.width+x}.first { pixels[$0] != nil && !removed.contains($0) }
        }
    }
    public static let all: [Self] = {
        let pictures: [(String,[String])] = [
            ("小蘑菇",["...AAAA...","..AABAAB..",".AAAAAAA..","AABAAAABAA","AAAAAAAAAA","...CCCC...","...CCCC...","...CDCC...","...CCCC...","..CCCCCC.."]),
            ("小鸭子",["...AAAA...","..AAAAAA..","..AABAACCC","..AAAAAA..","...AAAA...",".AAAAAAAA.","AAAAAAAAAA","AAAAAAAAAA",".AAAAAAAA.","..CCCCCC.."]),
            ("小树屋",["....AA....","...AAAA...","..AAAAAA..",".AAAAAAAA.","AAAAAAAAAA",".BBBBBBBB.",".BCCDCCDB.",".BCCDCCDB.",".BBBCCBBB.",".BBBCCBBB."]),
            ("小花朵",["..AA..AA..",".AAAAAAAA.",".AABBBBAA.","..ABBBBA..",".AABBBBAA.",".AAAAAAAA.","..AA..AA..","....CC....","..CCCCCC..","....CC...."]),
            ("小鱼儿",["....AA....","...AAAA...","..AAAAA..C",".AABAAAA.C","AAAAAAAAAC","AAAAAAAAAC",".AABAAAA.C","..AAAAA..C","...AAAA...","....AA...."]),
            ("小蝴蝶",["AA......AA","AAA....AAA","AAAA..AAAA","AAAABBAAAA","AAAABBAAAA",".AAABBAAA.","..AABBAA..",".CCCB BCCC.",".CCCB BCCC.","..CC..CC.."].map {$0.replacingOccurrences(of:" ",with:"")})
        ]
        return (0..<24).map { level in
            let picture=pictures[level%pictures.count],offset=(level/6)%4
            let pixels=picture.1.flatMap { row in row.map { character -> Int? in
                switch character { case "A":return offset;case "B":return (offset+1)%4;case "C":return (offset+2)%4;case "D":return (offset+3)%4;default:return nil }
            } }
            precondition(pixels.count == 100)
            var removed=Set<Int>(),workers=[AntWorker](),queues=[[Int](),[Int](),[Int]()],solution=[Int]()
            func exposed() -> [Int] { (0..<10).compactMap { x in (0..<10).reversed().map {$0*10+x}.first { pixels[$0] != nil && !removed.contains($0) } } }
            var rng=SeededRandom(seed:UInt64(17_131+level*8_191))
            while removed.count < pixels.compactMap({$0}).count {
                let front=exposed(),colors=Array(Set(front.compactMap {pixels[$0]})).sorted().shuffled(using:&rng)
                let color=colors[0],capacity=min(6,front.filter {pixels[$0] == color}.count),id=workers.count
                workers.append(.init(id:id,color:color,capacity:capacity))
                for _ in 0..<capacity { removed.insert(exposed().first(where:{pixels[$0] == color})!) }
                let lane=id%3;queues[lane].append(id);solution.append(lane)
            }
            return .init(index:level,title:picture.0,pixels:pixels,workers:workers,queues:queues,solution:solution)
        }
    }()
}
public struct AntCarrySession: Codable, Equatable, Sendable {
    public private(set) var level = 0
    public private(set) var board = AntBoardState()
    public private(set) var history: [AntBoardState] = []
    public private(set) var hint: String?
    public init() {}
    public var task: AntCarryTask { AntCarryTask.all[level] }
    public var isSolved: Bool { board.removed.count == task.pixelCount }
    public var isStuck: Bool { !isSolved && board.slots.allSatisfy {$0 != nil} && !board.slots.compactMap({$0}).contains { load in task.exposed(removed:board.removed).contains {task.pixels[$0] == task.workers[load.worker].color} } }
    public func nextWorker(in lane: Int) -> AntWorker? {
        guard (0..<3).contains(lane),board.used[lane] < task.queues[lane].count else { return nil }
        return task.workers[task.queues[lane][board.used[lane]]]
    }
    @discardableResult public mutating func dispatch(_ lane: Int) -> [AntMove] {
        guard !isSolved,let worker=nextWorker(in:lane),let free=board.slots.firstIndex(where:{$0 == nil}) else { hint="三个等候位满了，退一步换个顺序试试。";return [] }
        history.append(board);board.used[lane] += 1;board.slots[free] = .init(worker:worker.id,collected:0)
        var moves=[AntMove](),changed=true
        while changed {
            changed=false
            for slot in 0..<3 {
                guard var load=board.slots[slot] else { continue }
                let w=task.workers[load.worker]
                while load.collected < w.capacity,let cell=task.exposed(removed:board.removed).first(where:{task.pixels[$0] == w.color}) {
                    board.removed.insert(cell);load.collected += 1;changed=true
                    moves.append(.init(id:moves.count,cell:cell,color:w.color,slot:slot))
                }
                board.slots[slot]=load.collected == w.capacity ? nil : load
            }
        }
        hint=isStuck ? "等候位都占住了，退一步，先派能搬到颜色的小队。" : moves.isEmpty ? "小队先在这里等着，派其他颜色来打开路吧。" : nil
        return moves
    }
    public mutating func undo() { guard let old=history.popLast() else { return };board=old;hint=nil }
    public mutating func reset() { board = .init();history=[];hint=nil }
    public mutating func next() { guard isSolved else { return };level=(level+1)%AntCarryTask.all.count;reset() }
    public var isValid: Bool {
        guard AntCarryTask.all.indices.contains(level),history.count <= 100 else { return false }
        func valid(_ state: AntBoardState) -> Bool {
            guard state.used.count == 3,state.slots.count == 3,state.removed.allSatisfy({task.pixels.indices.contains($0) && task.pixels[$0] != nil}) else { return false }
            var dispatched=Set<Int>()
            for lane in 0..<3 { guard (0...task.queues[lane].count).contains(state.used[lane]) else { return false };dispatched.formUnion(task.queues[lane].prefix(state.used[lane])) }
            let loads=state.slots.compactMap {$0}
            guard Set(loads.map(\.worker)).count == loads.count else { return false }
            for load in loads { guard dispatched.contains(load.worker),(0..<task.workers[load.worker].capacity).contains(load.collected) else { return false } }
            for color in 0..<4 {
                let expected=dispatched.filter {task.workers[$0].color == color}.reduce(0) {$0+task.workers[$1].capacity} - loads.filter {task.workers[$0.worker].color == color}.reduce(0) {$0+task.workers[$1.worker].capacity-$1.collected}
                if expected != state.removed.filter({task.pixels[$0] == color}).count { return false }
            }
            return true
        }
        return valid(board) && history.allSatisfy(valid)
    }
}
