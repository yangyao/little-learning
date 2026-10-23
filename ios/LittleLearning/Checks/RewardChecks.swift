import Foundation

enum RewardChecks {
    static func reconcile(_ state: inout CollectionProgress) {
        for challenge in RewardCatalog.completed(in:state) { state.rewards.award(challenge.id) }
    }
    static func run() throws {
        precondition(Set(RewardCatalog.all.map(\.id)).count == RewardCatalog.all.count)
        var ledger=RewardLedger()
        precondition(ledger.balance == 0 && ledger.isValid)
        precondition(!ledger.award("not-a-challenge"))
        precondition(!ledger.redeem(title:"自己选的书",points:10,requestID:UUID()))
        let firstTen=Array(RewardCatalog.all.prefix(10))
        for q in firstTen { precondition(ledger.award(q.id)); precondition(!ledger.award(q.id)) }
        precondition(ledger.balance == 10)
        precondition(!ledger.redeem(title:"书",points:0,requestID:UUID()))
        precondition(!ledger.redeem(title:"书",points:-1,requestID:UUID()))
        precondition(!ledger.redeem(title:"书",points:11,requestID:UUID()))
        var custom=ledger
        precondition(custom.redeem(title:"  自定义奖励  ",points:3,requestID:UUID()))
        precondition(custom.balance == 7 && custom.entries.last?.title == "自定义奖励")
        let customCopy=try JSONDecoder().decode(RewardLedger.self,from:JSONEncoder().encode(custom))
        precondition(customCopy == custom && customCopy.isValid)
        let request=UUID()
        precondition(ledger.redeem(title:"自己选的书",points:10,requestID:request) && ledger.balance == 0)
        precondition(!ledger.redeem(title:"自己选的书",points:10,requestID:request))
        for q in firstTen { precondition(!ledger.award(q.id)) }
        precondition(ledger.balance == 0)
        precondition(ledger.refund(request) && ledger.balance == 10)
        precondition(!ledger.refund(request) && !ledger.refund(UUID()))
        precondition(!ledger.redeem(title:"自己选的书",points:10,requestID:request))
        precondition(!ledger.redeem(title:"   ",points:1,requestID:UUID()))
        precondition(ledger.isValid && ledger.awardedIDs.count == 10)
        let copy=try JSONDecoder().decode(RewardLedger.self,from:JSONEncoder().encode(ledger))
        precondition(copy == ledger && copy.isValid)

        // Every first completion earns exactly its declared value, then stays earned after spending.
        var all=RewardLedger()
        for challenge in RewardCatalog.all { precondition(all.award(challenge.id)) }
        let earned=RewardCatalog.all.reduce(0){$0+$1.points}
        precondition(all.balance == earned && all.isValid)
        for challenge in RewardCatalog.all.reversed() { precondition(!all.award(challenge.id)) }
        let spent=UUID();precondition(all.redeem(title:"手工填写",points:80,requestID:spent))
        for challenge in RewardCatalog.all { precondition(!all.award(challenge.id)) }
        precondition(all.balance == earned-80 && all.isValid)

        var progress=CollectionProgress()
        var arithmetic=NumberLineGame(questions:[.init(start:3,change:2),.init(start:2,change:-2)])
        progress.numberLine=arithmetic; reconcile(&progress);precondition(progress.rewards.balance == 0)
        arithmetic.check();progress.numberLine=arithmetic;reconcile(&progress);precondition(progress.rewards.balance == 0)
        arithmetic.move(to:5);arithmetic.check();progress.numberLine=arithmetic;reconcile(&progress)
        precondition(progress.rewards.balance == 1)
        // Same equation in a fresh round and different slot is still the same challenge.
        arithmetic=NumberLineGame(questions:[.init(start:3,change:2)])
        arithmetic.move(to:5);arithmetic.check();progress.numberLine=arithmetic;reconcile(&progress)
        precondition(progress.rewards.balance == 1)
        for game in LearningGame.allCases where game.isWorkshop {
            var session=WorkshopSession()
            for q in WorkshopContent.questions(for:game) {
                let before=progress.rewards.balance
                for i in q.answer.indices { session.choose(i,question:q) }
                session.check(q);progress.words[game.rawValue]=session;reconcile(&progress)
                if !q.choices.isEmpty {
                    precondition(progress.rewards.balance == before)
                    session.answerFollowUp((q.correctChoice+1)%q.choices.count,question:q)
                    progress.words[game.rawValue]=session;reconcile(&progress);precondition(progress.rewards.balance == before)
                    session.answerFollowUp(q.correctChoice,question:q)
                    progress.words[game.rawValue]=session;reconcile(&progress)
                }
                precondition(progress.rewards.balance == before+1)
                reconcile(&progress);precondition(progress.rewards.balance == before+1)
                session.next(total:WorkshopContent.questions(for:game).count)
            }
            progress.words[game.rawValue] = .init();reconcile(&progress)
        }
        let beforeSorting=progress.rewards.balance
        for move in FruitSession.generated(level:0).solution { progress.fruits.move(from:move.from,to:move.to);reconcile(&progress) }
        precondition(progress.fruits.isSolved && progress.rewards.balance == beforeSorting+3)
        progress.fruits.reset()
        for move in FruitSession.generated(level:0).solution { progress.fruits.move(from:move.from,to:move.to);reconcile(&progress) }
        precondition(progress.rewards.balance == beforeSorting+3)
        let beforeArt=progress.rewards.balance
        progress.printing.stamp(x:0.5,y:0.5);progress.printing.keep();reconcile(&progress)
        precondition(progress.rewards.balance == beforeArt)
        precondition(progress.isValid)
        let data=progress.encoded()!
        let restored=CollectionProgress.restore(data)!
        precondition(restored == progress)
        var restarted=restored;reconcile(&restarted);precondition(restarted.rewards == progress.rewards)

        // Older game saves migrate without dropping progress or silently inventing a balance.
        var old=try JSONSerialization.jsonObject(with:CollectionProgress().encoded()!) as! [String:Any]
        old.removeValue(forKey:"rewards");old.removeValue(forKey:"numberLine")
        let migrated=CollectionProgress.restore(try JSONSerialization.data(withJSONObject:old))!
        precondition(migrated.rewards.balance == 0 && migrated.numberLine == nil && migrated.sharing == SharingSession())

        // Reject duplicate awards, forged amounts, duplicate refunds, and negative balances.
        let json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(ledger)) as! [String:Any]
        let entries=json["entries"] as! [[String:Any]]
        func invalid(_ rows: [[String:Any]]) throws {
            let decoded=try JSONDecoder().decode(RewardLedger.self,from:JSONSerialization.data(withJSONObject:["entries":rows]))
            precondition(!decoded.isValid)
        }
        var duplicate=entries[0];duplicate["id"]=UUID().uuidString
        try invalid(entries+[duplicate])
        var forged=entries;forged[0]["amount"]=999;try invalid(forged)
        var duplicateRefund=entries.last!;duplicateRefund["id"]=UUID().uuidString
        try invalid(entries+[duplicateRefund])
        var overspend=entries;overspend[10]["amount"] = -11;try invalid(overspend)
        print("PASS: \(RewardCatalog.all.count) stable one-time challenge IDs; retries/follow-ups/replays/restarts, ledger migration, spending, duplicate requests, refunds and corrupt-ledger rejection.")
    }
}
