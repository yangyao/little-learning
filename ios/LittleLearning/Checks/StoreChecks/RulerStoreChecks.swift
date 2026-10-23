import Foundation

enum RulerStoreChecks {
    @MainActor static func solve(_ store: CollectionStore) {
        var s=store.progress.ruler,t=s.task
        switch t.mode {
        case .measure,.offset:s.move(to:2);s.choose(t.length);s.check()
        case .missingNumber:s.choose(t.blank!);s.check()
        case .target:
            let a=t.marks.first { t.marks.contains($0+t.length) }!;s.tap(a);s.tap(a+t.length);s.check()
        case .explore:
            for length in t.distances.sorted() {
                let a=t.marks.first { t.marks.contains($0+length) }!;s.clearPair();s.tap(a);s.tap(a+length);s.check()
            }
        }
        store.progress.ruler=s
    }
    @MainActor static func run(root:URL,defaults:UserDefaults) throws {
        let file=root.appendingPathComponent("ruler.json"),store=CollectionStore(fileURL:root.appendingPathComponent("ruler.json"),defaults:defaults)
        let baseline=store.progress.rewards.balance
        let groups=StudyCatalog.groups(for:.ruler)
        store.selectGroup(groups[2]);precondition(store.progress.ruler.index == 16 && store.progress.rewards.balance == baseline)
        store.advance(.ruler);precondition(store.progress.ruler.index == 16)
        store.progress.ruler.tap(0);store.progress.ruler.tap(4);store.progress.ruler.check();precondition(store.progress.rewards.balance == baseline)
        for group in groups {
            store.selectGroup(group)
            for _ in 0..<8 { solve(store);precondition(store.progress.ruler.phase == .correct);store.advance(.ruler) }
            precondition(store.isGroupFinished(.ruler) && store.remaining(.ruler) == 0)
        }
        precondition(store.progress.rewards.balance == baseline+28)
        let earned=store.progress.rewards
        store.selectGroup(groups[2],review:true);solve(store);store.progress.ruler.check();precondition(store.progress.rewards == earned)
        store.selectGroup(groups[0],review:true);solve(store);store.save()
        let reopened=CollectionStore(fileURL:file,defaults:defaults)
        precondition(reopened.progress.ruler == store.progress.ruler && reopened.progress.rewards == earned)
        reopened.progress.ruler.check();precondition(reopened.progress.rewards == earned)
        print("PASS: ruler group navigation, 24 one-time awards, no skipped/premature rewards, review deduplication and restart durability.")
    }
}
