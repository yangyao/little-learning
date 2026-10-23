import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct StudyPickerView: View {
    let game: LearningGame
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text("\(game.title) · 选题组").woodText(Wood.Typography.heading)
                Spacer()
                WoodIconButton(symbol:"xmark",label:"关闭题组选择") { store.topicPickerGame=nil }.accessibilityIdentifier("study.close")
            }.padding(.horizontal,20).padding(.top,12)
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    Text("按已经学到的内容选择，年级仅供参考。每款游戏会记住自己的题组。")
                        .font(.system(size:15)).foregroundStyle(Wood.Palette.textSecondary)
                    ForEach(StudyCatalog.groups(for:game)) { group in
                        let remaining=group.remaining(in:library.progress.rewards)
                        Button { store.chooseGroup(group,review:remaining == 0) } label: {
                            Tray(padding:16) {
                                HStack(spacing:12) {
                                    VStack(alignment:.leading,spacing:6) {
                                        Text(group.title).woodText(Wood.Typography.label)
                                        Text(group.detail).font(.system(size:14)).foregroundStyle(Wood.Palette.textSecondary)
                                        Text("\(group.stage) · \(group.count)题 · \(remaining == 0 ? "已完成，点此复习" : "新题还剩\(remaining)题")")
                                            .font(.system(size:13,weight:.medium)).foregroundStyle(remaining == 0 ? Wood.Palette.textSecondary : Wood.Palette.successText)
                                    }
                                    Spacer(minLength:0)
                                    Image(systemName:library.group(game)?.id == group.id ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(Wood.Palette.actionPrimary)
                                }
                            }
                        }.buttonStyle(IllustrationButtonStyle()).accessibilityIdentifier("study.group.\(group.id)")
                    }
                }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
            }
        }.background(Wood.Palette.canvas).foregroundStyle(Wood.Palette.textPrimary)
    }
}

struct StudyHeaderTitle: View {
    let game: LearningGame
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        if let group=library.group(game) {
            VStack(spacing:2) {
                Text(game.title).woodText(Wood.Typography.heading).lineLimit(1).minimumScaleFactor(0.8)
                Button { library.stopDelivery();store.stopSpeech();store.topicPickerGame=game } label: {
                    Label("切换题组",systemImage:"arrow.left.arrow.right")
                        .font(.system(size:14,weight:.semibold))
                        .padding(.horizontal,12).frame(minHeight:40)
                        .background(Wood.Palette.secondaryFill,in:Capsule())
                        .overlay(Capsule().strokeBorder(Wood.Palette.borderDecorative,lineWidth:1))
                }.buttonStyle(.plain)
                    .accessibilityLabel("切换题组，当前\(group.title)")
                    .accessibilityIdentifier("study.switch")
            }

        } else { Text(game.title).woodText(Wood.Typography.heading) }
    }
}

struct StudyFinishedView: View {
    let game: LearningGame
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        Tray {
            VStack(spacing:20) {
                Image(systemName:"checkmark.seal.fill").font(.system(size:64)).foregroundStyle(Wood.Palette.successText)
                Text(library.isReviewing(game) ? "这一组复习完了！" : "这一组完成了！").woodText(Wood.Typography.title)
                Text(library.group(game)?.title ?? "").woodText(Wood.Typography.heading)
                Text("可以换一组继续探索，也可以再复习。已获得的积分不会重复发放。")
                    .woodText(Wood.Typography.body).multilineTextAlignment(.center)
            }.frame(maxWidth:.infinity)
        }
    }
}
struct StudyFinishedActions: View {
    let game: LearningGame
    @EnvironmentObject private var store: GameStore
    var body: some View {
        Button("换一组") { store.topicPickerGame=game }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("study.change")
        Button("复习这一组") { store.reviewGroup(game) }.buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("study.review")
    }
}
