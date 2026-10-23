import Foundation

enum LibraryChecks {
    static func run() throws {
        var sharing=SharingSession()
        for index in SharingTask.all.indices {
            let task=sharing.task
            precondition(sharing.index == index && sharing.remaining == task.total)
            precondition(!sharing.check())
            sharing.give(to:0); sharing.take(from:0)
            precondition(sharing.remaining == task.total)
            for bowl in 0..<task.bowls { for _ in 0..<task.each { sharing.give(to:bowl) } }
            precondition(sharing.isValid && sharing.remaining == task.remainder && sharing.check())
            let before=sharing; sharing.give(to:0); precondition(sharing == before)
            sharing.next()
        }
        precondition(sharing.phase == .complete)
        var wordsChecked=0
        for game in LearningGame.allCases where game.isWorkshop {
            let questions=WorkshopContent.questions(for:game)
            var session=WorkshopSession()
            for q in questions {
                precondition(!q.answer.isEmpty && q.labels.count == q.answer.count)
                precondition(q.choices.isEmpty || q.choices.indices.contains(q.correctChoice))
                precondition(!session.check(q))
                session.choose(0,question:q); session.choose(0,question:q)
                precondition(session.chosen == [0]); session.remove(at:0)
                precondition(session.chosen.isEmpty)
                for i in q.answer.indices { session.choose(i,question:q) }
                precondition(session.isValid(for:questions) && session.check(q))
                if !q.choices.isEmpty {
                    session.answerFollowUp((q.correctChoice+1) % q.choices.count,question:q)
                    precondition(session.phase == .followUp && session.hint != nil)
                    session.answerFollowUp(q.correctChoice,question:q)
                }
                precondition(session.phase == .correct)
                let before=session; session.choose(0,question:q); precondition(session == before)
                session.next(total:questions.count); wordsChecked += 1
            }
            precondition(session.phase == .complete)
        }
        precondition(WorkshopContent.pinyin[11].reading == "xuě")
        var clock=ClockSession()
        for index in ClockTask.all.indices {
            let task=clock.task
            precondition(clock.index == index)
            if task.mode == .conversion { precondition(clock.check(choice:task.correctChoice)) }
            else if task.mode == .seconds { clock.select(.second); clock.setTick(task.target); precondition(clock.check()) }
            else {
                clock.select(.hour); clock.setTick(task.target/60*5)
                clock.select(.minute); clock.setTick(task.target % 60)
                precondition(clock.minutes == task.target && clock.check())
            }
            precondition(clock.isValid); clock.next()
        }
        precondition(clock.phase == .complete)
        clock=ClockSession(); clock.select(.minute); clock.nudge(-1)
        precondition(clock.minutes == 719)
        clock.setTick(0,carry:true); precondition(clock.minutes == 0)
        clock.setTick(59,carry:true); precondition(clock.minutes == 719)
        precondition(MatchPuzzle.all.count == 360)
        precondition(MatchPuzzle.all.allSatisfy { $0.rule == .move })
        for puzzle in MatchPuzzle.all {
            precondition(MatchPuzzle.decode(puzzle.initial) != nil && !MatchPuzzle.isTrue(puzzle.initial))
            precondition(puzzle.accepts(puzzle.solution) && !puzzle.accepts(puzzle.initial))
        }
        var matches=MatchSession()
        for puzzle in MatchPuzzle.all {
            let change=puzzle.initial ^ puzzle.solution
            let from=(0..<23).first { puzzle.initial & change & (1 << $0) != 0 }!
            let to=(0..<23).first { puzzle.solution & change & (1 << $0) != 0 }!
            precondition(!matches.move(from:to,to:from))
            matches.tap(to); precondition(matches.mask == puzzle.initial)
            matches.tap(from); precondition(matches.selectedMatch == from)
            let selectedData = try JSONEncoder().encode(matches)
            let selectedCopy = try JSONDecoder().decode(MatchSession.self,from:selectedData)
            precondition(selectedCopy == matches)
            matches.tap(to); precondition(matches.mask == puzzle.solution && matches.selectedMatch == nil)
            precondition(!matches.move(from:from,to:to))
            precondition(matches.isValid)
            precondition(matches.check()); matches.next()
        }
        precondition(matches.phase == .complete)
        for level in 0..<FruitSession.levelCount {
            let generated=FruitSession.generated(level:level)
            var fruit=FruitSession(); fruit.level=level; fruit.reset()
            precondition(fruit.jars == generated.board && fruit.isValid && !fruit.isSolved)
            precondition(!fruit.move(from:0,to:999))
            for move in generated.solution { precondition(fruit.move(from:move.from,to:move.to) && fruit.isValid) }
            precondition(fruit.isSolved)
            fruit.undo(); precondition(fruit.isValid)
            fruit.reset(); precondition(fruit.jars == generated.board)
        }
        var art=PrintSession()
        for material in 0..<4 { for color in 0..<6 { art.material=material;art.color=color;art.stamp(x:0.25,y:0.75) } }
        precondition(art.stamps.count == 24 && art.isValid)
        art.keep(); art.keep(); precondition(art.works.count == 1)
        art.newPaper(); precondition(art.stamps.isEmpty && art.works.count == 1)
        art.openWork(0); precondition(art.stamps.count == 24)
        art.undo(); precondition(art.stamps.count == 23)
        let before=art.stamps; art.stamp(x:.nan,y:0.5); precondition(art.stamps == before)
        var collection=CollectionProgress();collection.printing=art;collection.sharing=sharing;collection.matches=matches;collection.clock=clock
        let data=collection.encoded()!
        precondition(collection.isValid && CollectionProgress.restore(data) == collection)
        var oldCollection=collection; oldCollection.matches.ruleSetVersion=nil
        let migrated=CollectionProgress.restore(oldCollection.encoded()!)!
        precondition(migrated.matches == MatchSession() && migrated.printing == art && migrated.sharing == sharing)
        var invalid=collection; invalid.words[LearningGame.pinyin.rawValue]?.index=999
        precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        invalid=collection; invalid.printing.pressure=99
        precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        print("PASS: \(SharingTask.all.count) sharing tasks, \(wordsChecked) assembly/follow-up tasks, \(ClockTask.all.count) clock tasks + carry, \(MatchPuzzle.all.count) matchstick puzzles, \(FruitSession.levelCount) provably solvable sorting levels, art/gallery and collection persistence.")
    }
}
