import Foundation

public struct RulerTask: Sendable {
    public enum Mode: String, Sendable { case measure, missingNumber, offset, target, explore }
    public let mode: Mode
    public let marks: [Int]
    public let length: Int
    public let blank: Int?
    public var objectStart: Int { marks[0]+2 }
    public var distances: Set<Int> { Set(marks.flatMap { a in marks.filter {$0 > a}.map {$0-a} }) }
    public var identity: String { "ruler:v1:\(mode.rawValue):\(marks.map(String.init).joined(separator:",")):\(length):\(blank.map(String.init) ?? "-")" }
    public var prompt: String {
        switch mode {
        case .measure:return "移动尺子，从0开始量一量"
        case .missingNumber:return "补上问号处的刻度数字"
        case .offset:return "没有0，也能量出物体的长度"
        case .target:return "找两个刻度，量出\(length)厘米"
        case .explore:return "这把尺能量出哪些长度？"
        }
    }
    public var canMove: Bool { mode == .measure || mode == .offset }
    public static let all: [RulerTask] = {
        var tasks=(1...6).map { RulerTask(mode:.measure,marks:Array(0...8),length:$0,blank:nil) }
        tasks += [3,6].map { .init(mode:.missingNumber,marks:Array(0...8),length:0,blank:$0) }
        for (first,length) in [(2,3),(3,4),(4,2),(5,3),(2,5),(4,5),(6,4),(3,6)] {
            tasks.append(.init(mode:.offset,marks:Array(first...(first+7)),length:length,blank:nil))
        }
        for (marks,length) in [([0,1,4,6],2),([1,3,6,8],5),([0,2,5,9],7),([2,4,7,10],6),([1,2,5,7],4),([0,3,4,8],1)] {
            tasks.append(.init(mode:.target,marks:marks,length:length,blank:nil))
        }
        tasks += [[0,1,4,6],[1,3,6,8]].map { .init(mode:.explore,marks:$0,length:0,blank:nil) }
        return tasks
    }()
}

public struct RulerSession: Codable, Equatable, Sendable {
    public private(set) var index: Int
    public private(set) var origin: Int
    public private(set) var answer: Int?
    public private(set) var first: Int?
    public private(set) var second: Int?
    public private(set) var found: Set<Int> = []
    public private(set) var showUnits = false
    public private(set) var phase = PlayPhase.playing
    public private(set) var hint: String?
    public init(startAt: Int=0) { index=startAt;origin=RulerTask.all[startAt].mode == .offset ? 4 : 0 }
    public var task: RulerTask { RulerTask.all[index] }
    public var pair: [Int] { [first,second].compactMap {$0}.sorted() }
    public var measuredLength: Int? { pair.count == 2 ? pair[1]-pair[0] : nil }
    public var aligned: Bool {
        let a=task.objectStart-origin,b=a+task.length
        return task.marks.contains(a) && task.marks.contains(b) && (task.mode != .measure || a == 0)
    }
    public var matches: Bool {
        switch task.mode {
        case .measure,.offset:return aligned && answer == task.length
        case .missingNumber:return answer == task.blank
        case .target:return measuredLength == task.length
        case .explore:return found == task.distances
        }
    }
    public var explanation: String {
        switch task.mode {
        case .measure:return "数的是间隔：一共\(task.length)厘米。"
        case .missingNumber:return "每格相差1，缺少的是\(task.blank!)。"
        case .offset:let a=task.objectStart-origin;return "\(a+task.length) − \(a) = \(task.length)厘米。"
        case .target:return "\(pair.last ?? 0) − \(pair.first ?? 0) = \(task.length)厘米。"
        case .explore:return "找齐了！能量出\(found.sorted().map(String.init).joined(separator:"、"))厘米。"
        }
    }
    public mutating func move(to value: Int) {
        guard phase == .playing,task.canMove else { return };origin=min(4,max(0,value));hint=nil
    }
    public mutating func choose(_ value: Int) {
        guard phase == .playing,(0...8).contains(value),task.mode != .target,task.mode != .explore else { return };answer=value;hint=nil
    }
    public mutating func tap(_ mark: Int) {
        guard phase == .playing,task.mode == .target || task.mode == .explore,task.marks.contains(mark) else { return }
        if first == nil || second != nil { first=mark;second=nil }
        else if first == mark { first=nil }
        else { second=mark }
        hint=nil
    }
    public mutating func clearPair() { guard phase == .playing else { return };first=nil;second=nil;hint=nil }
    public mutating func revealHint() {
        guard phase == .playing else { return };showUnits=true
        switch task.mode {
        case .measure:hint="让0刻度对齐物体左端，再数中间有几格。"
        case .missingNumber:hint="相邻两条刻线之间是1格，数字每次增加1。"
        case .offset:hint="先让两端对上刻线，再数间隔，或用右端减左端。"
        case .target,.explore:hint="点两个刻度，看它们之间隔了几格。"
        }
    }
    public mutating func check() {
        guard phase == .playing else { return }
        if task.mode == .explore {
            guard let length=measuredLength else { hint="先点两个不同的现存刻度。";return }
            if found.contains(length) { hint="\(length)厘米已经找过了，试试另一种长度。";return }
            found.insert(length)
            if matches { phase = .correct;hint=nil }
            else { hint="找到\(length)厘米！还差\(task.distances.count-found.count)种长度。" }
            return
        }
        if matches { phase = .correct;hint=nil;return }
        if task.canMove && !aligned { hint=task.mode == .measure ? "先移动尺子，让0刻度对齐物体左端。" : "先移动断尺，让物体两端都对上现有刻线。" }
        else if task.mode == .target { hint=measuredLength == nil ? "先点两个不同的现存刻度。" : "这两个刻度之间不是\(task.length)厘米，再找一找。" }
        else { hint=answer == nil ? "先选一个数字，再点量好了。" : "再数一数刻度之间的间隔，可以点提示看看。" }
    }
    public mutating func reset() { self = .init(startAt:index) }
    public var isValid: Bool {
        guard RulerTask.all.indices.contains(index),(0...4).contains(origin),phase == .playing || phase == .correct,
              answer == nil || (0...8).contains(answer!),first == nil || task.marks.contains(first!),second == nil || task.marks.contains(second!),
              second == nil || (first != nil && second != first),found.isSubset(of:task.distances),task.mode == .explore || found.isEmpty else { return false }
        if task.mode != .target && task.mode != .explore && (first != nil || second != nil) { return false }
        if !task.canMove && origin != 0 { return false }
        return phase != .correct || matches
    }
}
