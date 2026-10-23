import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

extension CollectionStore {
    func group(_ game: LearningGame) -> StudyGroup? {
        progress.study.selected[game.rawValue].flatMap { StudyCatalog.group($0,for:game) }
    }
    func isGroupFinished(_ game: LearningGame) -> Bool { progress.study.finished.contains(game.rawValue) }
    func isReviewing(_ game: LearningGame) -> Bool { progress.study.reviewing.contains(game.rawValue) }
    func remaining(_ game: LearningGame) -> Int { group(game)?.remaining(in:progress.rewards) ?? 0 }
    func currentIndex(_ game: LearningGame) -> Int {
        switch game {
        case .sharing: return progress.sharing.index
        case .clock: return progress.clock.index
        case .matches: return progress.matches.index
        case .sorting: return progress.fruits.level
        case .tangram:return progress.tangram.index
        case .delivery:return progress.delivery.index
        case .beads:return progress.beads.index
        case .ruler:return progress.ruler.index
        default: return session(game).index
        }
    }
    func positionLabel(_ game: LearningGame) -> String {
        guard let group=group(game) else { return "" }
        let position=(group.indices.firstIndex(of:currentIndex(game)) ?? 0)+1
        return "\(group.title) · \(position) / \(group.count)\(isReviewing(game) ? " · 复习" : "")"
    }
    private func put(_ game: LearningGame,at index: Int,in state: inout CollectionProgress) {
        switch game {
        case .sharing: state.sharing = .init(startAt:index)
        case .clock: state.clock = .init(startAt:index)
        case .matches: state.matches = .init(startAt:index)
        case .sorting: state.fruits = .init(level:index)
        case .tangram:state.tangram = .init(startAt:index)
        case .delivery:state.delivery = .init(startAt:index)
        case .beads:state.beads = .init(startAt:index)
        case .ruler:state.ruler = .init(startAt:index)
        default: state.words[game.rawValue] = .init(startAt:index)
        }
    }
    func selectGroup(_ group: StudyGroup,review: Bool = false) {
        stopDelivery()
        clearRewardNotice()
        var updated=progress
        updated.study.selected[group.game.rawValue]=group.id
        updated.study.finished.remove(group.game.rawValue)
        if review { updated.study.reviewing.insert(group.game.rawValue) }
        else { updated.study.reviewing.remove(group.game.rawValue) }
        let earned=updated.rewards.awardedIDs
        if group.game == .numberLine {
            let bank=group.arithmetic.filter { review == earned.contains(RewardCatalog.arithmetic($0).id) }
            if bank.isEmpty { updated.study.finished.insert(group.game.rawValue) }
            else { updated.numberLine = .init(questions:Array(bank.shuffled().prefix(8)),limit:group.limit) }
        } else {
            let indices=group.indices.filter { review == earned.contains(group.challenge(at:$0).id) }
            if let first=indices.first { put(group.game,at:first,in:&updated) }
            else { updated.study.finished.insert(group.game.rawValue) }
        }
        progress=updated;save()
    }
    func prepareGroup(_ game: LearningGame) {
        guard let group=group(game) else { return }
        if isGroupFinished(game) {
            if !isReviewing(game) && remaining(game) > 0 { selectGroup(group) }
            return
        }
        if game == .numberLine {
            if let math=progress.numberLine, math.limit == group.limit, math.questions.allSatisfy({ group.arithmetic.contains($0) }) { return }
        } else if group.indices.contains(currentIndex(game)) { return }
        selectGroup(group,review:isReviewing(game))
    }
    func advance(_ game: LearningGame) {
        guard let group=group(game), !isGroupFinished(game) else { return }
        let solved: Bool
        switch game {
        case .sharing: solved=progress.sharing.phase == .correct
        case .clock: solved=progress.clock.phase == .correct
        case .matches: solved=progress.matches.phase == .correct
        case .sorting: solved=progress.fruits.isSolved
        case .tangram:solved=progress.tangram.phase == .correct
        case .delivery:solved=progress.delivery.phase == .correct
        case .beads:solved=progress.beads.phase == .correct
        case .ruler:solved=progress.ruler.phase == .correct
        default: solved=session(game).phase == .correct
        }
        guard solved else { return }
        clearRewardNotice()
        let oldIndex=currentIndex(game)
        let earned=progress.rewards.awardedIDs
        let next: Int? = isReviewing(game) ? group.indices.first(where:{$0 > oldIndex && earned.contains(group.challenge(at:$0).id)}) : group.indices.first(where:{ !earned.contains(group.challenge(at:$0).id) })
        var updated=progress
        if let next { put(game,at:next,in:&updated) }
        else { updated.study.finished.insert(game.rawValue) }
        progress=updated;save()
    }
    func finishMathIfNeeded() {
        if remaining(.numberLine) == 0 && !isReviewing(.numberLine) {
            progress.study.finished.insert(LearningGame.numberLine.rawValue);save()
        }
    }
}
