import Foundation

public struct StudyGroup: Identifiable, Sendable {
    public let id: String, game: LearningGame, title: String, shortTitle: String, detail: String, stage: String
    public var indices: [Int] = []
    public var arithmetic: [ArithmeticQuestion] = []
    public var limit = 10
    public var count: Int { game == .numberLine ? arithmetic.count : indices.count }
    public var challenges: [RewardChallenge] {
        if game == .numberLine { return arithmetic.map(RewardCatalog.arithmetic) }
        return indices.map { challenge(at:$0) }
    }
    public func challenge(at index: Int) -> RewardChallenge {
        switch game {
        case .sharing: return RewardCatalog.sharing(SharingTask.all[index])
        case .clock: return RewardCatalog.clock(ClockTask.all[index])
        case .matches: return RewardCatalog.matches(MatchPuzzle.all[index])
        case .sorting: return RewardCatalog.sorting(index)
        case .tangram,.delivery,.beads:return RewardCatalog.puzzle(game,index)
        default: return RewardCatalog.workshop(game,WorkshopContent.questions(for:game)[index])
        }
    }
    public func remaining(in ledger: RewardLedger) -> Int {
        let earned=ledger.awardedIDs
        return challenges.filter { !earned.contains($0.id) }.count
    }
}

public enum StudyCatalog {
    public static let all: [StudyGroup] = {
        var result: [StudyGroup]=[]
        func arithmetic(_ id: String,_ title: String,_ stage: String,_ limit: Int,_ pairs: [(Int,Int)]) {
            let bank=pairs.map { ArithmeticQuestion(start:$0.0,change:$0.1) }
            result.append(.init(id:id,game:.numberLine,title:title,shortTitle:title,detail:"8道精选题，用荷叶理解加减",stage:stage,arithmetic:bank,limit:limit))
        }
        arithmetic("arithmetic-5","5以内加减","学龄前参考",5,[(1,1),(2,1),(1,3),(2,3),(3,-1),(4,-2),(5,-1),(4,-4)])
        arithmetic("arithmetic-10-add","10以内加法","启蒙／一年级参考",10,[(1,5),(2,4),(3,4),(4,4),(5,4),(6,4),(7,2),(8,2)])
        arithmetic("arithmetic-10-subtract","10以内减法","启蒙／一年级参考",10,[(6,-1),(6,-4),(7,-2),(7,-5),(8,-3),(9,-4),(10,-3),(10,-6)])
        func group(_ game: LearningGame,_ id: String,_ title: String,_ detail: String,_ stage: String,_ indices: [Int]) {
            if !indices.isEmpty { result.append(.init(id:id,game:game,title:title,shortTitle:title,detail:detail,stage:stage,indices:indices)) }
        }
        let sharing=SharingTask.all
        group(.sharing,"sharing-hands","动手平均分","10个以内，用实物分得一样多","学龄前／一年级参考",sharing.indices.filter { sharing[$0].remainder == 0 && sharing[$0].total <= 10 })
        group(.sharing,"sharing-division","认识除法","平均分后认识除法算式","二年级参考",sharing.indices.filter { sharing[$0].remainder == 0 })
        group(.sharing,"sharing-remainder","分完还有剩余","每份一样多，剩下的不够再分一轮","二年级进阶参考",sharing.indices.filter { sharing[$0].remainder > 0 })
        let pinyin=WorkshopContent.pinyin
        for (id,title,stations,detail) in [
            ("pinyin-start","声调与两拼",["声调站"],"分清声调，拼接声母和韵母"),
            ("pinyin-vowels","复韵母与鼻音",["复韵母站","鼻音站"],"辨认复韵母、前后鼻音"),
            ("pinyin-three","三拼音节",["三拼站"],"练习声母、介母、韵母"),
            ("pinyin-tongue","平翘舌辨认",["翘舌站"],"留意 z/zh、c/ch、s/sh"),
            ("pinyin-whole","整体认读",["整体认读站"],"把整体认读音节记清楚")
        ] { group(.pinyin,id,title,detail,"按拼音学习进度",pinyin.indices.filter { stations.contains(pinyin[$0].title) }) }
        let characters=WorkshopContent.characters
        group(.characters,"characters-start","常见组合字","从熟悉的部件开始拼字","识字入门",Array(characters.indices.prefix(20)))
        group(.characters,"characters-radicals","偏旁部首","认识提手旁、三点水等常用偏旁","识字基础",Array(characters.indices.dropFirst(20)))
        let similar=Set(["清","晴","请","情","睛","妈","吗","河","和","时","诗","记","计","林","森"])
        group(.characters,"characters-similar","易混字辨认","看部件，也结合句子辨读音","识字进阶",characters.indices.filter { similar.contains(characters[$0].word) })
        let idioms=WorkshopContent.idioms
        let animals=Set(["画蛇添足","守株待兔","亡羊补牢","井底之蛙","狐假虎威","对牛弹琴","盲人摸象","惊弓之鸟","叶公好龙","骑虎难下"])
        let methods=Set(["刻舟求剑","拔苗助长","画龙点睛","一举两得","半途而废","水滴石穿","熟能生巧","聚沙成塔","胸有成竹","闻鸡起舞"])
        group(.idioms,"idioms-animals","动物故事","读故事线索，再选合适的情境","故事入门",idioms.indices.filter { animals.contains(idioms[$0].word) })
        group(.idioms,"idioms-methods","做事的方法","从故事里理解做事的道理","理解练习",idioms.indices.filter { methods.contains(idioms[$0].word) })
        group(.idioms,"idioms-judgment","观察与判断","结合线索和情境判断意思","理解进阶",idioms.indices.filter { !animals.contains(idioms[$0].word) && !methods.contains(idioms[$0].word) })
        let words=WorkshopContent.bakery
        group(.bakery,"english-short","3字母单词","听英文、看图片，拼短单词","英语入门",words.indices.filter { words[$0].reading.count <= 3 })
        group(.bakery,"english-common","4至5字母单词","练习常见生活单词","英语基础",words.indices.filter { (4...5).contains(words[$0].reading.count) })
        group(.bakery,"english-long","6至8字母单词","留意长单词的字母顺序","英语进阶",words.indices.filter { words[$0].reading.count >= 6 })
        let clocks=ClockTask.all
        group(.clock,"clock-hours","认识整点","分针指12，先认识时针","一年级参考",clocks.indices.filter { clocks[$0].mode == .set && clocks[$0].target%60 == 0 })
        group(.clock,"clock-halves","认识半点与一刻","认识15分、30分、45分","基础认钟",clocks.indices.filter { clocks[$0].mode == .set && [15,30,45].contains(clocks[$0].target%60) })
        group(.clock,"clock-minutes","分钟与秒针","练习五分刻度和秒针","二年级参考",clocks.indices.filter { clocks[$0].mode == .seconds || (clocks[$0].mode == .set && clocks[$0].target%15 != 0) })
        group(.clock,"clock-elapsed","经过时间与换算","分钟满60进1时，练习时间关系","二年级进阶参考",clocks.indices.filter { clocks[$0].mode == .elapsed || clocks[$0].mode == .conversion })
        for tier in 0...2 {
            let titles=["10以内加法·同数移动","10以内加法·跨数移动","20以内加减综合"]
            let details=["在一个数字里移动一根，等号不动","火柴可以在不同数字之间移动","可能需要改变加减号，等号不动"]
            group(.matches,"matches-\(tier)",titles[tier],details[tier],tier == 0 ? "已学10以内加法" : tier == 1 ? "加法推理进阶" : "已学20以内加减",MatchPuzzle.all.indices.filter { MatchPuzzle.all[$0].studyTier == tier })
        }
        for (id,title,range) in [("sorting-start","两三种水果",2...3),("sorting-middle","四五种水果",4...5),("sorting-advanced","六七种水果",6...7)] {
            group(.sorting,id,title,"同款装一罐，先想好再移动","按空间推理能力",(0..<FruitSession.levelCount).filter { range.contains(FruitSession.colors(for:$0)) })
        }
        for tier in 0..<3 {
            group(.tangram,"tangram-\(tier)",["照分块拼","看轮廓拼","旋转挑战"][tier],["分块线提示位置，木片已经转好方向","没有分块线，自己找木片的位置","自己旋转和翻面，拼满整个轮廓"][tier],"按空间操作能力",Array((tier*8)..<(tier*8+8)))
            group(.delivery,"delivery-\(tier)",["认识方向","绕开障碍","取信再送信"][tier],["先认识前进、左转、右转","路变长了，先想好每次转弯","先去取信，再绕过树木送到邮筒"][tier],"按路线推理能力",Array((tier*12)..<(tier*12+12)))
            group(.beads,"beads-\(tier)",["接着串","补中间","形状与颜色"][tier],["观察一组珠子，接着串下一颗","找到重复的一组，补好两个缺口","形状和颜色各有规律，要一起看"][tier],tier == 0 ? "学龄前参考" : "规律进阶",Array((tier*20)..<(tier*20+20)))
        }
        return result
    }()
    public static func groups(for game: LearningGame) -> [StudyGroup] { all.filter { $0.game == game } }
    public static func group(_ id: String,for game: LearningGame) -> StudyGroup? { all.first { $0.id == id && $0.game == game } }
}

public struct StudyProgress: Codable, Equatable, Sendable {
    public var selected: [String:String] = [:]
    public var reviewing: Set<String> = []
    public var finished: Set<String> = []
    public init() {}
    public var isValid: Bool {
        selected.allSatisfy { key,value in LearningGame(rawValue:key).flatMap { StudyCatalog.group(value,for:$0) } != nil } &&
        reviewing.isSubset(of:Set(selected.keys)) && finished.isSubset(of:Set(selected.keys))
    }
}

extension MatchPuzzle {
    public var studyTier: Int? {
        guard let (a,b,_,plus)=Self.decode(initial), let (x,y,_,solutionPlus)=Self.decode(solution), plus || a >= b else { return nil }
        if plus && solutionPlus && a+b <= 10 && x+y <= 10 {
            let removed=initial & ~solution, added=solution & ~initial
            let from=removed.trailingZeroBitCount, to=added.trailingZeroBitCount
            return from < 21 && to < 21 && from/7 == to/7 ? 0 : 1
        }
        return 2
    }
}
