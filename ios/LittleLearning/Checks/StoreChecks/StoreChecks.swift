import Foundation

@main struct StoreChecks {
    @MainActor static func main() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("LittleLearning-store-check-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let suite="LittleLearning-check-\(UUID())", defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let file=root.appendingPathComponent("state.json")
        let store=CollectionStore(fileURL:file,defaults:defaults)
        precondition(store.progress.rewards.balance == 0)
        var game=NumberLineGame(questions:[.init(start:3,change:2)])
        store.progress.numberLine=game
        game.check();store.progress.numberLine=game
        precondition(store.progress.rewards.balance == 0)
        game.move(to:5);game.check();store.progress.numberLine=game
        precondition(store.progress.rewards.balance == 1)
        // The completion and its reward are already durable without the debounce or scene callback.
        let reload=CollectionStore(fileURL:file,defaults:defaults)
        precondition(reload.progress.numberLine == game && reload.progress.rewards.balance == 1)
        reload.progress.numberLine = .init(questions:[.init(start:3,change:2)])
        reload.progress.numberLine=game
        precondition(reload.progress.rewards.balance == 1)
        for c in RewardCatalog.all.filter({$0.id != RewardCatalog.arithmetic(game.question).id}).prefix(9) { reload.progress.rewards.award(c.id) }
        reload.save();precondition(reload.progress.rewards.balance == 10)
        let request=UUID()
        precondition(reload.redeem(title:"自己选的书",points:10,requestID:request))
        precondition(reload.progress.rewards.balance == 0)
        let spent=CollectionStore(fileURL:file,defaults:defaults)
        precondition(spent.progress.rewards.balance == 0 && !spent.redeem(title:"自己选的书",points:10,requestID:request))
        spent.refund(request);precondition(spent.progress.rewards.balance == 10)
        spent.refund(request);precondition(spent.progress.rewards.balance == 10)
        let reopened=CollectionStore(fileURL:file,defaults:defaults)
        precondition(reopened.progress.rewards.balance == 10 && reopened.progress.rewards.isRefunded(request))
        reopened.progress.numberLine=game;precondition(reopened.progress.rewards.balance == 10)

        // A filesystem failure must not deduct points or append an unpersisted redemption.
        let parent=root.appendingPathComponent("failure"), backup=root.appendingPathComponent("backup")
        let failingFile=parent.appendingPathComponent("state.json")
        let failing=CollectionStore(fileURL:failingFile,defaults:defaults)
        for c in RewardCatalog.all.prefix(10) { failing.progress.rewards.award(c.id) };failing.save()
        let before=failing.progress.rewards
        try FileManager.default.moveItem(at:parent,to:backup)
        try Data("not-a-directory".utf8).write(to:parent)
        precondition(!failing.redeem(title:"自己选的书",points:10,requestID:UUID()))
        precondition(failing.progress.rewards == before && failing.saveError != nil)
        try FileManager.default.removeItem(at:parent)
        try FileManager.default.moveItem(at:backup,to:parent)
        let afterFailure=CollectionStore(fileURL:failingFile,defaults:defaults)
        precondition(afterFailure.progress.rewards == before)

        // Invalid data is preserved instead of replacing the wallet with a zero balance.
        let corrupt=root.appendingPathComponent("corrupt.json"), bad=Data("broken".utf8)
        try bad.write(to:corrupt)
        let broken=CollectionStore(fileURL:corrupt,defaults:defaults)
        precondition(broken.loadError != nil);broken.save()
        let stillBad=try Data(contentsOf:corrupt);precondition(stillBad == bad)

        // Original pre-points collection and number-line saves are imported once.
        let legacy=root.appendingPathComponent("legacy.json")
        var json=try JSONSerialization.jsonObject(with:CollectionProgress().encoded()!) as! [String:Any]
        json.removeValue(forKey:"rewards");json.removeValue(forKey:"numberLine")
        try JSONSerialization.data(withJSONObject:json).write(to:legacy)
        defaults.set(game.encoded(),forKey:"numberLine.v1")
        let migrated=CollectionStore(fileURL:legacy,defaults:defaults)
        precondition(migrated.progress.rewards.balance == 1 && migrated.progress.numberLine == game)
        let migratedAgain=CollectionStore(fileURL:legacy,defaults:defaults)
        precondition(migratedAgain.progress.rewards.balance == 1)
        try StudyStoreChecks.run(root:root,defaults:defaults)
        try await NewGamesStoreChecks.run(root:root,defaults:defaults)
        try FunStoreChecks.run(root:root,defaults:defaults)
        try RulerStoreChecks.run(root:root,defaults:defaults)
        try ChildStoreChecks.run(root:root,defaults:defaults)
        try PointsSyncStoreChecks.run(root:root,defaults:defaults)
        try UsageStoreChecks.run(root:root)
        print("PASS: actual store atomic awards, restart/replay protection, redemption/refund durability, failed-write rollback, corrupt-file preservation and legacy import.")
    }
}
