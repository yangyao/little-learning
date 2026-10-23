import Foundation

@MainActor enum FunStoreChecks {
    static func run(root: URL,defaults: UserDefaults) throws {
        defaults.removeObject(forKey:"numberLine.v1")
        var now=100.0
        let file=root.appendingPathComponent("fun-time.json")
        let store=CollectionStore(fileURL:file,defaults:defaults,uptime:{now})
        for c in RewardCatalog.all.prefix(10) {store.progress.rewards.award(c.id)}
        store.save()
        let request=UUID()
        precondition(store.buyFunTime(requestID:request) && store.progress.rewards.balance == 5 && store.funMilliseconds == 300_000)
        precondition(!store.buyFunTime(requestID:request))
        let durable=CollectionStore(fileURL:file,defaults:defaults,uptime:{now})
        precondition(durable.progress.rewards == store.progress.rewards && durable.funMilliseconds == 300_000 && !durable.funPlaying)
        store.resumeFun(.arrows);now += 2.25;store.settleFunTime(force:true)
        precondition(abs(store.funMilliseconds-297_750) <= 1)
        now += 0.125;store.pauseFun()
        let paused=store.funMilliseconds;precondition(abs(paused-297_625) <= 2 && !store.funPlaying)
        now += 3600;store.settleFunTime(force:true);precondition(store.funMilliseconds == paused)
        store.resumeFun(.ants);precondition(store.funPlaying && store.activeFunGame == .ants)
        let oldLedger=store.progress.rewards
        store.dispatchAnt(store.progress.funAnts.task.solution[0]);precondition(store.antBusy)
        now += 0.5;store.pauseFun();precondition(!store.antBusy && store.antWave.isEmpty && store.progress.rewards == oldLedger)
        let copied=CollectionStore(fileURL:file,defaults:defaults,uptime:{now})
        precondition(copied.progress.funAnts == store.progress.funAnts && copied.funMilliseconds == store.funMilliseconds && !copied.funPlaying)
        store.resumeFun(.arrows);now += 1000;store.settleFunTime(force:true)
        precondition(store.funMilliseconds == 0 && !store.funPlaying)
        let arrows=store.progress.funArrows
        store.escapeArrow(arrows.task.solution[0]);precondition(store.progress.funArrows == arrows)
        precondition(store.buyFunTime(requestID:UUID()) && store.funMilliseconds == 300_000 && store.progress.rewards.balance == 0)
        // Fail an atomic purchase: neither a debit nor a grant may leak into memory/disk.
        let parent=root.appendingPathComponent("fun-fail"),backup=root.appendingPathComponent("fun-backup")
        let failing=CollectionStore(fileURL:parent.appendingPathComponent("state.json"),defaults:defaults)
        for c in RewardCatalog.all.prefix(5) {failing.progress.rewards.award(c.id)};failing.save()
        let before=failing.progress
        try FileManager.default.moveItem(at:parent,to:backup);try Data("not-directory".utf8).write(to:parent)
        precondition(!failing.buyFunTime(requestID:UUID()) && failing.progress == before && failing.funMilliseconds == 0)
        print("PASS: atomic time purchase/failure rollback, shared time, partial-second pause, no offline charge, animation cancellation, expiry input lock and restart durability.")
    }
}
