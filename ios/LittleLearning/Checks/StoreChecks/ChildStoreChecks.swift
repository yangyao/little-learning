import Foundation

enum ChildStoreChecks {
    @MainActor static func run(root: URL,defaults: UserDefaults) throws {
        let file=root.appendingPathComponent("children.json")
        let familyFile=file.deletingPathExtension().appendingPathExtension("family-v1.json")
        let legacy=CollectionStore(fileURL:file,defaults:defaults)
        let awards=Array(RewardCatalog.all.prefix(12))
        for award in awards { legacy.progress.rewards.award(award.id) }
        legacy.progress.ruler = .init(startAt:18)
        legacy.selectGroup(StudyCatalog.groups(for:.clock)[1])
        let oldRedemption=UUID()
        precondition(legacy.redeem(title:"臻一的书",points:2,requestID:oldRedemption))
        legacy.save()
        let original=try Data(contentsOf:file),old=legacy.progress
        let family=CollectionStore(fileURL:file,defaults:defaults,profilesEnabled:true)
        precondition(family.activeChild == nil && family.loadError == nil)
        precondition(family.selectChild(.zhenyi))
        precondition(family.progress == old)
        let zhen=family.progress
        precondition(family.selectChild(.qianyi))
        precondition(family.progress.rewards.balance == 0 && family.progress.rewards.awardedIDs.isEmpty)
        precondition(family.progress.study.selected.isEmpty && family.progress.ruler.index == 0)
        // Each child may earn the very same challenge once independently.
        family.progress.rewards.award(awards[0].id)
        family.progress.rewards.award(awards[0].id)
        precondition(family.progress.rewards.balance == 1)
        let request=UUID()
        precondition(family.redeem(title:"千一的小礼物",points:1,requestID:request))
        precondition(family.progress.rewards.balance == 0)
        family.progress.ruler = .init(startAt:9)
        family.save()
        precondition(family.selectChild(.zhenyi))
        precondition(family.progress == zhen)
        family.refund(request) // A sibling's redemption cannot be refunded here.
        precondition(family.progress == zhen)
        var now=100.0
        let qianReload=CollectionStore(fileURL:file,defaults:defaults,uptime:{now},profilesEnabled:true)
        precondition(qianReload.activeChild == nil) // Every launch requires an explicit choice.
        precondition(qianReload.selectChild(.qianyi))
        precondition(qianReload.progress.ruler.index == 9 && qianReload.progress.rewards.balance == 0)
        qianReload.refund(request)
        precondition(qianReload.progress.rewards.balance == 1)
        precondition(qianReload.selectChild(.zhenyi))
        precondition(qianReload.progress == zhen)
        // Both time purchases and partial use belong to one child only.
        precondition(qianReload.buyFunTime(requestID:UUID()))
        let zhenTime=qianReload.funMilliseconds
        precondition(zhenTime == 300_000)
        qianReload.resumeFun(.arrows);now += 1.25
        precondition(qianReload.selectChild(.qianyi))
        precondition(qianReload.funMilliseconds == 0 && qianReload.progress.rewards.balance == 1)
        precondition(qianReload.selectChild(.zhenyi))
        precondition(qianReload.funMilliseconds == zhenTime-1250 && !qianReload.funPlaying)
        let legacyBytes=try Data(contentsOf:file);precondition(legacyBytes == original) // Original single-child backup stays untouched.

        // Failed switching retains the active child's live state and all durable balances.
        let moved=root.appendingPathComponent("family-backup.json")
        try FileManager.default.moveItem(at:familyFile,to:moved)
        try FileManager.default.createDirectory(at:familyFile,withIntermediateDirectories:true)
        let before=qianReload.progress
        precondition(!qianReload.selectChild(.qianyi))
        precondition(qianReload.activeChild == .zhenyi && qianReload.progress == before && qianReload.saveError != nil)
        try FileManager.default.removeItem(at:familyFile)
        try FileManager.default.moveItem(at:moved,to:familyFile)
        precondition(qianReload.selectChild(.qianyi))

        // A corrupt family file must never trigger reimport or overwrite either file.
        let bad=Data("broken family".utf8)
        try bad.write(to:familyFile)
        let corrupt=CollectionStore(fileURL:file,defaults:defaults,profilesEnabled:true)
        precondition(corrupt.loadError != nil && !corrupt.selectChild(.zhenyi))
        corrupt.save()
        let badBytes=try Data(contentsOf:familyFile);precondition(badBytes == bad)
        let finalLegacyBytes=try Data(contentsOf:file);precondition(finalLegacyBytes == original)
        print("PASS: fixed child profiles, exact legacy migration to 臻一, isolated rewards/redemptions/progress/play time, restart choice, failed-switch rollback and corrupt-file preservation.")
    }
}
