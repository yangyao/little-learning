import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct ChildPickerView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var usage: UsageStore
    var body: some View {
        VStack(spacing:24) {
            Spacer(minLength:16)
            Text("今天谁来玩？").woodText(Wood.Typography.heading)
            Text("选自己的名字，积分和进度各自保存")
                .woodText(Wood.Typography.support).multilineTextAlignment(.center)
            HStack(spacing:16) {
                ForEach(FamilyChild.allCases) { child in
                    Button { store.chooseChild(child) } label: {
                        Tray(padding:20) {
                            VStack(spacing:16) {
                                Text(child.avatar).font(.system(size:56))
                                Text(child.name).woodText(Wood.Typography.heading)
                                Text(usage.remaining(child) == 0 ? "休息 \(usage.restLabel(child))" : "可用 \(usage.remainingLabel(child))")
                                    .font(.system(size:14,weight:.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                                    .foregroundStyle(Wood.Palette.textSecondary)
                            }.frame(maxWidth:.infinity).padding(.vertical,16)
                        }
                    }.buttonStyle(IllustrationButtonStyle())
                        .accessibilityLabel("选择\(child.name)")
                        .accessibilityIdentifier("child.\(child.rawValue)")
                }
            }.frame(maxWidth:500)
            Spacer(minLength:16)
        }.padding(.horizontal,20).frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
