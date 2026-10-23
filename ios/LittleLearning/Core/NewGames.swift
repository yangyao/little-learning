import Foundation

public struct GridPoint: Codable, Hashable, Sendable {
    public var x: Int, y: Int
    public init(_ x: Int,_ y: Int) { self.x=x;self.y=y }
}

public struct TangramPlacement: Codable, Equatable, Sendable {
    public var x: Int, y: Int, rotation: Int, flipped: Bool
    public init(x: Int,y: Int,rotation: Int=0,flipped: Bool=false) { self.x=x;self.y=y;self.rotation=rotation;self.flipped=flipped }
}
public enum TangramGeometry {
    public static let base: [[GridPoint]] = [
        [GridPoint(0,0),GridPoint(4,0),GridPoint(2,2)],
        [GridPoint(0,0),GridPoint(4,0),GridPoint(2,2)],
        [GridPoint(0,0),GridPoint(2,0),GridPoint(0,2)],
        [GridPoint(0,0),GridPoint(2,0),GridPoint(1,1)],
        [GridPoint(0,0),GridPoint(2,0),GridPoint(1,1)],
        [GridPoint(1,0),GridPoint(2,1),GridPoint(1,2),GridPoint(0,1)],
        [GridPoint(1,0),GridPoint(1,2),GridPoint(0,3),GridPoint(0,1)]
    ]
    public static func polygon(_ piece: Int,_ placement: TangramPlacement) -> [GridPoint] {
        var p=base[piece]
        if placement.flipped { p=p.map { GridPoint(-$0.x,$0.y) } }
        for _ in 0..<placement.rotation { p=p.map { GridPoint(-$0.y,$0.x) } }
        let minX=p.map(\.x).min()!, minY=p.map(\.y).min()!
        return p.map { GridPoint($0.x-minX+placement.x,$0.y-minY+placement.y) }
    }
    public static func contains(_ p: [GridPoint],x: Double,y: Double) -> Bool {
        let values=p.indices.map { i -> Double in
            let a=p[i],b=p[(i+1)%p.count]
            return Double(b.x-a.x)*(y-Double(a.y))-Double(b.y-a.y)*(x-Double(a.x))
        }
        return values.allSatisfy {$0 >= -0.00001} || values.allSatisfy {$0 <= 0.00001}
    }
    public static func coverage(_ piece: Int,_ placement: TangramPlacement) -> Set<Int> {
        let p=polygon(piece,placement)
        let offsets=[(0.5,1.0/6),(5.0/6,0.5),(0.5,5.0/6),(1.0/6,0.5)]
        var result=Set<Int>()
        for y in 0..<7 { for x in 0..<7 { for (k,o) in offsets.enumerated() {
            if contains(p,x:Double(x)+o.0,y:Double(y)+o.1) { result.insert((y*7+x)*4+k) }
        } } }
        return result
    }
    public static func inBounds(_ piece: Int,_ p: TangramPlacement) -> Bool {
        guard (0...7).contains(p.x),(0...7).contains(p.y),(0..<4).contains(p.rotation) else { return false }
        return polygon(piece,p).allSatisfy { (0...7).contains($0.x) && (0...7).contains($0.y) }
    }
}
public struct TangramTask: Sendable {
    public let index: Int, solution: [TangramPlacement]
    public var tier: Int { index/8 }
    public var target: Set<Int> { solution.enumerated().reduce(into:Set<Int>()) { $0.formUnion(TangramGeometry.coverage($1.offset,$1.element)) } }
    public static let all: [Self] = TangramLayouts.all.enumerated().map { i,layout in
        .init(index:i,solution:layout.map { .init(x:$0[0],y:$0[1],rotation:$0[2],flipped:$0[3] == 1) })
    }
}
public struct TangramSession: Codable, Equatable, Sendable {
    public var index: Int
    public private(set) var pieces: [TangramPlacement?] = Array(repeating:nil,count:7)
    public private(set) var selected = 0
    public private(set) var turns = Array(repeating:0,count:7)
    public private(set) var flips = Array(repeating:false,count:7)
    public private(set) var phase = PlayPhase.playing
    public private(set) var hint: String?
    public init(startAt: Int=0) {
        index=startAt
        if startAt < 16 { turns=TangramTask.all[startAt].solution.map(\.rotation);flips=TangramTask.all[startAt].solution.map(\.flipped) }
    }
    public var task: TangramTask { TangramTask.all[index] }
    public mutating func select(_ piece: Int) { guard phase == .playing,(0..<7).contains(piece) else { return };selected=piece;hint=nil }
    public mutating func rotate() {
        guard phase == .playing else { return };turns[selected]=(turns[selected]+1)%4
        if var p=pieces[selected] { p.rotation=turns[selected];if TangramGeometry.inBounds(selected,p) { pieces[selected]=p } else { pieces[selected]=nil;hint="旋转后超出拼板，点格子重新放下。" } }
    }
    public mutating func flip() {
        guard phase == .playing, selected == 6 else { return };flips[6].toggle()
        if var p=pieces[6] { p.flipped=flips[6];pieces[6]=p }
    }
    public mutating func place(x: Int,y: Int) {
        guard phase == .playing else { return }
        let p=TangramPlacement(x:x,y:y,rotation:turns[selected],flipped:flips[selected])
        guard TangramGeometry.inBounds(selected,p) else { hint="这块超出拼板了，往里面移一点。";return }
        pieces[selected]=p;hint=nil
    }
    public mutating func remove() { guard phase == .playing else { return };pieces[selected]=nil;hint=nil }
    public mutating func reset() { self = .init(startAt:index) }
    public var matchesTarget: Bool {
        var covered=Set<Int>()
        for i in 0..<7 {
            guard let p=pieces[i],TangramGeometry.inBounds(i,p) else { return false }
            let c=TangramGeometry.coverage(i,p)
            guard covered.isDisjoint(with:c) else { return false };covered.formUnion(c)
        }
        return covered == task.target
    }
    public mutating func check() {
        guard phase == .playing else { return }
        if matchesTarget { phase = .correct;hint=nil }
        else { hint=pieces.contains(where:{$0 == nil}) ? "七块都要用上，再对照轮廓试试。" : "看看有没有重叠、空隙，或伸出轮廓的地方。" }
    }
    public var isValid: Bool {
        guard TangramTask.all.indices.contains(index), pieces.count == 7,turns.count == 7,flips.count == 7,(0..<7).contains(selected),turns.allSatisfy({(0..<4).contains($0)}),phase == .playing || phase == .correct else { return false }
        for i in 0..<7 { if let p=pieces[i] {
            guard (0..<4).contains(p.rotation),p.rotation == turns[i],p.flipped == flips[i],TangramGeometry.inBounds(i,p) else { return false }
        } }
        return phase != .correct || matchesTarget
    }
}

public enum RouteCommand: String, Codable, CaseIterable, Sendable {
    case forward, left, right
    public var title: String { switch self { case .forward:return "前进";case .left:return "左转";case .right:return "右转" } }
    public var symbol: String { switch self { case .forward:return "arrow.up";case .left:return "arrow.turn.up.left";case .right:return "arrow.turn.up.right" } }
}
public struct RouteFrame: Equatable, Sendable {
    public let point: GridPoint, heading: Int, collected: Bool
    public init(point: GridPoint,heading: Int,collected: Bool) { self.point=point;self.heading=heading;self.collected=collected }
}
// Seeds, ordering and geometry are part of the saved challenge identity. Append new banks rather than reshuffling these.
public struct RouteTask: Sendable {
    public let index: Int, size: Int, start: GridPoint, goal: GridPoint, pickup: GridPoint?, obstacles: Set<GridPoint>, solution: [RouteCommand]
    public var tier: Int { index/12 }
    public static let directions=[GridPoint(1,0),GridPoint(0,1),GridPoint(-1,0),GridPoint(0,-1)]
    public func trace(_ commands: [RouteCommand]) -> (frames:[RouteFrame],success:Bool,message:String) {
        var p=start,h=0,collected=pickup == nil
        var frames=[RouteFrame(point:p,heading:h,collected:collected)]
        for command in commands {
            switch command {
            case .left:h=(h+3)%4
            case .right:h=(h+1)%4
            case .forward:
                let d=Self.directions[h],next=GridPoint(p.x+d.x,p.y+d.y)
                guard (0..<size).contains(next.x),(0..<size).contains(next.y),!obstacles.contains(next) else {
                    return (frames,false,"前面走不通，修改指令再试试。")
                };p=next
            }
            if p == pickup { collected=true }
            frames.append(.init(point:p,heading:h,collected:collected))
        }
        let success=p == goal && collected
        return (frames,success,success ? "信送到了！" : p == goal ? "先去信封处取信，再送到邮筒。" : "还没到邮筒，看看方向和前进步数。")
    }
    public static let all: [Self] = {
        var result=[Self](),seen=Set<String>()
        var seed=0
        while result.count < 36 {
            seed += 1
            let tier=result.count/12,n=4+tier,start=GridPoint(0,n-1),goal=GridPoint(n-1,0)
            var rng=SeededRandom(seed:UInt64(seed*7919+53))
            let candidates=(0..<n).flatMap { y in (0..<n).map { GridPoint($0,y) } }.filter { $0 != start && $0 != goal }
            let shuffled=candidates.shuffled(using:&rng),obstacles=Set(shuffled.prefix(tier == 0 ? 3 : tier == 1 ? 6 : 8))
            let pickup: GridPoint?=tier == 2 ? shuffled.dropFirst(8).first : nil
            func path(_ from: GridPoint,_ to: GridPoint) -> [GridPoint]? {
                var queue=[from],visited:Set<GridPoint>=[from],parent=[GridPoint:GridPoint](),cursor=0
                while cursor < queue.count {
                    let p=queue[cursor];cursor += 1
                    if p == to {
                        var route=[p],q=p
                        while q != from { q=parent[q]!;route.append(q) }
                        return route.reversed()
                    }
                    for d in directions.shuffled(using:&rng) {
                        let q=GridPoint(p.x+d.x,p.y+d.y)
                        if (0..<n).contains(q.x),(0..<n).contains(q.y),!obstacles.contains(q),visited.insert(q).inserted { parent[q]=p;queue.append(q) }
                    }
                }
                return nil
            }
            guard let first=path(start,pickup ?? goal) else { continue }
            var route=first
            if let pickup { guard let second=path(pickup,goal) else { continue };route += second.dropFirst() }
            var commands=[RouteCommand](),heading=0
            for (a,b) in zip(route,route.dropFirst()) {
                let direction=directions.firstIndex(of:GridPoint(b.x-a.x,b.y-a.y))!
                let turn=(direction-heading+4)%4
                if turn == 1 { commands.append(.right) };if turn == 3 { commands.append(.left) };if turn == 2 { commands += [.right,.right] }
                commands.append(.forward);heading=direction
            }
            guard commands.count <= 28 else { continue }
            let signature="\(n):\(obstacles.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }):\(String(describing:pickup))"
            guard seen.insert(signature).inserted else { continue }
            result.append(.init(index:result.count,size:n,start:start,goal:goal,pickup:pickup,obstacles:obstacles,solution:commands))
        }
        return result
    }()
}
public struct RouteSession: Codable, Equatable, Sendable {
    public var index: Int
    public private(set) var commands: [RouteCommand] = []
    public private(set) var phase = PlayPhase.playing
    public private(set) var hint: String?
    public init(startAt: Int=0) { index=startAt }
    public var task: RouteTask { RouteTask.all[index] }
    public mutating func append(_ c: RouteCommand) { guard phase == .playing,commands.count < 40 else { return };commands.append(c);hint=nil }
    public mutating func remove(at i: Int) { guard phase == .playing,commands.indices.contains(i) else { return };commands.remove(at:i);hint=nil }
    public mutating func reset() { self = .init(startAt:index) }
    public mutating func check() {
        guard phase == .playing else { return }
        let result=task.trace(commands);hint=result.message
        if result.success { phase = .correct }
    }
    public var isValid: Bool { RouteTask.all.indices.contains(index) && commands.count <= 40 && (phase == .playing || phase == .correct) && (phase != .correct || task.trace(commands).success) }
}

public struct BeadToken: Codable, Hashable, Sendable {
    public let shape: Int, color: Int
    public var symbol: String { ["circle.fill","triangle.fill","square.fill","star.fill","diamond.fill","heart.fill"][shape] }
    public var name: String { ["圆形","三角","方形","星形","菱形","爱心"][shape] + ["橙色","绿色","蓝色","紫色"][color] }
}
public struct BeadTask: Sendable {
    public let index: Int, sequence: [BeadToken], blanks: [Int], options: [BeadToken], explanation: String
    public var tier: Int { index/20 }
    public static let all: [Self] = {
        var result=[Self](),seen=Set<String>()
        var seed=0
        while result.count < 60 {
            seed += 1
            let tier=result.count/20
            var rng=SeededRandom(seed:UInt64(seed*2039+17))
            let shapes=Array(0..<6).shuffled(using:&rng),colors=Array(0..<4).shuffled(using:&rng)
            let patterns=tier == 0 ? [[0,1],[0,0,1],[0,1,2]] : [[0,1,1],[0,0,1,2],[0,1,2,1],[0,1,2,3]]
            let pattern=patterns[(seed-1)%patterns.count],length=tier == 0 ? 7 : 9
            let sequence=(0..<length).map { i -> BeadToken in
                let k=pattern[i%pattern.count]
                return .init(shape:shapes[k],color:colors[tier == 2 ? i%3 : k%4])
            }
            let blanks=tier == 0 ? [length-1] : tier == 1 ? [4,7] : [5,8]
            var options=Array(Set(sequence))
            if tier == 2 { options=Array(Set(sequence + sequence.map { .init(shape:$0.shape,color:colors[($0.color+1)%4]) })) }
            options.sort { $0.shape == $1.shape ? $0.color < $1.color : $0.shape < $1.shape };options.shuffle(using:&rng)
            let key=sequence.map { "\($0.shape)\($0.color)" }.joined()+"\(blanks)"
            guard seen.insert(key).inserted else { continue }
            let explanation=tier == 2 ? "形状按一组重复，颜色按另一组重复，要一起看。" : "每\(pattern.count)颗是一组，按同样的顺序重复。"
            result.append(.init(index:result.count,sequence:sequence,blanks:blanks,options:options,explanation:explanation))
        }
        return result
    }()
}
public struct BeadSession: Codable, Equatable, Sendable {
    public var index: Int
    public private(set) var answers: [BeadToken?]
    public private(set) var active = 0
    public private(set) var phase = PlayPhase.playing
    public private(set) var hint: String?
    public init(startAt: Int=0) { index=startAt;answers=Array(repeating:nil,count:BeadTask.all[startAt].blanks.count) }
    public var task: BeadTask { BeadTask.all[index] }
    public mutating func select(_ i: Int) { guard phase == .playing,answers.indices.contains(i) else { return };active=i }
    public mutating func choose(_ i: Int) {
        guard phase == .playing,task.options.indices.contains(i) else { return }
        answers[active]=task.options[i];hint=nil
        if let next=answers.indices.first(where:{answers[$0] == nil}) { active=next }
    }
    public mutating func reset() { self = .init(startAt:index) }
    public var matches: Bool { zip(answers,task.blanks).allSatisfy { $0.0 == task.sequence[$0.1] } }
    public mutating func check() {
        guard phase == .playing else { return }
        if matches { phase = .correct;hint=nil }
        else { hint=answers.contains(where:{$0 == nil}) ? "还有空位，先把珠子补齐。" : "从头读一遍，找出重复的一组。" }
    }
    public var isValid: Bool {
        BeadTask.all.indices.contains(index) && answers.count == task.blanks.count && answers.indices.contains(active) && answers.compactMap({$0}).allSatisfy { task.options.contains($0) } && (phase == .playing || phase == .correct) && (phase != .correct || matches)
    }
}
