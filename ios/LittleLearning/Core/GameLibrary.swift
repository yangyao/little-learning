import Foundation

public enum LearningGame: String, Codable, CaseIterable, Identifiable, Sendable {
    case numberLine, sharing, pinyin, characters, idioms, bakery, clock, matches, sorting, printing, tangram, delivery, beads
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .numberLine: return "荷叶跳跳"
        case .sharing: return "森林野餐"
        case .pinyin: return "拼音火车"
        case .characters: return "拼字工坊"
        case .idioms: return "成语拼装"
        case .bakery: return "字母面包房"
        case .clock: return "滴答时钟"
        case .matches: return "巧移火柴"
        case .sorting: return "果篮分拣"
        case .printing: return "落叶拓印"
        case .tangram: return "七巧板拼图"
        case .delivery: return "小鸭送信"
        case .beads: return "规律串珠"
        }
    }
    public var subtitle: String {
        switch self {
        case .numberLine: return "跳一跳，学加减"
        case .sharing: return "分一分，一样多"
        case .pinyin: return "接好车厢，读拼音"
        case .characters: return "拼部件，认汉字"
        case .idioms: return "读线索，拼成语"
        case .bakery: return "排字母，烤单词"
        case .clock: return "转指针，认时间"
        case .matches: return "动一根，算式变对"
        case .sorting: return "同款水果装一罐"
        case .printing: return "选叶子，盖一幅画"
        case .tangram: return "移木片，拼轮廓"
        case .delivery: return "排指令，送封信"
        case .beads: return "找规律，串珠子"
        }
    }
    public var symbol: String {
        switch self {
        case .numberLine: return "leaf.fill"
        case .sharing: return "basket.fill"
        case .pinyin: return "tram.fill"
        case .characters: return "square.grid.2x2.fill"
        case .idioms: return "book.closed.fill"
        case .bakery: return "birthday.cake.fill"
        case .clock: return "clock.fill"
        case .matches: return "puzzlepiece.fill"
        case .sorting: return "carrot.fill"
        case .printing: return "paintpalette.fill"
        case .tangram: return "square.on.square.fill"
        case .delivery: return "envelope.fill"
        case .beads: return "circle.hexagongrid.fill"
        }
    }
    public var isNewPuzzle: Bool { [.tangram,.delivery,.beads].contains(self) }
    public var isWorkshop: Bool { [.pinyin, .characters, .idioms, .bakery].contains(self) }
}

public enum PlayPhase: String, Codable, Sendable { case playing, followUp, correct, complete }

public struct SharingTask: Sendable {
    public let food: String, name: String, animal: String
    public let total: Int, bowls: Int
    public var each: Int { total / bowls }
    public var remainder: Int { total % bowls }
    public static let all: [Self] = [
        .init(food: "🍓", name: "草莓", animal: "🐰", total: 6, bowls: 2),
        .init(food: "🥕", name: "胡萝卜", animal: "🐰", total: 8, bowls: 4),
        .init(food: "🍎", name: "苹果", animal: "🐻", total: 12, bowls: 3),
        .init(food: "🍬", name: "糖果", animal: "🐿️", total: 15, bowls: 3),
        .init(food: "🌰", name: "栗子", animal: "🦔", total: 20, bowls: 5)
    ] + ExpandedContent.sharing
}

public struct SharingSession: Codable, Equatable, Sendable {
    public var index = 0
    public private(set) var plates = [0, 0]
    public var phase = PlayPhase.playing
    public var hint: String?
    public var task: SharingTask { SharingTask.all[index] }
    public var remaining: Int { task.total - plates.reduce(0, +) }
    public init(startAt index: Int = 0) {
        precondition(SharingTask.all.indices.contains(index));self.index=index
        plates=Array(repeating:0,count:task.bowls)
    }
    public mutating func give(to bowl: Int) {
        guard phase == .playing, plates.indices.contains(bowl), remaining > 0 else { return }
        plates[bowl] += 1; hint = nil
    }
    public mutating func take(from bowl: Int) {
        guard phase == .playing, plates.indices.contains(bowl), plates[bowl] > 0 else { return }
        plates[bowl] -= 1; hint = nil
    }
    @discardableResult public mutating func check() -> Bool {
        guard phase == .playing else { return false }
        if remaining == task.remainder && plates.allSatisfy({ $0 == task.each }) { phase = .correct; hint = nil; return true }
        hint = remaining > task.remainder ? "还有 \(remaining-task.remainder) 个可以继续分，再分一分。" : "每一盘要一样多；不够再分一轮的留在篮子里。可以拿回来重分。"
        return false
    }
    public mutating func next() {
        guard phase == .correct else { return }
        if index + 1 == SharingTask.all.count { phase = .complete; return }
        index += 1; plates = Array(repeating: 0, count: task.bowls); phase = .playing; hint = nil
    }
    public mutating func reset() { plates = Array(repeating: 0, count: task.bowls); phase = .playing; hint = nil }
    public var isValid: Bool {
        guard SharingTask.all.indices.contains(index) else { return false }
        guard [.playing,.correct,.complete].contains(phase), plates.count == task.bowls && plates.allSatisfy({ (0...task.total).contains($0) }) && plates.reduce(0,+) <= task.total else { return false }
        return phase == .playing || (remaining == task.remainder && plates.allSatisfy({ $0 == task.each }) && (phase != .complete || index == SharingTask.all.count-1))
    }
}

public struct WorkshopQuestion: Sendable {
    public let title: String, clue: String, picture: String
    public let answer: [String], extras: [String], labels: [String]
    public let word: String, reading: String, explanation: String
    public var followUp: String = ""
    public var choices: [String] = []
    public var correctChoice = 0
    public var layout = "row"
    public var pool: [String] { answer + extras }
}

public struct WorkshopSession: Codable, Equatable, Sendable {
    public var index = 0
    public var phase = PlayPhase.playing
    public private(set) var chosen: [Int] = []
    public var hint: String?
    public init(startAt index: Int = 0) { self.index=index }
    public mutating func choose(_ tile: Int, question: WorkshopQuestion) {
        guard phase == .playing, question.pool.indices.contains(tile), !chosen.contains(tile), chosen.count < question.answer.count else { return }
        chosen.append(tile); hint = nil
    }
    public mutating func remove(at slot: Int) {
        guard phase == .playing, chosen.indices.contains(slot) else { return }
        chosen.remove(at: slot); hint = nil
    }
    @discardableResult public mutating func check(_ q: WorkshopQuestion) -> Bool {
        guard phase == .playing else { return false }
        if chosen.map({ q.pool[$0] }) == q.answer {
            phase = q.choices.isEmpty ? .correct : .followUp; hint = nil; return true
        }
        hint = chosen.count < q.answer.count ? "还有空位，把零件放齐再试试。" : "再看看顺序；点上面的零件可以拿回来。"
        return false
    }
    public mutating func answerFollowUp(_ choice: Int, question: WorkshopQuestion) {
        guard phase == .followUp, question.choices.indices.contains(choice) else { return }
        if choice == question.correctChoice { phase = .correct; hint = nil }
        else { hint = "再想一想。\(question.followUp)" }
    }
    public mutating func next(total: Int) {
        guard phase == .correct else { return }
        if index + 1 == total { phase = .complete; return }
        index += 1; phase = .playing; chosen = []; hint = nil
    }
    public mutating func reset() { chosen = []; hint = nil; phase = .playing }
    public func isValid(for questions: [WorkshopQuestion]) -> Bool {
        guard questions.indices.contains(index) else { return false }
        let q = questions[index]
        guard chosen.count <= q.answer.count && Set(chosen).count == chosen.count && chosen.allSatisfy({ q.pool.indices.contains($0) }) else { return false }
        if phase == .playing { return true }
        return chosen.map({q.pool[$0]}) == q.answer && (phase != .followUp || !q.choices.isEmpty) && (phase != .complete || index == questions.count-1)
    }
}

public struct ClockTask: Sendable {
    public enum Mode: Sendable, Equatable { case set, elapsed, seconds, conversion }
    public let mode: Mode
    public let title: String, prompt: String, tip: String
    public let start: Int, target: Int
    public var choices: [String] = []
    public var correctChoice = 0
    public static let all: [Self] = [
        .init(mode:.set, title:"认整点", prompt:"把时钟拨到 3 时整", tip:"分针指着 12，时针指着 3。", start:0, target:180),
        .init(mode:.set, title:"认整点", prompt:"把时钟拨到 9 时整", tip:"先选时针，再点钟面的 9。", start:180, target:540),
        .init(mode:.set, title:"认分钟", prompt:"把时钟拨到 6 时 30 分", tip:"分针指到 6，就是 30 分。时针在 6 和 7 中间。", start:360, target:390),
        .init(mode:.set, title:"认分钟", prompt:"把时钟拨到 12 时 15 分", tip:"分针指到 3，就是 15 分。", start:0, target:15),
        .init(mode:.set, title:"指针一起走", prompt:"把时钟拨到 11 时 45 分", tip:"分针指到 9；时针会自动往 12 靠近。", start:660, target:705),
        .init(mode:.elapsed, title:"经过时间", prompt:"8 时 20 分，再过 35 分是几点？", tip:"20 加 35 是 55 分。", start:500, target:535),
        .init(mode:.elapsed, title:"经过时间", prompt:"10 时 50 分，再过 25 分是几点？", tip:"75 分可以换成 1 时 15 分。", start:650, target:675),
        .init(mode:.seconds, title:"认秒针", prompt:"把秒针拨到 25 秒", tip:"秒针走到数字 5，就是 25 秒。", start:0, target:25),
        .init(mode:.seconds, title:"认秒针", prompt:"把秒针拨到 40 秒", tip:"秒针走到数字 8，就是 40 秒。", start:0, target:40),
        .init(mode:.elapsed, title:"时间换算", prompt:"8 时整，再过 100 分是几点？", tip:"100 分等于 1 时 40 分。", start:480, target:580),
        .init(mode:.conversion, title:"时间换算", prompt:"1 时 20 分，一共是几分钟？", tip:"1 时是 60 分，再加 20 分。", start:0, target:80, choices:["80 分","120 分","60 分"], correctChoice:0),
        .init(mode:.conversion, title:"时间换算", prompt:"2 分钟，一共是几秒？", tip:"每分钟有 60 秒。", start:0, target:120, choices:["60 秒","120 秒","200 秒"], correctChoice:1)
    ] + ExpandedContent.clock
    public static func text(_ minutes: Int) -> String { "\(minutes / 60 == 0 ? 12 : minutes / 60):\(String(format:"%02d",minutes % 60))" }
}

public struct ClockSession: Codable, Equatable, Sendable {
    public enum Hand: String, Codable, Sendable { case hour, minute, second }
    public var index = 0
    public var minutes = 0
    public var seconds = 0
    public var hand = Hand.hour
    public var phase = PlayPhase.playing
    public var hint: String?
    public var task: ClockTask { ClockTask.all[index] }
    public init(startAt index: Int = 0) {
        precondition(ClockTask.all.indices.contains(index));self.index=index
        minutes=task.start;hand=task.mode == .seconds ? .second : .hour
    }
    public mutating func select(_ h: Hand) { guard phase == .playing else { return }; hand = h }
    public mutating func setTick(_ tick: Int, carry: Bool = false) {
        guard phase == .playing, (0..<60).contains(tick) else { return }
        switch hand {
        case .hour: minutes = ((tick + 2) / 5 % 12) * 60 + minutes % 60
        case .minute:
            var hour = minutes / 60
            if carry, tick - minutes % 60 < -30 { hour += 1 }
            if carry, tick - minutes % 60 > 30 { hour -= 1 }
            minutes = (hour + 12) % 12 * 60 + tick
        case .second: seconds = tick
        }
        hint = nil
    }
    public mutating func nudge(_ amount: Int) {
        guard phase == .playing else { return }
        if hand == .second { seconds = (seconds + amount % 60 + 60) % 60 }
        else if hand == .hour { minutes = (minutes + (amount % 12) * 60 + 720) % 720 }
        else { minutes = (minutes + amount % 720 + 720) % 720 }
        hint = nil
    }
    @discardableResult public mutating func check(choice: Int? = nil) -> Bool {
        guard phase == .playing else { return false }
        let correct = task.mode == .conversion ? choice == task.correctChoice : (task.mode == .seconds ? seconds == task.target : minutes == task.target)
        if correct { phase = .correct; hint = nil; return true }
        hint = task.tip; return false
    }
    public mutating func next() {
        guard phase == .correct else { return }
        if index + 1 == ClockTask.all.count { phase = .complete; return }
        index += 1; minutes = task.start; seconds = 0
        hand = task.mode == .seconds ? .second : .hour; phase = .playing; hint = nil
    }
    public var isValid: Bool {
        guard ClockTask.all.indices.contains(index), (0..<720).contains(minutes), (0..<60).contains(seconds), [.playing,.correct,.complete].contains(phase) else { return false }
        guard phase != .complete || index == ClockTask.all.count-1 else { return false }
        return phase == .playing || task.mode == .conversion || (task.mode == .seconds ? seconds == task.target : minutes == task.target)
    }
}

public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
