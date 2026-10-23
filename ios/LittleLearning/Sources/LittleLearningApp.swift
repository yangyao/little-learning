import SwiftUI

@main
struct LittleLearningApp: App {
    @StateObject private var store: GameStore
    @StateObject private var collection: CollectionStore
    init() {
        let library=CollectionStore(profilesEnabled:true)
        _collection=StateObject(wrappedValue:library)
        _store=StateObject(wrappedValue:GameStore(collection:library))
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(collection)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                #if os(macOS)
                .frame(minWidth:390,minHeight:740)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 430, height: 880)
        #endif
    }
}
