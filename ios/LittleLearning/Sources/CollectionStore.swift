import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

@MainActor
final class CollectionStore: ObservableObject {
    @Published var progress: CollectionProgress { didSet { reconcileRewards() } }
    @Published private(set) var recentAwardID: String?
    @Published var rewardMessage: String?
    private var reconciling = false
    @Published var saveError: String?
    @Published private(set) var loadError: String?
    var clockDragging = false
    let funNow: ()->Double
    @Published var funPlaying = false
    @Published var activeFunGame: FunGame?
    @Published var antBusy = false
    @Published var antWave: [AntMove] = []
    @Published var antAnimationProgress = 0.0
    var funMeter = FunTimeMeter()
    var funTask: Task<Void,Never>?
    var antTask: Task<Void,Never>?
    private let file: URL
    private var saveTask: Task<Void,Never>?

    init(fileURL: URL? = nil,defaults: UserDefaults = .standard,uptime: @escaping ()->Double = { ProcessInfo.processInfo.systemUptime }) {
        funNow=uptime
        let base = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!
        file = fileURL ?? base.appendingPathComponent("LittleLearning",isDirectory:true).appendingPathComponent("collection-v1.json")
        let data=try? Data(contentsOf:file)
        let restored=data.flatMap(CollectionProgress.restore)
        if FileManager.default.fileExists(atPath:file.path), restored == nil {
            progress = .init()
            loadError="本机学习记录暂时无法读取。原文件已保留，请先让家人帮忙检查。"
            return
        }
        var state=restored ?? .init()
        if state.numberLine == nil {
            state.numberLine=defaults.data(forKey:"numberLine.v1").flatMap(NumberLineGame.restore) ?? .fresh()
        }
        for challenge in RewardCatalog.completed(in:state) { state.rewards.award(challenge.id) }
        progress=state
        save()
    }
    func clearRewardNotice() { recentAwardID=nil; rewardMessage=nil }
    @Published var deliveryFrame: RouteFrame?
    @Published var deliveryPlaying = false
    @Published var deliveryStep = 0
    private var deliveryTask: Task<Void,Never>?
    func stopDelivery() {
        deliveryTask?.cancel();deliveryTask=nil;deliveryPlaying=false;deliveryFrame=nil;deliveryStep=0
    }
    func runDelivery() {
        guard !deliveryPlaying,progress.delivery.phase == .playing,!progress.delivery.commands.isEmpty else { return }
        let snapshot=progress.delivery,trace=snapshot.task.trace(snapshot.commands)
        deliveryPlaying=true;deliveryStep=0;deliveryFrame=trace.frames.first
        deliveryTask=Task { [weak self] in
            for (i,frame) in trace.frames.dropFirst().enumerated() {
                do { try await Task.sleep(nanoseconds:350_000_000) } catch { return }
                guard let self,!Task.isCancelled else { return }
                self.deliveryFrame=frame;self.deliveryStep=i+1
            }
            guard let self,!Task.isCancelled,self.progress.delivery == snapshot else { self?.deliveryPlaying=false;return }
            self.progress.delivery.check();self.deliveryPlaying=false;self.deliveryTask=nil
        }
    }
    private func reconcileRewards() {
        guard !reconciling, loadError == nil else { return }
        var updated=progress
        var latest: String?
        let awarded=updated.rewards.awardedIDs
        for challenge in RewardCatalog.completed(in:updated) where !awarded.contains(challenge.id) {
            if updated.rewards.award(challenge.id) { latest=challenge.id }
        }
        if let latest {
            reconciling=true; progress=updated; reconciling=false
            recentAwardID=latest
            // The completed game state and its one-time award are one atomic file write.
            save()
        } else { scheduleSave() }
    }
    func redeem(title: String,points: Int,requestID: UUID) -> Bool {
        var updated=progress
        guard updated.rewards.redeem(title:title,points:points,requestID:requestID) else {
            rewardMessage="请填写兑换内容和有效积分，不能超过余额。"; return false
        }
        do {
            try persist(updated)
            progress=updated; rewardMessage="已记录，扣除 \(points) 积分。"; return true
        } catch { saveError="兑换暂时无法保存，没有扣除积分。"; return false }
    }
    func refund(_ id: UUID) {
        var updated=progress
        guard updated.rewards.refund(id) else { return }
        do { try persist(updated); progress=updated; rewardMessage="记录已撤销，积分已退回。" }
        catch { saveError="撤销暂时无法保存，请再试一次。" }
    }
    func commitFunState(_ state: CollectionProgress) throws {
        try persist(state)
        reconciling=true;progress=state;reconciling=false
        saveTask?.cancel();saveTask=nil
    }
    func persist(_ state: CollectionProgress) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        let data=try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:file,options:.atomic)
        if saveError != nil { saveError=nil }
    }
    func save() {
        saveTask?.cancel(); saveTask = nil
        do { try persist(progress) }
        catch { if saveError == nil { saveError = "这次进度暂时无法保存，请先保留 App 开启。" } }
    }
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds:250_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
    func session(_ game: LearningGame) -> WorkshopSession { progress.words[game.rawValue] ?? .init() }
    func editWorkshop(_ game: LearningGame, _ action: (inout WorkshopSession) -> Void) {
        var session = session(game); action(&session); progress.words[game.rawValue] = session
    }
    func restart(_ game: LearningGame) {
        if let group=group(game) { selectGroup(group,review:group.remaining(in:progress.rewards) == 0);return }
        clearRewardNotice()
        switch game {
        case .sharing: progress.sharing = .init()
        case .clock: progress.clock = .init()
        case .matches: progress.matches = .init()
        case .sorting: progress.fruits = .init()
        case .printing: progress.printing.newPaper()
        default: if game.isWorkshop { progress.words[game.rawValue] = .init() }
        }
    }
    func resumeLabel(_ game: LearningGame) -> String? {
        switch game {
        case .sharing: let s=progress.sharing; return s.phase == .complete ? nil : (s.index > 0 || s.remaining != s.task.total ? "接着分 · 第 \(s.index+1) 题" : nil)
        case .clock: let s=progress.clock; return s.phase == .complete || (s.index == 0 && s.minutes == 0) ? nil : "接着玩 · 第 \(s.index+1) 题"
        case .matches: let s=progress.matches; return s.phase == .complete || (s.index == 0 && s.mask == s.puzzle.initial) ? nil : "接着玩 · 第 \(s.index+1) 题"
        case .sorting: return progress.fruits.level > 0 || !progress.fruits.history.isEmpty ? "接着分 · 第 \(progress.fruits.level+1) 关" : nil
        case .printing: return progress.printing.stamps.isEmpty ? nil : "接着画"
        default:
            guard game.isWorkshop else { return nil }; let s=session(game)
            return s.phase == .complete || (s.index == 0 && s.chosen.isEmpty) ? nil : "接着玩 · 第 \(s.index+1) 题"
        }
    }
}
