import Foundation

@MainActor enum StudyStoreChecks {
    static func run(root: URL,defaults: UserDefaults) throws {
        defaults.removeObject(forKey:"numberLine.v1")
        let math=CollectionStore(fileURL:root.appendingPathComponent("study-math.json"),defaults:defaults)
        let five=StudyCatalog.group("arithmetic-5",for:.numberLine)!
        math.selectGroup(five)
        precondition(math.group(.numberLine)?.id == five.id && math.progress.rewards.balance == 0)
        while math.remaining(.numberLine) > 0 {
            var round=math.progress.numberLine!
            precondition(round.questions.allSatisfy { !math.progress.rewards.hasAward(RewardCatalog.arithmetic($0).id) })
            while round.phase == .playing {
                round.move(to:round.question.answer);round.check();math.progress.numberLine=round
                round.next();math.progress.numberLine=round
            }
            if math.remaining(.numberLine) > 0 { math.selectGroup(five) }
        }
        math.finishMathIfNeeded()
        precondition(math.progress.rewards.balance == 8 && math.isGroupFinished(.numberLine))
        math.selectGroup(five,review:true)
        var review=math.progress.numberLine!
        for _ in review.questions.indices {
            review.move(to:review.question.answer);review.check();math.progress.numberLine=review
            review.next();math.progress.numberLine=review
        }
        precondition(math.progress.rewards.balance == 8)
        let add=StudyCatalog.group("arithmetic-10-add",for:.numberLine)!
        math.selectGroup(add)
        precondition(math.progress.rewards.balance == 8 && math.remaining(.numberLine) == 8)
        precondition(math.progress.numberLine!.questions.allSatisfy { $0.change > 0 && !math.progress.rewards.hasAward(RewardCatalog.arithmetic($0).id) })
        let mathReload=CollectionStore(fileURL:root.appendingPathComponent("study-math.json"),defaults:defaults)
        precondition(mathReload.group(.numberLine)?.id == add.id && mathReload.progress.rewards.balance == 8)

        let clock=CollectionStore(fileURL:root.appendingPathComponent("study-clock.json"),defaults:defaults)
        clock.selectGroup(StudyCatalog.group("clock-halves",for:.clock)!)
        precondition(clock.progress.clock.index == 2 && clock.progress.rewards.balance == 0)
        var c=clock.progress.clock
        c.select(.hour);c.setTick(c.task.target/60*5);c.select(.minute);c.setTick(c.task.target%60);c.check()
        clock.progress.clock=c
        precondition(clock.progress.rewards.balance == 1 && clock.progress.rewards.entries.count == 1)
        precondition(!clock.progress.rewards.hasAward(RewardCatalog.clock(ClockTask.all[0]).id))
        clock.advance(.clock)
        let index=clock.progress.clock.index
        precondition(clock.progress.clock.phase == .playing)
        clock.advance(.clock);precondition(clock.progress.clock.index == index)

        let fruit=CollectionStore(fileURL:root.appendingPathComponent("study-fruit.json"),defaults:defaults)
        fruit.selectGroup(StudyCatalog.group("sorting-advanced",for:.sorting)!)
        let firstLevel=fruit.progress.fruits.level
        precondition(firstLevel >= 8 && fruit.progress.rewards.balance == 0)
        for move in FruitSession.generated(level:firstLevel).solution { fruit.progress.fruits.move(from:move.from,to:move.to) }
        precondition(fruit.progress.rewards.balance == 3 && fruit.progress.rewards.entries.count == 1)
        fruit.advance(.sorting)
        precondition(fruit.progress.rewards.balance == 3 && fruit.progress.fruits.level != firstLevel)
        // Choosing a different tier must not award the levels between its catalog slot and zero.
        fruit.selectGroup(StudyCatalog.group("sorting-start",for:.sorting)!)
        precondition(fruit.progress.rewards.balance == 3 && fruit.progress.fruits.level == 0)

        let words=CollectionStore(fileURL:root.appendingPathComponent("study-words.json"),defaults:defaults)
        let group=StudyCatalog.group("characters-similar",for:.characters)!
        words.selectGroup(group)
        precondition(words.progress.rewards.balance == 0)
        let s=words.session(.characters), q=WorkshopContent.characters[s.index]
        words.editWorkshop(.characters) { state in for tile in q.answer.indices { state.choose(tile,question:q) };state.check(q) }
        precondition(words.session(.characters).phase == .followUp && words.progress.rewards.balance == 0)
        words.editWorkshop(.characters) { $0.answerFollowUp(q.correctChoice,question:q) }
        precondition(words.progress.rewards.balance == 1 && words.progress.rewards.entries.count == 1)
        words.selectGroup(StudyCatalog.group("characters-start",for:.characters)!)
        precondition(words.progress.rewards.balance == 1)
        words.selectGroup(group)
        precondition(words.session(.characters).index != s.index && words.progress.rewards.balance == 1)

        let share=CollectionStore(fileURL:root.appendingPathComponent("study-share.json"),defaults:defaults)
        share.selectGroup(StudyCatalog.group("sharing-remainder",for:.sharing)!)
        let task=share.progress.sharing.task
        precondition(task.remainder > 0 && share.progress.rewards.balance == 0)
        for bowl in 0..<task.bowls { for _ in 0..<task.each { share.progress.sharing.give(to:bowl) } }
        precondition(share.progress.sharing.check() && share.progress.rewards.balance == 1)
        let before=share.progress.rewards.entries
        share.prepareGroup(.sharing);share.save()
        let shareReload=CollectionStore(fileURL:root.appendingPathComponent("study-share.json"),defaults:defaults)
        precondition(shareReload.progress.rewards.entries == before && shareReload.group(.sharing)?.id == "sharing-remainder")
        print("PASS: remembered groups, new-first rounds, all-8 completion + review, cross-tier deduplication, no phantom awards on index jumps, follow-up gating, remainder tasks and no double-next skipping.")
    }
}
