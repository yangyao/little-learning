import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var usage: UsageStore
    @Environment(\.scenePhase) private var scenePhase
    private var showsDrawer: Bool { !usage.isBlocked && collection.loadError == nil && collection.activeChild != nil && !store.showsChildPicker && !store.showsRewards && store.selectedFunGame == nil && store.selectedGame == nil }
    var body: some View {
        ZStack {
            GameDrawerView()
                .opacity(showsDrawer ? 1 : 0)
                .allowsHitTesting(showsDrawer)
                .accessibilityElement(children:.contain)
                .accessibilityHidden(!showsDrawer)
            Group {
            if let error=collection.loadError { Text(error).woodText(Wood.Typography.body).padding(24) }
            else if collection.activeChild == nil || store.showsChildPicker { ChildPickerView() }
            else if usage.isBlocked { UsageLimitView() }
            else if store.showsRewards { RewardsView() }
            else if let game=store.selectedFunGame { FunGameView(game:game,child:collection.activeChild ?? .zhenyi) }
            else if let game = store.selectedGame {
                if game == .numberLine { NumberLineView() }
                else { CollectionGameView(game:game) }
            } else { Color.clear.allowsHitTesting(false) }
            }
            .id(collection.activeChild == nil || store.showsChildPicker ? "children" : usage.isBlocked ? "usage-lock" : store.showsRewards ? "rewards" : store.selectedFunGame.map {"fun-\($0.rawValue)"} ?? store.selectedGame?.rawValue ?? "drawer")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Wood.Palette.canvas.ignoresSafeArea())
        .foregroundStyle(Wood.Palette.textPrimary)
        .overlay(alignment:.bottom) {
            if let error = collection.saveError { Text(error).woodText(Wood.Typography.support).padding().background(Wood.Palette.hintBackground) }
        }
        .sheet(item:$store.topicPickerGame) { game in
            StudyPickerView(game:game).presentationDetents([.large])
        }

        .safeAreaInset(edge:.top,spacing:0) {
            if usage.showsWarning && !usage.isBlocked {
                Text("还剩1分钟，记得休息一下")
                    .font(.system(size:14,weight:.semibold)).frame(maxWidth:.infinity).padding(8)
                    .background(Wood.Palette.hintBackground).accessibilityIdentifier("usage.warning")
            }
        }
        .onAppear { updateUsage();collection.scheduleServerSync() }
        .task(id:scenePhase) { guard scenePhase == .active else {return};while !Task.isCancelled {await collection.syncNow();do {try await Task.sleep(nanoseconds:30_000_000_000)} catch {return}} }
        .onChange(of:collection.activeChild) { _,_ in updateUsage() }
        .onChange(of:store.showsChildPicker) { _,_ in updateUsage() }
        .onChange(of:usage.isBlocked) { _,blocked in
            if blocked {
                store.topicPickerGame=nil;store.showsPointsSync=false
                collection.pauseFun();collection.stopDelivery();store.stopSpeech();store.save();collection.save()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            updateUsage()
            if phase == .active {collection.scheduleServerSync()}
            if phase != .active { collection.pauseFun();collection.stopDelivery();store.save(); collection.save(); store.stopSpeech() }
        }
    }
    private func updateUsage() {
        usage.updateContext(child:store.showsChildPicker ? nil : collection.activeChild,active:scenePhase == .active)
    }
}
