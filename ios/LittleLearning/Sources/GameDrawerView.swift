import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct GameDrawerView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var collection: CollectionStore
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing:Wood.Spacing.md) {
                VStack(spacing:12) {
                    HStack(alignment:.firstTextBaseline) {
                        Button { store.showChildPicker() } label: {
                            HStack(spacing:5) {
                                Text(collection.activeChild?.avatar ?? "🐰")
                                Text(collection.activeChild?.name ?? "选人")
                                Image(systemName:"chevron.down").font(.system(size:12,weight:.bold))
                            }.font(.system(size:20,weight:.semibold)).lineLimit(1).frame(minHeight:48)
                        }.buttonStyle(IllustrationButtonStyle()).accessibilityLabel("当前是\(collection.activeChild?.name ?? "未选择")，点击切换孩子").accessibilityIdentifier("drawer.child")
                        Spacer()
                        Button { collection.clearRewardNotice();store.showsRewards=true } label: {
                            HStack(spacing:6) {
                                Image(systemName:"star.fill").foregroundStyle(Wood.Palette.hint)
                                Text("\(collection.progress.rewards.balance) 分").monospacedDigit()
                                Image(systemName:"chevron.right").font(.system(size:12,weight:.bold))
                            }.font(.system(size:18,weight:.semibold)).padding(.horizontal,12).frame(minHeight:48)
                                .background(Wood.Palette.secondaryFill,in:Capsule())
                        }.buttonStyle(IllustrationButtonStyle()).accessibilityLabel("积分 \(collection.progress.rewards.balance) 分，兑换礼物").accessibilityIdentifier("drawer.rewards")
                    }
                    HStack(spacing:6) {
                        ForEach(DrawerCategory.allCases,id:\.self) { category in
                            Button { store.drawerCategory=category } label: {
                                Label(category.title,systemImage:category.symbol)
                                    .font(.system(size:18,weight:.semibold))
                                    .frame(maxWidth:.infinity,minHeight:48)
                                    .foregroundStyle(store.drawerCategory == category ? Wood.Palette.onPrimary : Wood.Palette.textSecondary)
                                    .background(store.drawerCategory == category ? Wood.Palette.actionPrimary : Color.clear,in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(IllustrationButtonStyle())
                                .accessibilityAddTraits(store.drawerCategory == category ? .isSelected : [])
                                .accessibilityIdentifier("drawer.category.\(category.rawValue)")
                        }
                    }.padding(5).background(Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:16))
                }.frame(maxWidth:1000).padding(.horizontal,margin(geometry))
                ZStack {
                    learningGames(margin:margin(geometry))
                        .opacity(store.drawerCategory == .learning ? 1 : 0)
                        .allowsHitTesting(store.drawerCategory == .learning)
                        .accessibilityElement(children:.contain)
                        .accessibilityHidden(store.drawerCategory != .learning)
                    VStack(spacing:12) {
                        HStack {
                            Label("剩余 \(collection.funTimeLabel)",systemImage:"hourglass").monospacedDigit()
                            Spacer()
                            Text("5积分换5分钟")
                        }.font(.system(size:15,weight:.medium)).foregroundStyle(Wood.Palette.textSecondary)
                            .frame(maxWidth:1000).padding(.horizontal,margin(geometry)).accessibilityIdentifier("drawer.playTime")
                        playGames(margin:margin(geometry))
                    }.opacity(store.drawerCategory == .play ? 1 : 0)
                        .allowsHitTesting(store.drawerCategory == .play)
                        .accessibilityElement(children:.contain)
                        .accessibilityHidden(store.drawerCategory != .play)
                }
            }.padding(.top,Wood.Spacing.md)
        }
    }
    private func margin(_ geometry: GeometryProxy) -> CGFloat {
        geometry.size.width > 600 ? Wood.Size.tabletMargin : Wood.Size.phoneMargin
    }
    private func learningGames(margin: CGFloat) -> some View {
        ScrollView {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:12)],spacing:12) {
                ForEach(LearningGame.allCases.filter { $0 != .printing }) { game in
                    Button { store.open(game) } label: {
                        Tray(padding:12) {
                            VStack(alignment:.leading,spacing:6) {
                                GameArtwork(game:game,compact:true).frame(height:62)
                                Text(game.title).woodText(Wood.Typography.label).lineLimit(1).minimumScaleFactor(0.9)
                                Text(resume(game) ?? game.subtitle)
                                    .font(.system(size:14,weight:.medium))
                                    .foregroundStyle(resume(game) == nil ? Wood.Palette.textSecondary : Wood.Palette.successText)
                                    .lineLimit(1)
                            }.frame(maxWidth:.infinity,alignment:.topLeading)
                        }
                    }.buttonStyle(IllustrationButtonStyle())
                        .accessibilityLabel("\(game.title)，\(game.subtitle)。\(resume(game) ?? "开始玩")")
                        .accessibilityIdentifier("drawer.\(game.rawValue)").id(game.rawValue)
                }
            }.scrollTargetLayout().frame(maxWidth:1000).padding(.horizontal,margin)
                .padding(.bottom,Wood.Spacing.lg).frame(maxWidth:.infinity)
        }.accessibilityIdentifier("drawer.learningList")
    }
    private var availableFunGames: [FunGame] {
        FunGame.allCases.filter { Bundle.main.url(forResource:"index",withExtension:"html",subdirectory:"WebGames/\($0.rawValue)") != nil }
    }
    private func playGames(margin: CGFloat) -> some View {
        ScrollView {
            if availableFunGames.isEmpty {
                Text("暂时没有游玩游戏").font(.system(size:17)).foregroundStyle(Wood.Palette.textSecondary).frame(maxWidth:.infinity).padding(.vertical,40)
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:12)],spacing:12) {
                ForEach(availableFunGames) { game in
                    Button { store.openFun(game) } label: {
                        Tray(padding:12) {
                            VStack(alignment:.leading,spacing:6) {
                                FunArtwork(game:game).frame(height:62)
                                Text(game.title).woodText(Wood.Typography.label).lineLimit(1)
                                Text(game.subtitle).font(.system(size:14,weight:.medium)).foregroundStyle(Wood.Palette.textSecondary).lineLimit(1)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }.buttonStyle(IllustrationButtonStyle()).accessibilityIdentifier("drawer.fun.\(game.rawValue)").id(game.rawValue)
                }
            }.scrollTargetLayout().frame(maxWidth:1000).padding(.horizontal,margin)
                .padding(.bottom,Wood.Spacing.lg).frame(maxWidth:.infinity)
        }.accessibilityIdentifier("drawer.playList")
    }
    private func resume(_ game: LearningGame) -> String? {
        if let group=collection.group(game) {
            return collection.isGroupFinished(game) ? "已完成 · 可换一组" : collection.isReviewing(game) ? "\(group.shortTitle) · 复习中" : "\(group.shortTitle) · 新题\(collection.remaining(game))"
        }
        if game == .numberLine { return store.hasProgress ? "接着玩" : nil }
        return collection.resumeLabel(game)
    }
}

struct GameArtwork: View {
    let game: LearningGame
    var compact = false
    var body: some View {
        if game == .numberLine {
            ZStack {
                RoundedRectangle(cornerRadius:16).fill(Wood.Palette.successBackground)
                LilyShape().fill(Wood.Palette.success).frame(width:compact ? 58 : 72,height:compact ? 26 : 40).offset(y:compact ? 18 : 27)
                LilyShape().fill(Wood.Palette.success).frame(width:compact ? 22 : 28,height:compact ? 14 : 20).offset(x:compact ? -36 : -48,y:compact ? 20 : 34)
                LilyShape().fill(Wood.Palette.success).frame(width:compact ? 22 : 28,height:compact ? 14 : 20).offset(x:compact ? 36 : 48,y:compact ? 18 : 26)
                LittleDuck().frame(width:compact ? 42 : 60,height:compact ? 42 : 60).offset(y:compact ? -4 : -15)
            }.clipped().accessibilityHidden(true)
        }
        else {
            ZStack {
                RoundedRectangle(cornerRadius:Wood.Radius.control).fill([.sharing,.sorting,.printing].contains(game) ? Wood.Palette.successBackground : Wood.Palette.secondaryFill)
                switch game {
                case .characters: HStack(spacing:4) { block("木"); block("木") }
                case .idioms: HStack(spacing:4) { block("成"); block("语") }
                case .bakery: HStack(spacing:4) { block("a"); block("b") }
                case .sharing: Text("🐰  🍓").font(.system(size:compact ? 28 : 36))
                case .sorting: Text("🍎 🍋").font(.system(size:compact ? 28 : 36))
                default: Image(systemName:game.symbol).font(.system(size:compact ? 34 : 52,weight:.medium)).foregroundStyle(game == .printing ? Wood.Palette.success : Wood.Palette.actionPrimary)
                }
            }.accessibilityHidden(true)
        }
    }
    private func block(_ text: String) -> some View {
        Text(text).font(.system(size:compact ? 24 : 30,weight:.bold,design:.rounded)).foregroundStyle(Wood.Palette.onObject)
            .frame(width:compact ? 36 : 48,height:compact ? 40 : 56).background(Wood.Palette.object,in:RoundedRectangle(cornerRadius:12))
            .background(RoundedRectangle(cornerRadius:12).fill(Wood.Palette.objectSide).offset(y:4))
    }
}
