import Foundation

enum FunChecks {
    static func run() throws {
        var arrows=ArrowEscapeSession(),blockedSeen=false,signatures=Set<String>()
        for task in ArrowEscapeTask.all {
            precondition(task.index == arrows.level && task.arrows.count >= 4)
            let signature=task.arrows.map { $0.cells.map {"\($0.x),\($0.y)"}.joined(separator:";") }.joined(separator:"|")
            precondition(signatures.insert(signature).inserted)
            if let blocked=task.arrows.first(where:{!task.canRemove($0.id,removed:[])}) {
                precondition(!arrows.tap(blocked.id) && arrows.removed.isEmpty && arrows.hint != nil);blockedSeen=true
            }
            let initial=arrows;arrows.next();precondition(arrows == initial)
            for id in task.solution { precondition(arrows.tap(id) && arrows.isValid) }
            precondition(arrows.isSolved)
            let copy=try JSONDecoder().decode(ArrowEscapeSession.self,from:JSONEncoder().encode(arrows));precondition(copy == arrows && copy.isValid)
            precondition(!arrows.tap(task.solution[0]))
            arrows.next()
        }
        precondition(blockedSeen && arrows.level == 0 && arrows.removed.isEmpty)
        var ants=AntCarrySession(),stuckFound=false
        for task in AntCarryTask.all {
            precondition(task.index == ants.level && task.pixels.count == 100 && task.pixelCount > 20)
            for lane in task.solution {
                let moves=ants.dispatch(lane)
                precondition(!moves.isEmpty && ants.isValid)
            }
            precondition(ants.isSolved && ants.board.slots.allSatisfy {$0 == nil})
            let copy=try JSONDecoder().decode(AntCarrySession.self,from:JSONEncoder().encode(ants));precondition(copy == ants && copy.isValid)
            ants.undo();precondition(!ants.isSolved && ants.isValid)
            _=ants.dispatch(task.solution.last!);precondition(ants.isSolved)
            // Explore bad orderings and ensure a dead end can always undo to a valid board.
            var trial=ants;trial.reset()
            for _ in 0..<30 {
                let old=trial.board
                let lane=(0..<3).reversed().first(where:{trial.nextWorker(in:$0) != nil && !trial.board.slots.allSatisfy {$0 != nil}})
                guard let lane else { break }
                _=trial.dispatch(lane);precondition(trial.isValid)
                if trial.isStuck { stuckFound=true;trial.undo();precondition(trial.board == old && trial.isValid);break }
                if trial.isSolved { break }
            }
            ants.next()
        }
        precondition(ants.level == 0 && stuckFound)
        var ledger=RewardLedger(),bank=FunTimeBank()
        for c in RewardCatalog.all.prefix(10) { ledger.award(c.id) }
        let request=UUID();precondition(ledger.buyPlayTime(requestID:request) && ledger.balance == 5)
        precondition(!ledger.buyPlayTime(requestID:request) && !ledger.refund(request))
        precondition(bank.remaining(in:ledger) == 300_000 && bank.isValid(in:ledger))
        precondition(bank.consume(2500,in:ledger) == 2500 && bank.remaining(in:ledger) == 297_500)
        precondition(bank.consume(-10,in:ledger) == 0)
        precondition(bank.consume(Int.max,in:ledger) == 297_500 && bank.remaining(in:ledger) == 0)
        precondition(ledger.buyPlayTime(requestID:UUID()) && ledger.balance == 0 && ledger.isValid)
        precondition(!ledger.buyPlayTime(requestID:UUID()) && bank.remaining(in:ledger) == 300_000)
        var meter=FunTimeMeter();meter.start(at:10)
        precondition(meter.take(at:10.25) == 250 && meter.take(at:10.5) == 250)
        precondition(meter.elapsed(at:9) == 0 && meter.elapsed(at:.nan) == 0)
        meter.stop();precondition(meter.take(at:9999) == 0)
        meter.start(at:10_000);precondition(meter.take(at:10_001) == 1000)
        var p=CollectionProgress();p.rewards=ledger;p.funTime=bank
        precondition(p.isValid && CollectionProgress.restore(p.encoded()!) == p)
        var json=try JSONSerialization.jsonObject(with:p.encoded()!) as! [String:Any]
        json["funTime"]=["spentMilliseconds":-1]
        precondition(CollectionProgress.restore(try! JSONSerialization.data(withJSONObject:json)) == nil)
        json["funTime"]=["spentMilliseconds":999_999_999]
        precondition(CollectionProgress.restore(try! JSONSerialization.data(withJSONObject:json)) == nil)
        var old=CollectionProgress();old.rewards.award(RewardCatalog.all[0].id);old.printing.stamp(x:0.2,y:0.7)
        json=try JSONSerialization.jsonObject(with:old.encoded()!) as! [String:Any]
        for key in ["funTime","funArrows","funAnts"] {json.removeValue(forKey:key)}
        let imported=CollectionProgress.restore(try JSONSerialization.data(withJSONObject:json))!
        precondition(imported.rewards == old.rewards && imported.printing == old.printing && imported.funTime.remaining(in:imported.rewards) == 0)
        print("PASS: 48 solvable arrow boards, 24 complete ant pictures, dead-end undo, exact time credits/spend, purchase deduplication, clock pauses and old-save migration.")
    }
}
