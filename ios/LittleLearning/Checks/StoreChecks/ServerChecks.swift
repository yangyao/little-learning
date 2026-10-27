import Foundation

@MainActor enum ServerChecks {
 static func run() async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("nas-tests-\(UUID())")
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  defer{try? FileManager.default.removeItem(at:root)}
  let file=root.appendingPathComponent("collection-v1.json")
  let suite="nas-tests-\(UUID())",defaults=UserDefaults(suiteName:suite)!
  defer{defaults.removePersistentDomain(forName:suite)}
  let store=CollectionStore(fileURL:file,defaults:defaults,profilesEnabled:true)
  precondition(store.selectChild(.qianyi));store.serverConfigured=true
  for c in RewardCatalog.all.prefix(12){store.progress.rewards.award(c.id)};store.save()
  let before=store.progress.rewards.balance
  // No server response: retain balance and durable operation through restart.
  store.serverExchange={_ in throw NASSyncFailure.offline}
  let offline=await store.redeemOnServer(title:"书",points:3)
  precondition(!offline && store.progress.rewards.balance==before)
  let pending=store.family!.syncPending!
  let restored=CollectionStore(fileURL:file,defaults:defaults,profilesEnabled:true)
  precondition(restored.family!.syncPending!.id==pending.id)
  var canonical=store.progress.rewards
  precondition(canonical.redeem(title:"书",points:3,requestID:pending.id))
  store.serverExchange={req in
   precondition(req.operation!.id==pending.id)
   return ServerSyncResponse(children:["qianyi":canonical.entries,"zhenyi":[]],balances:["qianyi":canonical.balance,"zhenyi":0],error:nil,applied:pending.id.uuidString)
  }
  let recovered=await store.syncNow();precondition(recovered && store.family!.syncPending==nil && store.progress.rewards.balance==before-3)
  // The requesting device receives purchased time exactly once, even after repeating sync.
  store.serverExchange={req in
   if let op=req.operation {precondition(op.kind=="playTime");precondition(canonical.buyPlayTime(requestID:op.id))}
   return ServerSyncResponse(children:["qianyi":canonical.entries,"zhenyi":[]],balances:["qianyi":canonical.balance,"zhenyi":0],error:nil,applied:req.operation?.id.uuidString)
  }
  let bought=await store.buyFunTimeOnServer();precondition(bought && store.funMilliseconds==300000)
  store.progress.funTime.consume(12345,in:store.progress.rewards);store.save()
  let left=store.funMilliseconds;let repeated=await store.syncNow();precondition(repeated && store.funMilliseconds==left)
  // A different device adopts the ledger without importing purchased play time.
  let other=CollectionStore(fileURL:root.appendingPathComponent("other.json"),defaults:defaults,profilesEnabled:true)
  precondition(other.selectChild(.qianyi));other.serverConfigured=true
  other.serverExchange=store.serverExchange
  let remote=await other.syncNow();precondition(remote && other.funMilliseconds==0 && other.progress.rewards.balance==canonical.balance)
  // Earnings and game state changed during a request survive canonical adoption.
  let newAward=RewardCatalog.all.first{!canonical.hasAward($0.id)}!
  store.serverExchange={req in
   store.progress.rewards.award(newAward.id)
   return ServerSyncResponse(children:["qianyi":canonical.entries,"zhenyi":[]],balances:["qianyi":canonical.balance,"zhenyi":0],error:nil,applied:nil)
  }
  let concurrent=await store.syncNow();precondition(concurrent && store.progress.rewards.hasAward(newAward.id))
  // Missing historical spending is a conflict; never overwrite local history.
  var empty=RewardLedger();for c in RewardCatalog.all.prefix(12){empty.award(c.id)}
  store.serverExchange={_ in ServerSyncResponse(children:["qianyi":empty.entries,"zhenyi":[]],balances:["qianyi":empty.balance,"zhenyi":0],error:nil,applied:nil)}
  let saved=store.progress.rewards;let conflict=await store.syncNow();precondition(!conflict && store.progress.rewards==saved)
  store.serverDebounce?.cancel();other.serverDebounce?.cancel()
  print("PASS: NAS offline durability, same-ID retry after restart, confirmed spend, exactly-once local play-time grant, remote time isolation, in-flight awards and history conflict protection.")
 }
}
