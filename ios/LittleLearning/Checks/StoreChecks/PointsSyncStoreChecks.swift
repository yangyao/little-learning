import Foundation

enum PointsSyncStoreChecks {
    @MainActor static func run(root: URL,defaults: UserDefaults) throws {
        let aFile=root.appendingPathComponent("sync-a.json"),bFile=root.appendingPathComponent("sync-b.json")
        let a=CollectionStore(fileURL:aFile,defaults:defaults,profilesEnabled:true)
        let b=CollectionStore(fileURL:bFile,defaults:defaults,profilesEnabled:true)
        precondition(a.selectChild(.qianyi) && b.selectChild(.qianyi))
        let challenges=Array(RewardCatalog.all.prefix(20))
        for challenge in challenges.prefix(12) { a.progress.rewards.award(challenge.id);b.progress.rewards.award(challenge.id) }
        a.progress.ruler = .init(startAt:9);b.progress.ruler = .init(startAt:18)
        precondition(a.buyFunTime(requestID:UUID()))
        let id=UUID();precondition(b.redeem(title:"书",points:2,requestID:id))
        let outgoing=try a.pointsSnapshot()
        let beforePreview=b.progress
        _ = try b.previewPointsSync(outgoing);precondition(b.progress == beforePreview)
        try b.mergePointsSync(outgoing)
        precondition(b.progress.rewards.balance == 5 && b.funMilliseconds == 0 && b.progress.ruler.index == 18)
        try a.mergePointsSync(b.pointsSnapshot())
        precondition(a.progress.rewards == b.progress.rewards && a.progress.ruler.index == 9 && a.funMilliseconds == 300_000)
        let ledger=a.progress.rewards
        try a.mergePointsSync(b.pointsSnapshot());precondition(a.progress.rewards == ledger && a.funMilliseconds == 300_000)
        b.refund(id);try a.mergePointsSync(b.pointsSnapshot());precondition(a.progress.rewards.balance == 7)
        precondition(a.selectChild(.zhenyi));a.progress.rewards.award(challenges[15].id)
        try b.mergePointsSync(a.pointsSnapshot()) // Updates the inactive child's ledger too.
        precondition(b.selectChild(.zhenyi));precondition(b.progress.rewards.balance == 1)
        let reopen=CollectionStore(fileURL:bFile,defaults:defaults,profilesEnabled:true)
        precondition(reopen.selectChild(.qianyi));precondition(reopen.progress.rewards.balance == 7)
        precondition(reopen.progress.ruler.index == 18 && reopen.funMilliseconds == 0)
        // Failure is atomic across both children.
        let familyFile=bFile.deletingPathExtension().appendingPathExtension("family-v1.json")
        let backup=root.appendingPathComponent("sync-b-backup.json")
        let original=try Data(contentsOf:familyFile)
        try FileManager.default.moveItem(at:familyFile,to:backup)
        try FileManager.default.createDirectory(at:familyFile,withIntermediateDirectories:true)
        a.progress.rewards.award(challenges[16].id)
        let before=try reopen.pointsSnapshot()
        do { try reopen.mergePointsSync(a.pointsSnapshot());preconditionFailure("Write should fail") } catch {}
        let after=try reopen.pointsSnapshot();precondition(after.ledgers == before.ledgers)
        try FileManager.default.removeItem(at:familyFile);try FileManager.default.moveItem(at:backup,to:familyFile)
        let saved=try Data(contentsOf:familyFile);precondition(saved == original)
        print("PASS: durable two-child sync, no progress overwrite, no imported time duplication, repeated sync, remote refunds, inactive child updates and atomic failed-write rollback.")
    }
}
