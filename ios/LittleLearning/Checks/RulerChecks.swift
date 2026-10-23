import Foundation

enum RulerChecks {
    static func solve(_ state: inout RulerSession) {
        let task=state.task
        switch task.mode {
        case .measure,.offset:state.move(to:2);state.choose(task.length);state.check()
        case .missingNumber:state.choose(task.blank!);state.check()
        case .target:
            let a=task.marks.first { a in task.marks.contains(a+task.length) }!
            state.tap(a);state.tap(a+task.length);state.check()
        case .explore:
            for length in task.distances.sorted() {
                let a=task.marks.first { a in task.marks.contains(a+length) }!
                state.clearPair();state.tap(a);state.tap(a+length);state.check()
            }
        }
    }
    static func run() throws {
        precondition(RulerTask.all.count == 24 && Set(RulerTask.all.map(\.identity)).count == 24)
        precondition(StudyCatalog.groups(for:.ruler).map(\.count) == [8,8,8])
        precondition(RulerTask.all[16].distances == Set(1...6))
        for i in RulerTask.all.indices {
            let task=RulerTask.all[i]
            precondition(task.marks.count >= 4 && task.marks == task.marks.sorted() && Set(task.marks).count == task.marks.count)
            var state=RulerSession(startAt:i)
            state.check();precondition(state.phase == .playing && state.hint != nil)
            state.revealHint();precondition(state.showUnits)
            state.reset();precondition(!state.showUnits && state.hint == nil)
            solve(&state);precondition(state.phase == .correct && state.isValid)
            let frozen=state;state.move(to:0);state.choose(0);state.tap(0);state.clearPair();state.check();state.revealHint();precondition(state == frozen)
            let restored=try JSONDecoder().decode(RulerSession.self,from:JSONEncoder().encode(state))
            precondition(restored == state && restored.isValid)
            if task.canMove {
                for origin in 0...4 {
                    var candidate=RulerSession(startAt:i);candidate.move(to:origin);candidate.choose(task.length)
                    let a=task.objectStart-origin
                    let valid=task.marks.contains(a) && task.marks.contains(a+task.length) && (task.mode != .measure || a == 0)
                    candidate.check();precondition((candidate.phase == .correct) == valid)
                }
            }
            if task.mode == .target {
                for a in task.marks { for b in task.marks where a != b {
                    var candidate=RulerSession(startAt:i);candidate.tap(a);candidate.tap(b);candidate.check()
                    precondition((candidate.phase == .correct) == (abs(a-b) == task.length))
                } }
            }
        }
        var explore=RulerSession(startAt:23)
        explore.tap(1);explore.tap(3);explore.check();let found=explore.found
        explore.check();precondition(explore.found == found && explore.phase == .playing)
        let pair=explore.pair;explore.tap(2);precondition(explore.pair == pair) // Missing marks cannot be used.
        let resumed=try JSONDecoder().decode(RulerSession.self,from:JSONEncoder().encode(explore));precondition(resumed.found == found)
        var old=CollectionProgress();old.printing.stamp(x:0.4,y:0.6);old.rewards.award(RewardCatalog.arithmetic(.init(start:1,change:1)).id)
        var json=try JSONSerialization.jsonObject(with:old.encoded()!) as! [String:Any];json.removeValue(forKey:"ruler")
        let migrated=CollectionProgress.restore(try JSONSerialization.data(withJSONObject:json))!
        precondition(migrated.ruler == RulerSession() && migrated.rewards == old.rewards && migrated.printing == old.printing)
        var invalid=try JSONSerialization.jsonObject(with:JSONEncoder().encode(RulerSession())) as! [String:Any]
        for (key,value) in [("index",999),("origin",99),("answer",99)] {
            var data=invalid;data[key]=value;json["ruler"]=data
            let encoded=try JSONSerialization.data(withJSONObject:json)
            precondition(CollectionProgress.restore(encoded) == nil)
        }
        invalid["phase"]="correct";json["ruler"]=invalid
        let corrupted=try JSONSerialization.data(withJSONObject:json)
        precondition(CollectionProgress.restore(corrupted) == nil)
        print("PASS: 24 ruler puzzles, all endpoint alternatives, alignment guards, sparse-ruler completeness, duplicate discoveries, saved-state validation and legacy migration.")
    }
}
