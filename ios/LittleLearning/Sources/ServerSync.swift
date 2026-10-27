import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

extension CollectionStore {
    func latestFamily() throws -> FamilyProgress {
        guard loadError == nil,var f=family else {throw NASSyncFailure.invalid}
        if let child=activeChild {f.children[child.rawValue]=progress};return f
    }
    func scheduleServerSync() {
        guard serverConfigured else {return}
        serverDebounce?.cancel();serverDebounce=Task { [weak self] in
            do {try await Task.sleep(nanoseconds:500_000_000)}catch{return}
            guard !Task.isCancelled else{return};_ = await self?.syncNow()
        }
    }
    @discardableResult func syncNow() async -> Bool {
        if let task=serverTask {return await task.value}
        let task=Task { [weak self] in await self?.performServerSync() ?? false };serverTask=task
        let result=await task.value;serverTask=nil;return result
    }
    private func performServerSync() async -> Bool {
        guard serverConfigured,loadError == nil else {syncStatus="离线可用 · 同步尚未配置";return false}
        var diagnosticError: String?
        syncBusy=true;defer{
            syncBusy=false
            if let f=try? latestFamily() {
                var diagnostic:[String:Any] = ["status":syncStatus,"date":Date().timeIntervalSince1970,"balances":f.children.mapValues{$0.rewards.balance},"pending":f.syncPending != nil]
                if let reason=diagnosticError {diagnostic["error"]=reason}
                if let data=try? JSONSerialization.data(withJSONObject:diagnostic,options:.sortedKeys){try? data.write(to:fileURLForSyncStatus(),options:.atomic)}
            }
        }
        do {
            let f=try latestFamily();try writeFamily(f);family=f
            let request=ServerSyncRequest(device:f.syncDeviceID.uuidString,children:f.children.mapValues{ $0.rewards.entries },operation:f.syncPending)
            let response=try await serverExchange(request)
            // Preserve current progress, including awards earned or children switched during the request.
            settleFunTime(force:true)
            var updated=try latestFamily()
            for child in FamilyChild.allCases {
                var state=updated.children[child.rawValue]!
                let oldTime=state.funTime.remaining(in:state.rewards)
                state.rewards=try RewardLedger.fromServer(response.children[child.rawValue]!,local:state.rewards)
                var grant=0
                if response.error == nil,let op=f.syncPending,op.kind == "playTime",op.child == child.rawValue,
                   state.rewards.entries.contains(where:{$0.id == op.id && $0.kind == .playTime}),
                   !updated.syncPlayGrants.contains(op.id.uuidString) {
                    updated.syncPlayGrants.insert(op.id.uuidString);grant=FunTimeBank.purchaseMilliseconds
                }
                let excess=state.funTime.remaining(in:state.rewards)-oldTime-grant
                if excess > 0 {state.funTime.consume(excess,in:state.rewards)}
                guard state.funTime.isValid(in:state.rewards) else {throw NASSyncFailure.invalid}
                updated.children[child.rawValue]=state
            }
            // A definitive rejection clears the durable operation; network failures never do.
            updated.syncPending=nil
            try writeFamily(updated);saveTask?.cancel();saveTask=nil;family=updated
            if let child=activeChild {reconciling=true;progress=updated.children[child.rawValue]!;reconciling=false}
            syncStatus=response.error == nil ? "已同步" : "同步完成 · 兑换未成功"
            if let error=response.error {rewardMessage=error}
            return response.error == nil
        } catch NASSyncFailure.server(let text) {syncStatus="离线可用 · 同步待处理";rewardMessage=text;return false}
        catch PointsSyncError.conflict {syncStatus="离线可用 · 历史记录待核对";rewardMessage="本机历史记录尚未全部导入，已保留，请让家长检查。";return false}
        catch {diagnosticError=String(describing:error);syncStatus="离线可用 · 本机记录已保存";return false}
    }
    private func fileURLForSyncStatus() -> URL {
        file.deletingLastPathComponent().appendingPathComponent("nas-sync-status.json")
    }
    @discardableResult func serverAction(kind: String,title: String="",points: Int=0,reference: String="") async -> Bool {
        guard let child=activeChild,loadError == nil,!serverActionBusy else {return false}
        serverActionBusy=true;defer{serverActionBusy=false}
        if let task=serverTask {_ = await task.value}
        do {
            var f=try latestFamily()
            guard f.syncPending == nil else {rewardMessage="上次兑换正在确认，联网后会自动恢复。";_ = await syncNow();return false}
            let operation=ServerOperation(child:child.rawValue,kind:kind,title:title,points:points,reference:reference)
            f.syncPending=operation;try writeFamily(f);family=f
            let ok=await syncNow()
            if ok {rewardMessage=kind == "refund" ? "兑换已撤销，积分已退回。":kind == "playTime" ? "已兑换5分钟。":"兑换已记录。"}
            else if family?.syncPending != nil {rewardMessage="暂时无法连接NAS，本次请求已保存；联网后确认，不会重复扣分。"}
            return ok
        }catch{saveError="请求暂时无法保存，没有发送兑换。";return false}
    }
    func redeemOnServer(title: String,points: Int) async -> Bool {
        guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,points>0 else{return false}
        return await serverAction(kind:"redemption",title:title.trimmingCharacters(in:.whitespacesAndNewlines),points:points)
    }
    func refundOnServer(_ id: UUID) async { _ = await serverAction(kind:"refund",reference:id.uuidString) }
    func buyFunTimeOnServer() async -> Bool {
        guard !funPlaying,funMilliseconds == 0 else{return false}
        return await serverAction(kind:"playTime",title:"趣味游戏 · 5分钟",points:5)
    }
}
