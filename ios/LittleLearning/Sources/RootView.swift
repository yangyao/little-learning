import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.scenePhase) private var scenePhase
    private var showsDrawer: Bool { collection.loadError == nil && !store.showsRewards && store.selectedFunGame == nil && store.selectedGame == nil }
    var body: some View {
        ZStack {
            GameDrawerView()
                .opacity(showsDrawer ? 1 : 0)
                .allowsHitTesting(showsDrawer)
                .accessibilityElement(children:.contain)
                .accessibilityHidden(!showsDrawer)
            Group {
            if let error=collection.loadError { Text(error).woodText(Wood.Typography.body).padding(24) }
            else if store.showsRewards { RewardsView() }
            else if let game=store.selectedFunGame { FunGameView(game:game) }
            else if let game = store.selectedGame {
                if game == .numberLine { NumberLineView() }
                else { CollectionGameView(game:game) }
            } else { Color.clear.allowsHitTesting(false) }
            }
            .id(store.showsRewards ? "rewards" : store.selectedFunGame.map {"fun-\($0.rawValue)"} ?? store.selectedGame?.rawValue ?? "drawer")
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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { collection.pauseFun();collection.stopDelivery();store.save(); collection.save(); store.stopSpeech() }
        }
    }
}
