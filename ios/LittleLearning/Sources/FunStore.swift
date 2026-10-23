import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

extension CollectionStore {
    var funMilliseconds: Int { progress.funTime.remaining(in:progress.rewards) }
    var funTimeLabel: String {
        let seconds=(funMilliseconds+999)/1000
        return String(format:"%d:%02d",seconds/60,seconds%60)
    }
    func funLevel(_ game: FunGame) -> Int { game == .arrows ? progress.funArrows.level : progress.funAnts.level }
    func funSolved(_ game: FunGame) -> Bool { game.isWebGame ? false : game == .arrows ? progress.funArrows.isSolved : progress.funAnts.isSolved && !antBusy }
    @discardableResult func buyFunTime(requestID: UUID) -> Bool {
        guard !funPlaying,funMilliseconds == 0 else { return false }
        var updated=progress
        guard updated.rewards.buyPlayTime(requestID:requestID) else { rewardMessage="积分不足，需要5积分。";return false }
        do { try commitFunState(updated);rewardMessage=nil;return true }
        catch { saveError="兑换暂时无法保存，没有扣除积分。";return false }
    }
    func resumeFun(_ game: FunGame) {
        guard !funPlaying,funMilliseconds > 0,!funSolved(game),loadError == nil,saveError == nil else { return }
        activeFunGame=game;funMeter.start(at:funNow());funPlaying=true
        funTask=Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds:200_000_000) } catch { return }
                guard let self,self.funPlaying else { return }
                self.settleFunTime(force:false)
            }
        }
    }
    func pauseFun() {
        settleFunTime(force:true);stopFunRuntime()
    }
    /// Persists at most once a second during play, and the exact partial second when leaving.
    func settleFunTime(force: Bool) {
        guard funPlaying else { return }
        let now=funNow(),elapsed=funMeter.elapsed(at:now)
        guard elapsed > 0,(force || elapsed >= 1000 || elapsed >= funMilliseconds) else { return }
        var updated=progress
        updated.funTime.consume(elapsed,in:updated.rewards)
        do {
            try commitFunState(updated);_ = funMeter.take(at:now)
            if funMilliseconds == 0 { stopFunRuntime() }
        } catch {
            saveError="游戏时间暂时无法保存，已暂停，请保留App开启。";stopFunRuntime()
        }
    }
    private func stopFunRuntime() {
        funTask?.cancel();funTask=nil;funMeter.stop();funPlaying=false;activeFunGame=nil
        antTask?.cancel();antTask=nil;antWave=[];antBusy=false;antAnimationProgress=0
    }
    private func canPlay(_ game: FunGame) -> Bool {
        settleFunTime(force:true)
        return funPlaying && activeFunGame == game && funMilliseconds > 0
    }
    func escapeArrow(_ id: Int) {
        guard canPlay(.arrows) else { return }
        progress.funArrows.tap(id);save()
        if progress.funArrows.isSolved { pauseFun() }
    }
    func dispatchAnt(_ lane: Int) {
        guard canPlay(.ants),!antBusy else { return }
        let moves=progress.funAnts.dispatch(lane);save()
        guard !moves.isEmpty else { return }
        antWave=moves;antAnimationProgress=0;antBusy=true
        let started=funNow(),duration=0.9+Double(moves.count)*0.08
        antTask=Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds:33_000_000) } catch { return }
                guard let self,self.funPlaying else { return }
                self.antAnimationProgress=min(1,max(0,(self.funNow()-started)/duration))
                if self.antAnimationProgress >= 1 {
                    self.antWave=[];self.antBusy=false;self.antTask=nil
                    if self.progress.funAnts.isSolved { self.pauseFun() }
                    return
                }
            }
        }
    }
    func undoAnt() { guard canPlay(.ants),!antBusy else { return };progress.funAnts.undo();save() }
    func resetFun(_ game: FunGame) {
        guard canPlay(game),!antBusy else { return }
        if game == .arrows { progress.funArrows.reset() } else { progress.funAnts.reset() };save()
    }
    func nextFun(_ game: FunGame) {
        guard funSolved(game) else { return }
        pauseFun()
        if game == .arrows { progress.funArrows.next() } else { progress.funAnts.next() }
        save();resumeFun(game)
    }
}
