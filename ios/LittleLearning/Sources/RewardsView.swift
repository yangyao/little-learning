import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct RewardStatusView: View {
    let game: LearningGame
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        if let challenge=RewardCatalog.current(game,in:library.progress), library.progress.rewards.hasAward(challenge.id) {
            let justEarned=library.recentAwardID == challenge.id
            Label(justEarned ? "首次完成，＋\(challenge.points) 积分" : "已获得积分，复习不重复计分",systemImage:justEarned ? "star.fill" : "checkmark.seal.fill")
                .font(.system(size:15,weight:.semibold)).foregroundStyle(Wood.Palette.successText)
                .frame(maxWidth:.infinity).accessibilityIdentifier("reward.status")
        }
    }
}

struct RewardsView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    @StateObject private var screen = RewardsScreenState()
    private var ledger: RewardLedger { library.progress.rewards }
    private var points: Int { Int(screen.points) ?? 0 }
    private var canRedeem: Bool {
        !screen.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && points > 0 && points <= ledger.balance
    }
    var body: some View {
        VStack(spacing:0) {
            HStack {
                WoodIconButton(symbol:"arrow.left",label:"返回首页") { store.showsRewards=false; library.rewardMessage=nil }
                    .accessibilityIdentifier("rewards.back")
                Spacer()
                Text("积分兑换").woodText(Wood.Typography.heading)
                Spacer()
                Image(systemName:"star.fill").font(.system(size:26)).foregroundStyle(Wood.Palette.actionPrimary).frame(width:64)
            }.padding(.horizontal,Wood.Size.phoneMargin).padding(.vertical,8)
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Tray(padding:16) {
                        VStack(spacing:8) {
                            Text("可用积分").woodText(Wood.Typography.label)
                            Text("\(ledger.balance)").woodText(Wood.Typography.display).monospacedDigit().accessibilityIdentifier("rewards.balance")
                        }.frame(maxWidth:.infinity)
                    }
                    Tray(padding:16) {
                        VStack(alignment:.leading,spacing:12) {
                            Text("扣多少积分").woodText(Wood.Typography.label)
                            TextField("输入积分",text:$screen.points)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .textFieldStyle(.roundedBorder).accessibilityIdentifier("rewards.points")
                            Text("换了什么").woodText(Wood.Typography.label)
                            TextField("自己填写，例如一本书",text:$screen.title)
                                .textFieldStyle(.roundedBorder).accessibilityIdentifier("rewards.title")
                            if points > ledger.balance {
                                Text("不能超过现有积分").font(.system(size:14)).foregroundStyle(Wood.Palette.textSecondary)
                            }
                            Button("确认兑换") {
                                if library.redeem(title:screen.title,points:points,requestID:UUID()) {
                                    screen.title=""; screen.points=""
                                }
                            }.buttonStyle(SecondaryWoodStyle()).disabled(!canRedeem).accessibilityIdentifier("rewards.redeem")
                        }
                    }
                    if let message=library.rewardMessage {
                        LibraryFeedback(text:message,correct:true).accessibilityIdentifier("rewards.message")
                    }
                    Text("兑换记录").woodText(Wood.Typography.label)
                    if !ledger.entries.contains(where:{$0.kind == .redemption || $0.kind == .playTime}) {
                        Text("还没有兑换记录").font(.system(size:16)).foregroundStyle(Wood.Palette.textSecondary)
                    }
                    ForEach(ledger.entries.filter {$0.kind == .redemption || $0.kind == .playTime}.sorted { $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date }) { entry in
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:4) {
                                Text(entry.title).font(.system(size:16,weight:.semibold))
                                Text(entry.date,format:.dateTime.month().day().hour().minute()).font(.system(size:12)).foregroundStyle(Wood.Palette.textSecondary)
                                if ledger.isRefunded(entry.id) {
                                    Text("已撤销").font(.system(size:13))
                                } else if entry.kind == .redemption {
                                    Button("撤销") { library.refund(entry.id) }.buttonStyle(.plain)
                                        .font(.system(size:14)).foregroundStyle(Wood.Palette.actionPrimary)
                                        .accessibilityIdentifier("rewards.refund.\(entry.id.uuidString)")
                                }
                            }
                            Spacer()
                            Text("−\(-entry.amount) 分").font(.system(size:18,weight:.bold)).monospacedDigit()
                        }.padding(.vertical,8)
                    }
                }.frame(maxWidth:760).padding(.horizontal,Wood.Size.phoneMargin).padding(.vertical,16).frame(maxWidth:.infinity)
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
    }
}

@MainActor private final class RewardsScreenState: ObservableObject {
    @Published var title = ""
    @Published var points = ""
}
