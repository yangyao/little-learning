import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct WorkshopGameView: View {
    let game: LearningGame
    @EnvironmentObject private var library: CollectionStore
    private var questions: [WorkshopQuestion] { WorkshopContent.questions(for:game) }
    private var session: WorkshopSession { library.session(game) }
    private var q: WorkshopQuestion { questions[session.index] }
    private var tileOrder: [Int] {
        var rng=SeededRandom(seed:UInt64(session.index*71+game.rawValue.utf8.reduce(0){$0+Int($1)}))
        var order=Array(q.pool.indices).shuffled(using:&rng)
        if game == .bakery, order.map({q.pool[$0]}) == q.answer, let first=order.first { order=Array(order.dropFirst())+[first] }
        return order
    }
    var body: some View {
        if session.phase == .complete {
            GameCompletion(game:game,message:"你完成了 \(questions.count) 道\(game.title)挑战。") { library.restart(game) }
        } else {
            ChallengeHeading(subtitle:library.positionLabel(game),title:q.clue)
            if session.phase == .playing {
                assembly
                Text(game == .bakery ? "点字母放进烤盘，点上面的字母可以拿回。" : "点零件放上去，点已放好的零件可以拿回。")
                    .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:64),spacing:12)],spacing:12) {
                    ForEach(tileOrder,id:\.self) { index in
                        PieceButton(text:q.pool[index]) { library.editWorkshop(game) { $0.choose(index,question:q) } }
                            .disabled(session.chosen.contains(index)).opacity(session.chosen.contains(index) ? 0.35 : 1)
                            .accessibilityLabel("零件 \(q.pool[index])").accessibilityIdentifier("workshop.tile.\(index)")
                    }
                }
            } else {
                Tray {
                    VStack(spacing:Wood.Spacing.md) {
                        if !q.picture.isEmpty { Text(q.picture).font(.system(size:64)).accessibilityHidden(true) }
                        Text(game == .bakery ? q.reading : q.word).font(.system(size:game == .characters ? 80 : 36,weight:.bold,design:.rounded)).multilineTextAlignment(.center)
                        if game == .pinyin { Text(q.reading).woodText(Wood.Typography.display) }
                    }.frame(maxWidth:.infinity)
                }

            }
        }
    }
    private var assembly: some View {
        Tray(padding:Wood.Spacing.md) {
            VStack(spacing:Wood.Spacing.md) {
                if game == .bakery { Text(q.picture).font(.system(size:64)).accessibilityLabel(q.word) }
                if game == .characters && q.layout == "column" {
                    VStack(spacing:12) { ForEach(q.answer.indices,id:\.self) { slot($0).frame(maxWidth:100) } }
                } else if game == .characters && q.layout == "pyramid" {
                    VStack(spacing:12) { slot(0).frame(width:72); HStack(spacing:12) { slot(1); slot(2) }.frame(maxWidth:180) }
                } else if game == .characters && q.layout == "twoTop" {
                    VStack(spacing:12) { HStack(spacing:12) { slot(0); slot(1) }.frame(maxWidth:180); slot(2).frame(width:100) }
                } else if game == .pinyin {
                    HStack(alignment:.bottom,spacing:12) {
                        ForEach(q.answer.indices,id:\.self) { index in
                            VStack(spacing:8) {
                                Text(q.labels[index]).woodText(Wood.Typography.support)
                                slot(index)
                                HStack { Circle().frame(width:12,height:12); Spacer(); Circle().frame(width:12,height:12) }.foregroundStyle(Wood.Palette.actionPrimarySide).padding(.horizontal,8).accessibilityHidden(true)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:64),spacing:12)],spacing:12) { ForEach(q.answer.indices,id:\.self) { slot($0) } }
                }
            }.frame(maxWidth:.infinity)
        }
    }
    private func slot(_ index: Int) -> some View {
        let filled=session.chosen.indices.contains(index), text=filled ? q.pool[session.chosen[index]] : "?"
        return PieceButton(text:text,empty:!filled) { library.editWorkshop(game) { $0.remove(at:index) } }
            .disabled(!filled).accessibilityLabel("第 \(index+1) 格，\(filled ? text : "空位")").accessibilityIdentifier("workshop.slot.\(index)")
    }
}
