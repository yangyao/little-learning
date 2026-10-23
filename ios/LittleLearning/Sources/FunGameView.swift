import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

private let funColors: [Color] = [Color(red:0.80,green:0.36,blue:0.19),Color(red:0.27,green:0.54,blue:0.33),Color(red:0.28,green:0.48,blue:0.70),Color(red:0.62,green:0.39,blue:0.64)]
private let funColorNames = ["橙色","绿色","蓝色","紫色"]

struct FunGameView: View {
    let game: FunGame
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    @StateObject private var web: WebGameSession
    @StateObject private var screen=FunPurchaseState()
    init(game: FunGame,child: FamilyChild) { self.game=game;_web=StateObject(wrappedValue:WebGameSession.cached(game,child:child)) }
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:8) {
                WoodIconButton(symbol:"arrow.left",label:"回游戏抽屉") { pause();store.closeFun() }.accessibilityIdentifier("fun.back")
                Spacer(minLength:0)
                VStack(spacing:4) {
                    Text(game.title).woodText(Wood.Typography.heading)
                    Label(library.funTimeLabel,systemImage:"hourglass").font(.system(size:16,weight:.semibold)).monospacedDigit().accessibilityIdentifier("fun.time")
                }
                Spacer(minLength:0)
                WoodIconButton(symbol:library.funPlaying ? "pause.fill" : "play.fill",label:library.funPlaying ? "暂停游戏和计时" : "继续游戏") {
                    if library.funPlaying { pause() } else { resume() }
                }.disabled(!web.ready || library.funMilliseconds == 0).accessibilityIdentifier("fun.pause")
            }.padding(.horizontal,Wood.Size.phoneMargin).padding(.vertical,8)
            ZStack {
                EmbeddedGame(session:web).allowsHitTesting(library.funPlaying).accessibilityHidden(!library.funPlaying)
                if !library.funPlaying {
                    Wood.Palette.canvas.opacity(0.96)
                    Tray(padding:20) {
                        VStack(spacing:16) {
                            FunArtwork(game:game).frame(height:80)
                            Text(web.error != nil ? "游戏暂时没有载入" : !web.ready ? "正在准备游戏…" : library.funMilliseconds > 0 ? "已暂停" : "用积分换游戏时间").woodText(Wood.Typography.heading)
                            Text(game.subtitle).woodText(Wood.Typography.body).multilineTextAlignment(.center)
                            if let error=web.error {
                                Text(error).font(.system(size:14)).multilineTextAlignment(.center)
                                Button("重新载入") { web.reload() }.buttonStyle(SecondaryWoodStyle())
                            } else if web.ready {
                                if library.funMilliseconds > 0 {
                                    Text("剩余 \(library.funTimeLabel)，可以接着玩。")
                                    Button("继续玩") { resume() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("fun.resume")
                                } else {
                                    Text("现有 \(library.progress.rewards.balance) 积分")
                                    Button(library.progress.rewards.balance >= 5 ? "5积分换5分钟" : "还差\(5-library.progress.rewards.balance)积分") { screen.purchaseID=UUID() }
                                        .buttonStyle(WoodenPrimaryButtonStyle()).disabled(library.progress.rewards.balance < 5).accessibilityIdentifier("fun.buy")
                                }
                                Text("两款共用 · 离开暂停 · 剩余保留").font(.system(size:13)).foregroundStyle(Wood.Palette.textSecondary)
                            } else { ProgressView() }
                            Button("回去学一会儿") { pause();store.closeFun() }.buttonStyle(SecondaryWoodStyle())
                        }.frame(maxWidth:.infinity)
                    }.padding(.horizontal,Wood.Size.phoneMargin).frame(maxWidth:500)
                }
            }.clipShape(RoundedRectangle(cornerRadius:18)).padding(.horizontal,8)
            Text(library.funPlaying ? (game == .watermelon ? "拖动水果，松手下落 · 相同水果合成" : "本局得分不计入学习积分") : "趣味游戏不产生学习积分").font(.system(size:12)).foregroundStyle(Wood.Palette.textSecondary).padding(.vertical,6)
        }
        .onAppear { library.pauseFun();web.pause(true) }
        .onDisappear { pause();library.save() }
        .onChange(of:library.funPlaying) { _,playing in web.pause(!playing) }
        .onChange(of:web.error) { _,error in if error != nil { pause() } }
        .onChange(of:web.ready) { _,ready in if !ready { pause() } }
        .alert("花5积分换5分钟？",isPresented:Binding(get:{screen.purchaseID != nil},set:{if !$0 { screen.purchaseID=nil }}),presenting:screen.purchaseID) { id in
            Button("取消",role:.cancel) {}
            Button("兑换并开始") { if web.ready,library.buyFunTime(requestID:id) { resume() } }
        } message: { _ in Text("扣除5积分，剩余\(max(0,library.progress.rewards.balance-5))积分。两款游戏共用时间，离开游戏就暂停。") }
    }
    private func pause() { web.pause(true);library.pauseFun() }
    private func resume() { guard web.ready,web.error == nil else { return };library.resumeFun(game);web.pause(!library.funPlaying) }
}

private final class FunPurchaseState: ObservableObject { @Published var purchaseID: UUID? }

struct FunArtwork: View {
    let game: FunGame
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:14).fill(game == .bubbles ? Color(red:0.18,green:0.13,blue:0.35) : Color(red:1,green:0.90,blue:0.68))
            if game == .bubbles {
                HStack(spacing:-5) {
                    ForEach(0..<3) { i in Circle().fill(RadialGradient(colors:[.white,[Color.pink,.purple,.cyan][i]],center:.topLeading,startRadius:0,endRadius:35)).frame(width:36,height:36).shadow(color:.white.opacity(0.2),radius:5).offset(y:i == 1 ? -7 : 6) }
                }
            } else { Text("🍉").font(.system(size:52)) }
        }.accessibilityHidden(true)
    }
}
