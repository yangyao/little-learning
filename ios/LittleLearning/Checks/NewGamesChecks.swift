import Foundation

enum NewGamesChecks {
    static func solve(_ task: TangramTask) -> TangramSession {
        var s=TangramSession(startAt:task.index)
        for i in 0..<7 {
            s.select(i)
            while s.turns[i] != task.solution[i].rotation { s.rotate() }
            if s.flips[i] != task.solution[i].flipped { s.flip() }
            s.place(x:task.solution[i].x,y:task.solution[i].y)
        }
        s.check();return s
    }
    static func run() throws {
        var silhouettes=Set<Set<Int>>()
        for task in TangramTask.all {
            precondition(task.solution.count == 7 && task.target.count == 64)
            precondition(silhouettes.insert(task.target).inserted)
            var coverage=Set<Int>()
            for i in 0..<7 {
                precondition(TangramGeometry.inBounds(i,task.solution[i]))
                let c=TangramGeometry.coverage(i,task.solution[i])
                precondition(c.count == [16,16,8,4,4,8,8][i] && coverage.isDisjoint(with:c));coverage.formUnion(c)
            }
            var incomplete=TangramSession(startAt:task.index);incomplete.check();precondition(incomplete.phase == .playing && incomplete.hint != nil)
            let solved=solve(task);precondition(solved.phase == .correct && solved.isValid)
            let copy=try JSONDecoder().decode(TangramSession.self,from:JSONEncoder().encode(solved));precondition(copy == solved && copy.isValid)
            var reset=solved;reset.reset();precondition(reset.phase == .playing && reset.isValid)
        }
        // A different arrangement of the two interchangeable large triangles is accepted.
        var alternative=TangramSession()
        let task=TangramTask.all[0]
        for i in 0..<7 {
            let p=task.solution[i == 0 ? 1 : i == 1 ? 0 : i]
            alternative.select(i)
            while alternative.turns[i] != p.rotation { alternative.rotate() }
            if alternative.flips[i] != p.flipped { alternative.flip() }
            alternative.place(x:p.x,y:p.y)
        }
        alternative.check();precondition(alternative.phase == .correct)
        var overlap=TangramSession()
        overlap.select(0);overlap.place(x:0,y:0);overlap.select(1);overlap.place(x:0,y:0);overlap.check()
        precondition(overlap.phase == .playing)
        for task in RouteTask.all {
            let trace=task.trace(task.solution)
            precondition(trace.success && trace.frames.count == task.solution.count+1)
            precondition(trace.frames.last?.point == task.goal && trace.frames.last?.collected == true)
            precondition(!task.trace([]).success)
            precondition(!task.trace(Array(repeating:.forward,count:8)).success)
            var s=RouteSession(startAt:task.index)
            // Full rotations do not change a valid route; all valid solutions count.
            for c in [RouteCommand.left,.left,.left,.left]+task.solution { s.append(c) }
            s.check();precondition(s.phase == .correct && s.isValid)
            let copy=try JSONDecoder().decode(RouteSession.self,from:JSONEncoder().encode(s));precondition(copy == s && copy.isValid)
            var reset=s;reset.reset();reset.append(.forward);reset.remove(at:0);precondition(reset.commands.isEmpty && reset.isValid)
        }
        for task in BeadTask.all {
            var s=BeadSession(startAt:task.index)
            s.check();precondition(s.phase == .playing)
            for (i,blank) in task.blanks.enumerated() {
                s.select(i);s.choose(task.options.firstIndex(of:task.sequence[blank])!)
            }
            s.check();precondition(s.phase == .correct && s.isValid)
            let copy=try JSONDecoder().decode(BeadSession.self,from:JSONEncoder().encode(s));precondition(copy == s)
            s.reset();s.choose(task.options.firstIndex(where:{$0 != task.sequence[task.blanks[0]]})!);s.check();precondition(s.phase == .playing)
        }
        // An existing phone save has no new fields. Its ledger/artwork must stay intact.
        var old=CollectionProgress();old.rewards.award(RewardCatalog.all[0].id);old.printing.stamp(x:0.3,y:0.4)
        var json=try JSONSerialization.jsonObject(with:old.encoded()!) as! [String:Any]
        for key in ["tangram","delivery","beads"] { json.removeValue(forKey:key) }
        let restored=CollectionProgress.restore(try JSONSerialization.data(withJSONObject:json))!
        precondition(restored.rewards == old.rewards && restored.printing == old.printing && restored.isValid)
        var invalid=restored;invalid.delivery.index=999;precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        invalid=restored;invalid.beads.index = -1;precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        invalid=restored;invalid.tangram.index=999;precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        print("PASS: 24 exact seven-piece silhouettes (including alternative tilings), 36 solvable animated routes, 60 pattern tasks, error/retry/reset/restore, and old-save migration.")
    }
}
