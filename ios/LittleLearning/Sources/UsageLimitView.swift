import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct UsageLimitView: View {
    @EnvironmentObject private var usage: UsageStore
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var collection: CollectionStore
    var body: some View {
        VStack(spacing:24) {
            Spacer(minLength:16)
            Text(collection.activeChild?.avatar ?? "🌙").font(.system(size:64))
            Text(usage.storageError == nil ? "该休息一下啦" : "暂时休息一下")
                .woodText(Wood.Typography.heading)
            if let error=usage.storageError {
                Text(error).woodText(Wood.Typography.body).multilineTextAlignment(.center)
            } else if let child=collection.activeChild {
                Text("\(child.name)，这次已经用了30分钟")
                    .woodText(Wood.Typography.body).multilineTextAlignment(.center)
                Text(usage.restLabel(child)).font(.system(size:42,weight:.semibold,design:.rounded))
                    .monospacedDigit().accessibilityLabel("休息剩余\(usage.restLabel(child))")
                    .accessibilityIdentifier("usage.countdown")
                Text("休息2小时后，自动恢复30分钟\n进度已保留，下次接着玩")
                    .woodText(Wood.Typography.support).multilineTextAlignment(.center)
            }
            Button("返回选人") { store.showChildPicker() }
                .buttonStyle(SecondaryWoodStyle()).frame(maxWidth:260).accessibilityIdentifier("usage.children")
            Spacer(minLength:16)
        }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity)
            .background(Wood.Palette.canvas.ignoresSafeArea())
    }
}
