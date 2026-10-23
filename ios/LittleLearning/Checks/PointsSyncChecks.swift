import Foundation

enum PointsSyncChecks {
    static func fails(_ action: () throws -> Void) {
        do { try action();preconditionFailure("Expected rejected sync") } catch {}
    }
    static func run() throws {
        let challenges=Array(RewardCatalog.all.prefix(20))
        var a=RewardLedger(),b=RewardLedger()
        for challenge in challenges.prefix(12) { a.award(challenge.id);b.award(challenge.id) }
        let redemption=UUID();a.redeem(title:"书",points:2,requestID:redemption)
        b=try b.merging(a)
        a.refund(redemption);b.refund(redemption) // Two independently made refund events.
        b.award(challenges[12].id)
        let ab=try a.merging(b),ba=try b.merging(a)
        precondition(ab == ba && ab.balance == 13)
        precondition(ab.entries.filter { $0.kind == .refund }.count == 1)
        precondition(ab.entries.filter { $0.kind == .award }.count == 13)
        let repeated=try ab.merging(a).merging(b);precondition(repeated == ab)
        // Independent spend conflicts never delete either device's records.
        var x=RewardLedger(),y=RewardLedger()
        x.award(challenges[0].id);y.award(challenges[0].id)
        x.redeem(title:"糖",points:1,requestID:UUID());y.redeem(title:"贴纸",points:1,requestID:UUID())
        fails { _ = try x.merging(y) }
        let sharedID=UUID()
        var conflictA=RewardLedger(),conflictB=RewardLedger()
        conflictA.award(challenges[0].id);conflictB.award(challenges[0].id)
        conflictA.redeem(title:"A",points:1,requestID:sharedID);conflictB.redeem(title:"B",points:1,requestID:sharedID)
        fails { _ = try conflictA.merging(conflictB) }
        // One snapshot always carries both names, not the current screen's selected child.
        let snapshot=PointsSyncSnapshot(ledgers:["qianyi":ab,"zhenyi":a])
        let frames=try PointsSyncCode.frames(snapshot)
        precondition(frames.count > 1 && frames.allSatisfy { $0.utf8.count < 900 })
        var scanner=PointsSyncScanner(),restored:PointsSyncSnapshot?
        for frame in frames.reversed() {
            if let done=try scanner.accept(frame) { restored=done }
            if let done=try scanner.accept(frame) { restored=done }
        }
        precondition(restored?.ledgers == snapshot.ledgers && scanner.received == frames.count)
        var partial=PointsSyncScanner();_ = try partial.accept(frames[0]);precondition(partial.received == 1)
        fails { _ = try partial.accept("not a sync QR") }
        var wrong=PointsSyncScanner();var fields=frames[0].components(separatedBy:"|")
        fields[4]=String(repeating:"0",count:64)
        for frame in frames.dropLast() { _ = try wrong.accept(frame) }
        fails { _ = try wrong.accept(fields.joined(separator:"|")) }
        var tampered=PointsSyncScanner()
        var damaged=frames[0].components(separatedBy:"|")
        damaged[5]=(damaged[5].first == "A" ? "B" : "A")+damaged[5].dropFirst()
        _ = try tampered.accept(damaged.joined(separator:"|"))
        for frame in frames.dropFirst().dropLast() { _ = try tampered.accept(frame) }
        fails { _ = try tampered.accept(frames.last!) }
        let another=try PointsSyncCode.frames(snapshot)
        fails { _ = try partial.accept(another[0]) }
        var missing=PointsSyncScanner();for frame in frames.dropLast() { precondition(tryResult(&missing,frame) == nil) }
        fails { _ = try PointsSyncCode.frames(.init(ledgers:["qianyi":a])) }
        // Maximum current challenge catalog plus historical redemptions fits multiple frames.
        var full=RewardLedger();for challenge in RewardCatalog.all { full.award(challenge.id) }
        for _ in 0..<100 { let id=UUID();full.redeem(title:"家庭小礼物",points:1,requestID:id);full.refund(id) }
        let large=PointsSyncSnapshot(ledgers:["qianyi":full,"zhenyi":full])
        let largeFrames=try PointsSyncCode.frames(large);var largeScanner=PointsSyncScanner(),largeResult:PointsSyncSnapshot?
        for frame in largeFrames.shuffled() { if let result=try largeScanner.accept(frame) { largeResult=result } }
        precondition(largeResult?.ledgers == large.ledgers)
        print("PASS: QR sync event union, repeated/independent awards and refunds, bidirectional convergence, spending/UUID conflicts, compressed multipart roundtrip, reordered/duplicate/missing/mixed/corrupt frames, and full catalog (\(largeFrames.count) frames).")
    }
    static func tryResult(_ scanner: inout PointsSyncScanner,_ frame: String) -> PointsSyncSnapshot? { try! scanner.accept(frame) }
}
