import Foundation

public enum WorkshopContent {
    public static func questions(for game: LearningGame) -> [WorkshopQuestion] {
        switch game {
        case .pinyin: return pinyin
        case .characters: return characters
        case .idioms: return idioms
        case .bakery: return bakery
        default: return []
        }
    }

    static func syllable(_ station: String, _ word: String, _ parts: [String], _ extras: [String], labels: [String] = ["声母","韵母"]) -> WorkshopQuestion {
        let reading = parts.joined().replacingOccurrences(of:"xü",with:"xu").replacingOccurrences(of:"jü",with:"ju").replacingOccurrences(of:"qü",with:"qu")
        return .init(title:station, clue:"给「\(word)」接上拼音车厢", picture:"🚂", answer:parts, extras:extras, labels:labels,
              word:word, reading:reading, explanation:"\(word)的拼音是 \(reading)。" + (parts.contains("ü") ? "ü 和 j、q、x 相拼时，两点省略。" : ""))
    }

    public static let pinyin: [WorkshopQuestion] = [
        syllable("声调站","妈",["m","ā"],["n","á","ǎ","à"]),
        syllable("声调站","禾",["h","é"],["f","ē","ě","è"]),
        syllable("声调站","马",["m","ǎ"],["n","ā","á","à"]),
        syllable("声调站","爸",["b","à"],["p","ā","á","ǎ"]),
        syllable("复韵母站","好",["h","ǎo"],["f","ào","óu","ái"]),
        syllable("复韵母站","来",["l","ái"],["n","ài","éi","ǎi"]),
        syllable("复韵母站","妹",["m","èi"],["n","éi","ì","ài"]),
        syllable("复韵母站","头",["t","óu"],["d","òu","áo","iú"]),
        syllable("三拼站","花",["h","u","ā"],["f","i","á","à"],labels:["声母","介母","韵母"]),
        syllable("三拼站","瓜",["g","u","ā"],["k","i","á","à"],labels:["声母","介母","韵母"]),
        syllable("三拼站","家",["j","i","ā"],["q","u","á","à"],labels:["声母","介母","韵母"]),
        syllable("三拼站","雪",["x","ü","ě"],["s","u","é","è"],labels:["声母","介母","韵母"]),
        syllable("鼻音站","山",["sh","ān"],["s","āng","ǎn","án"]),
        syllable("鼻音站","灯",["d","ēng"],["t","ēn","éng","ěng"]),
        syllable("鼻音站","云",["y","ún"],["w","ǘn","ùn","uán"]),
        syllable("鼻音站","星",["x","īng"],["s","īn","íng","ǐng"]),
        syllable("翘舌站","知",["zh","ī"],["z","í","ǐ","ì"]),
        syllable("翘舌站","诗",["sh","ī"],["s","í","ǐ","ì"]),
        syllable("翘舌站","吃",["ch","ī"],["c","í","ǐ","ì"]),
        syllable("翘舌站","日",["r","ì"],["l","ī","í","ǐ"]),
        syllable("整体认读站","衣",["yī"],["yí","yǐ","yì"],labels:["整体音节"]),
        syllable("整体认读站","五",["wǔ"],["wū","wú","wù"],labels:["整体音节"]),
        syllable("整体认读站","鱼",["yú"],["yū","yǔ","yù"],labels:["整体音节"]),
        syllable("整体认读站","雨",["yǔ"],["yū","yú","yù"],labels:["整体音节"])
    ] + ExpandedContent.pinyin

    static func character(_ word: String, _ parts: [String], _ extras: [String], _ layout: String,
                                  _ clue: String, _ reading: String, _ alternatives: [String], _ usage: String) -> WorkshopQuestion {
        .init(title:"拼汉字，再读一读", clue:clue, picture:"", answer:parts, extras:extras,
              labels:parts.indices.map { "部件 \($0 + 1)" }, word:word, reading:reading, explanation:"\(word) · \(reading)\n\(usage)",
              followUp:"在「\(usage.trimmingCharacters(in:CharacterSet(charactersIn:"。！")))」里，这个字怎么读？", choices:[reading] + alternatives, correctChoice:0, layout:layout)
    }

    public static let characters: [WorkshopQuestion] = [
        character("明",["日","月"],["目","门"],"row","太阳和月亮，一起放光。","míng",["mǐng","mín"],"明亮的月光。"),
        character("休",["亻","木"],["人","禾"],"row","一个人靠着树，歇一歇。","xiū",["xíu","qiū"],"玩累了，休息一下。"),
        character("林",["木","木"],["禾","本"],"row","两棵树，排成一小片。","lín",["líng","lǐn"],"树林里有鸟叫。"),
        character("森",["木","木","木"],["禾","本"],"pyramid","好多树，长得又密又绿。","sēn",["shēn","sēng"],"走进森林。"),
        character("尖",["小","大"],["少","太"],"column","上面小，下面大，顶端细细的。","jiān",["qiān","jiǎn"],"削尖的铅笔。"),
        character("好",["女","子"],["了","亻"],"row","左边女字旁，右边子。","hǎo",["hào","háo"],"今天是个好日子。"),
        character("男",["田","力"],["日","刀"],"column","上面田，下面力。","nán",["lán","nǎn"],"男生和女生一起玩。"),
        character("字",["宀","子"],["安","了"],"column","宝盖头下面一个子，记录说的话。","zì",["zhì","zí"],"认识一个新汉字。"),
        character("早",["日","十"],["目","千"],"column","天亮了，上面日，下面十。","zǎo",["zhǎo","zào"],"早上好！"),
        character("朋",["月","月"],["日","明"],"row","两个月，肩并肩。","péng",["pén","pěng"],"和朋友一起分享。"),
        character("晶",["日","日","日"],["目","昌"],"pyramid","三个日，亮晶晶。","jīng",["jīn","qīng"],"水珠亮晶晶。"),
        character("品",["口","口","口"],["回","吕"],"pyramid","三个口，一口一口尝。","pǐn",["píng","pín"],"细细品尝水果。"),
        character("苗",["艹","田"],["早","申"],"column","草字头，下面田，田里冒出小绿芽。","miáo",["máo","miǎo"],"禾苗慢慢长高。"),
        character("岩",["山","石"],["出","右"],"column","山下面是一块石。","yán",["yǎn","yáng"],"山上有岩石。"),
        character("歪",["不","正"],["上","止"],"column","不正，就是它。","wāi",["wài","wēi"],"帽子戴歪了。"),
        character("信",["亻","言"],["人","音"],"row","单人旁，加上说话的言。","xìn",["xīng","xīn"],"给朋友写一封信。"),
        character("想",["相","心"],["目","木"],"column","上面相，下面心，用心思考。","xiǎng",["xiàng","xiǎn"],"先想一想，再动手。"),
        character("坐",["人","人","土"],["入","士"],"twoTop","两个人在土上，坐下歇歇。","zuò",["zhuò","zuó"],"坐在椅子上。"),
        character("杏",["木","口"],["本","日"],"column","上面木，下面口，一种水果。","xìng",["xìn","xīng"],"杏子熟了。"),
        character("呆",["口","木"],["日","本"],"column","上面口，下面木。","dāi",["dài","tāi"],"他望着窗外发呆。")
    ] + ExpandedContent.characters

    static func idiom(_ word: String, _ clue: String, _ extras: String, _ scene: String, _ wrong: String, _ explanation: String) -> WorkshopQuestion {
        .init(title:"读线索，拼成语", clue:clue, picture:"📜", answer:word.map(String.init), extras:extras.map(String.init), labels:Array(repeating:"",count:4),
              word:word, reading:word, explanation:explanation, followUp:"哪个情境适合用「\(word)」？", choices:[scene,wrong],correctChoice:0)
    }
    public static let idioms: [WorkshopQuestion] = [
        idiom("画蛇添足","蛇已经画好了，还给它加上脚。","龙手尾","作品已经完整，却加了多余装饰。","画一张有四只脚的猫。","做了多余的事，反而弄巧成拙。"),
        idiom("守株待兔","守在树桩旁，等兔子自己撞过来。","树看羊","不肯努力，只等好运自己来。","每天照顾菜园，等蔬菜长大。","把偶然的好运当成固定方法。"),
        idiom("亡羊补牢","羊逃走了，赶快把羊圈修好。","牛修门","发现错误后及时改正，避免再犯。","看见羊圈破了也不理会。","出了问题，及时补救仍有帮助。"),
        idiom("井底之蛙","住在井底的青蛙，只看得到一小片天。","水上鱼","只知道一点点，就以为看懂全世界。","到不同地方旅行，学到新知识。","比喻见识狭窄。"),
        idiom("掩耳盗铃","把耳朵遮住，以为别人也听不到铃声。","目手偷","自己不看问题，就当问题不存在。","用耳塞减少噪音，专心阅读。","自己欺骗自己，事实仍不会改变。"),
        idiom("刻舟求剑","剑掉进河里，却在移动的船上刻记号。","船找刀","情况已经改变，仍照旧方法办事。","根据新线索调整寻找方法。","不懂得随情况改变方法。"),
        idiom("拔苗助长","嫌禾苗长得慢，把苗往上拔。","拉草高","急着求成，反而伤害原本的成长。","每天给禾苗适量的水和阳光。","违反成长规律，反而坏了事。"),
        idiom("自相矛盾","夸口矛能刺穿所有盾，又说盾挡得住所有矛。","刀同对","前后说的话互相冲突。","前后说法一致，也有证据。","同一个人的说法前后不能同时成立。"),
        idiom("画龙点睛","画好龙，再点上眼睛，整幅画活了起来。","蛇目珠","加上关键的一笔，让作品更传神。","把不需要的装饰一直往上加。","关键的一笔，让内容更加精彩。")
    ] + ExpandedContent.idioms

    public static let bakery: [WorkshopQuestion] = {
        let words: [(String,String,String,String)] = [
            ("cat","猫","🐱","动物伙伴"),("dog","狗","🐶","动物伙伴"),("bird","鸟","🐦","动物伙伴"),("fish","鱼","🐟","动物伙伴"),("panda","熊猫","🐼","动物伙伴"),("rabbit","兔子","🐰","动物伙伴"),
            ("egg","鸡蛋","🥚","好吃的"),("cake","蛋糕","🍰","好吃的"),("milk","牛奶","🥛","好吃的"),("apple","苹果","🍎","好吃的"),("bread","面包","🍞","好吃的"),("banana","香蕉","🍌","好吃的"),
            ("bag","书包","🎒","书包里"),("book","书","📚","书包里"),("ruler","尺子","📏","书包里"),("pen","钢笔","🖊️","书包里"),("pencil","铅笔","✏️","书包里"),("eraser","橡皮擦","▰","书包里"),
            ("bed","床","🛏️","在家里"),("chair","椅子","🪑","在家里"),("desk","书桌","▤","在家里"),("cup","杯子","☕️","在家里"),("door","门","🚪","在家里"),("clock","时钟","🕒","在家里")
        ]
        return (words + ExpandedContent.englishWords).map { word, chinese, picture, topic in
            WorkshopQuestion(title:topic,clue:"把字母饼干排好，烤出「\(chinese)」",picture:picture,answer:word.map(String.init),extras:[],labels:Array(repeating:"",count:word.count),word:chinese,reading:word,explanation:"\(word) · \(chinese)")
        }
    }()
}
