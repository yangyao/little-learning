import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct SharingGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var session: SharingSession { library.progress.sharing }
    private var task: SharingTask { session.task }
    var body: some View {
        if session.phase == .complete {
            GameCompletion(game:.sharing,message:"平均分，就是每一份都一样多。") { library.restart(.sharing) }
        } else {
            ChallengeHeading(subtitle:library.positionLabel(.sharing),title:"\(task.total) 个\(task.name)，分给 \(task.bowls) 位朋友")
            Tray(padding:Wood.Spacing.md) {
                VStack(spacing:Wood.Spacing.md) {
                    Text("篮子里还有 \(session.remaining) 个").woodText(Wood.Typography.heading)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:42))],spacing:8) {
                        ForEach(0..<session.remaining,id:\.self) { _ in Text(task.food).font(.system(size:30)).accessibilityHidden(true) }
                    }.frame(minHeight:44)
                    Text(task.remainder > 0 ? "每盘一样多，不够再分一轮的留在篮子里。" : "点一盘，分一个；分多了可以拿回。")
                        .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
                }
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:140),spacing:16)],spacing:16) {
                ForEach(session.plates.indices,id:\.self) { bowl in
                    VStack(spacing:8) {
                        Button { library.progress.sharing.give(to:bowl) } label: {
                            VStack(spacing:8) {
                                Text("\(task.animal) \(bowl+1)").font(.system(size:30))
                                LazyVGrid(columns:[GridItem(.adaptive(minimum:24))],spacing:4) {
                                    ForEach(0..<session.plates[bowl],id:\.self) { _ in Text(task.food).font(.system(size:24)) }
                                }.frame(minHeight:54)
                                Text("\(session.plates[bowl]) 个").woodText(Wood.Typography.label)
                            }.padding(Wood.Spacing.md).frame(maxWidth:.infinity,minHeight:160)
                                .background(Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:Wood.Radius.tray))
                        }.buttonStyle(IllustrationButtonStyle()).disabled(session.phase != .playing || session.remaining == 0)
                            .accessibilityLabel("第 \(bowl+1) 盘，\(session.plates[bowl]) 个，分一个")
                            .accessibilityIdentifier("sharing.bowl.\(bowl)")
                        Button("拿回一个") { library.progress.sharing.take(from:bowl) }
                            .buttonStyle(SecondaryWoodStyle()).disabled(session.phase != .playing || session.plates[bowl] == 0)
                            .accessibilityIdentifier("sharing.take.\(bowl)")
                    }
                }
            }
        }
    }
}
