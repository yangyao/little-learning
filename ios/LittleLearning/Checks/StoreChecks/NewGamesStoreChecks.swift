import Foundation

enum NewGamesStoreChecks {
    @MainActor static func run(root: URL,defaults: UserDefaults) async throws {
        let file=root.appendingPathComponent("new-games.json"),store=CollectionStore(fileURL:root.appendingPathComponent("new-games.json"),defaults:defaults)
        for game in [LearningGame.tangram,.delivery,.beads] {
            store.selectGroup(StudyCatalog.groups(for:game)[0])
        }
        let baseline=store.progress.rewards.balance
        let t=store.progress.tangram.task
        for i in 0..<7 { store.progress.tangram.select(i);store.progress.tangram.place(x:t.solution[i].x,y:t.solution[i].y) }
        store.progress.tangram.check();precondition(store.progress.rewards.balance == baseline+3)
        store.selectGroup(StudyCatalog.groups(for:.tangram)[0],review:true)
        for i in 0..<7 { store.progress.tangram.select(i);store.progress.tangram.place(x:t.solution[i].x,y:t.solution[i].y) }
        store.progress.tangram.check();precondition(store.progress.rewards.balance == baseline+3)
        store.advance(.tangram);precondition(store.isGroupFinished(.tangram))
        store.selectGroup(StudyCatalog.groups(for:.tangram)[2]);precondition(store.progress.tangram.index == 16 && store.progress.rewards.balance == baseline+3)
        // Short failed route and cancellation cannot earn an award.
        store.progress.delivery.append(.left);store.runDelivery();precondition(store.deliveryPlaying)
        store.stopDelivery();try await Task.sleep(nanoseconds:400_000_000)
        precondition(!store.deliveryPlaying && store.progress.delivery.phase == .playing && store.progress.rewards.balance == baseline+3)
        store.progress.delivery.reset()
        for c in store.progress.delivery.task.solution { store.progress.delivery.append(c) }
        store.runDelivery();store.runDelivery() // Repeated Run is ignored while playing.
        for _ in 0..<600 { if !store.deliveryPlaying { break };try await Task.sleep(nanoseconds:50_000_000) }
        precondition(store.progress.delivery.phase == .correct && store.progress.rewards.balance == baseline+6)
        store.stopDelivery();store.advance(.delivery);precondition(store.progress.delivery.index == 1 && store.progress.delivery.commands.isEmpty)
        let task=store.progress.beads.task
        store.progress.beads.choose(task.options.firstIndex(of:task.sequence[task.blanks[0]])!);store.progress.beads.check()
        precondition(store.progress.rewards.balance == baseline+7)
        store.save()
        let reopened=CollectionStore(fileURL:file,defaults:defaults)
        precondition(reopened.progress.rewards == store.progress.rewards && reopened.progress.tangram == store.progress.tangram && reopened.progress.delivery == store.progress.delivery && reopened.progress.beads == store.progress.beads)
        reopened.progress.beads.check();precondition(reopened.progress.rewards.balance == baseline+7)
        print("PASS: new-game atomic one-time awards, group jumps/review, animation cancellation/double-run protection, and restart persistence.")
    }
}
