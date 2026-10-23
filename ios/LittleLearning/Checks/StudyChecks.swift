import Foundation

enum StudyChecks {
    static func run() throws {
        precondition(StudyCatalog.all.count == 42)
        var playable=Set<String>()
        for game in LearningGame.allCases where game != .printing {
            let groups=StudyCatalog.groups(for:game)
            precondition(!groups.isEmpty)
            for group in groups {
                precondition(group.count > 0 && group.indices == group.indices.sorted())
                let ids=group.challenges.map(\.id)
                precondition(Set(ids).count == ids.count)
                precondition(ids.allSatisfy { RewardCatalog.byID[$0] != nil })
                playable.formUnion(ids)
                if game == .numberLine {
                    for q in group.arithmetic {
                        precondition((0...group.limit).contains(q.start) && (0...group.limit).contains(q.answer))
                        var session=NumberLineGame(questions:[q],limit:group.limit)
                        precondition(session.move(to:q.answer) && session.check())
                        precondition(NumberLineGame.restore(session.encoded()!) == session)
                    }
                }
                if game == .matches {
                    for index in group.indices {
                        let puzzle=MatchPuzzle.all[index], initial=MatchPuzzle.decode(puzzle.initial)!
                        precondition(initial.3 || initial.0 >= initial.1)
                        precondition(puzzle.accepts(puzzle.solution))
                        if group.id != "matches-2" {
                            let solution=MatchPuzzle.decode(puzzle.solution)!
                            precondition(initial.3 && solution.3 && initial.0+initial.1 <= 10 && solution.0+solution.1 <= 10)
                        }
                    }
                }
            }
        }
        precondition(StudyCatalog.groups(for:.printing).isEmpty)
        // The same question in two groups has one reward identity.
        let five=StudyCatalog.group("arithmetic-5",for:.numberLine)!, add=StudyCatalog.group("arithmetic-10-add",for:.numberLine)!
        let common=Set(five.challenges.map(\.id)).intersection(add.challenges.map(\.id))
        precondition(common.isEmpty)
        precondition(StudyCatalog.groups(for:.numberLine).count == 3)
        let mathIDs=StudyCatalog.groups(for:.numberLine).flatMap(\.challenges).map(\.id)
        precondition(mathIDs.count == 24 && Set(mathIDs).count == 24)
        precondition(StudyCatalog.groups(for:.numberLine).allSatisfy {$0.count == 8 && $0.limit <= 10})
        var ledger=RewardLedger()
        for c in five.challenges { ledger.award(c.id) }
        precondition(ledger.balance == 8 && add.remaining(in:ledger) == 8)
        for id in common { precondition(!ledger.award(id)) }
        // Old catalog identities remain at exactly the same slots.
        precondition(MatchPuzzle.all.prefix(3).map(\.initial) == [8388591,3899389,3139565])
        precondition(WorkshopContent.pinyin[11].reading == "xuě" && WorkshopContent.characters[19].word == "呆")
        let boards=(0..<FruitSession.levelCount).map { String(describing:FruitSession.generated(level:$0).board) }
        precondition(Set(boards).count == boards.count)
        // Expanding a bank cannot invalidate a previously completed end-of-bank save.
        var old=CollectionProgress()
        var character=WorkshopSession(startAt:19), q=WorkshopContent.characters[19]
        for i in q.answer.indices { character.choose(i,question:q) }
        character.check(q);character.answerFollowUp(0,question:q)
        old.words[LearningGame.characters.rawValue]=character
        var json=try JSONSerialization.jsonObject(with:old.encoded()!) as! [String:Any]
        var words=json["words"] as! [String:[String:Any]]
        words["characters"]!["phase"]="complete";json["words"]=words;json.removeValue(forKey:"study")
        let migrated=CollectionProgress.restore(try JSONSerialization.data(withJSONObject:json))!
        precondition(migrated.words["characters"]!.phase == .correct)
        precondition(RewardCatalog.completed(in:migrated).filter{$0.id.hasPrefix("characters:")}.count == 20)
        // Old 20-range selection and removed questions migrate without changing points/art.
        var retired=CollectionProgress()
        retired.study.selected["numberLine"]="arithmetic-20-cross"
        retired.study.reviewing.insert("numberLine");retired.study.finished.insert("numberLine")
        retired.numberLine = .init(questions:[.init(start:8,change:7)],limit:20)
        retired.rewards.award(RewardCatalog.arithmetic(.init(start:8,change:7)).id)
        retired.printing.stamp(x:0.3,y:0.4)
        let clean=CollectionProgress.restore(retired.encoded()!)!
        precondition(clean.study.selected["numberLine"] == nil && !clean.study.reviewing.contains("numberLine") && !clean.study.finished.contains("numberLine"))
        precondition(clean.rewards == retired.rewards && clean.printing == retired.printing && clean.numberLine!.limit == 5)
        retired.study.selected["numberLine"]="arithmetic-10-add"
        retired.study.reviewing=[];retired.study.finished=[]
        retired.numberLine = .init(questions:[.init(start:1,change:1)])
        let trimmed=CollectionProgress.restore(retired.encoded()!)!
        precondition(trimmed.study.selected["numberLine"] == "arithmetic-10-add" && trimmed.numberLine!.questions.allSatisfy {add.arithmetic.contains($0)})
        precondition(trimmed.rewards == retired.rewards)
        var invalid=migrated;invalid.study.selected["pinyin"]="not-a-group"
        precondition(CollectionProgress.restore(invalid.encoded()!) == nil)
        print("PASS: \(StudyCatalog.all.count) nonempty skill groups, \(playable.count) unique playable challenges, arithmetic bounds, match prerequisites, unique solvable sorting boards, cross-group deduplication and legacy completion migration.")
    }
}
