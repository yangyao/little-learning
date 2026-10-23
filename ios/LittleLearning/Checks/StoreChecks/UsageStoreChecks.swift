import Foundation

enum UsageStoreChecks {
    @MainActor static func run(root: URL) throws {
        let budget=UsageAllowance.budgetMilliseconds
        var date=Date(timeIntervalSince1970:1_700_000_000),clock=1000.0
        func advance(_ seconds: Double) { date=date.addingTimeInterval(seconds);clock += seconds }
        let file=root.appendingPathComponent("usage.json")
        let store=UsageStore(fileURL:file,date:{date},uptime:{clock})
        precondition(store.remaining(.qianyi) == budget && store.remaining(.zhenyi) == budget)
        store.updateContext(child:nil,active:true)
        advance(600);store.tick();precondition(store.remaining(.qianyi) == budget) // Picker is free.
        store.updateContext(child:.qianyi,active:true)
        advance(599.25);store.tick()
        store.updateContext(child:.qianyi,active:true) // Repeated view updates do not reset the clock.
        advance(0.75);store.updateContext(child:.qianyi,active:false)
        precondition(store.remaining(.qianyi) == budget-600_000)
        advance(10_800);store.tick() // Background hours do not replenish a partial allowance.
        precondition(store.remaining(.qianyi) == budget-600_000)
        let restarted=UsageStore(fileURL:file,date:{date},uptime:{clock})
        precondition(restarted.remaining(.qianyi) == budget-600_000)
        restarted.updateContext(child:.qianyi,active:true)
        advance(1200);restarted.tick()
        precondition(restarted.isBlocked && restarted.remaining(.qianyi) == 0 && restarted.restLabel(.qianyi) == "2:00:00")
        let exhausted=try Data(contentsOf:file)
        // Rest survives closing, switching, relaunch, and the passage of midnight.
        restarted.updateContext(child:nil,active:true)
        advance(60);restarted.tick()
        restarted.updateContext(child:.qianyi,active:true)
        precondition(restarted.isBlocked && restarted.restLabel(.qianyi) == "1:59:00")
        restarted.updateContext(child:.zhenyi,active:true)
        advance(120);restarted.tick()
        precondition(!restarted.isBlocked && restarted.remaining(.zhenyi) == budget-120_000)
        restarted.updateContext(child:.zhenyi,active:false)
        advance(7019)
        let resting=UsageStore(fileURL:file,date:{date},uptime:{clock})
        resting.updateContext(child:.qianyi,active:true)
        precondition(resting.isBlocked && resting.restLabel(.qianyi) == "0:00:01")
        advance(1);resting.tick()
        precondition(!resting.isBlocked && resting.remaining(.qianyi) == budget)
        precondition(resting.remaining(.zhenyi) == budget-120_000)
        advance(1.25);resting.updateContext(child:nil,active:true)
        precondition(resting.remaining(.qianyi) == budget-1250)
        let durable=UsageStore(fileURL:file,date:{date},uptime:{clock})
        precondition(durable.remaining(.qianyi) == budget-1250)
        // A blocked UI delays a tick: start rest at exhaustion, not at the late callback.
        var allowance=UsageAllowance();allowance.consume(budget+5000,endingAt:date)
        precondition(allowance.restingSeconds(at:date) == 7195 && allowance.isValid)
        allowance.refresh(at:date.addingTimeInterval(7195));precondition(allowance.remaining(at:date) == budget)
        // Wall-clock movements never award foreground usage time; consumption uses uptime.
        resting.updateContext(child:.zhenyi,active:true)
        date=date.addingTimeInterval(100_000);clock += 2;resting.tick()
        precondition(resting.remaining(.zhenyi) == budget-122_000)
        resting.updateContext(child:nil,active:false)
        // Corrupt files are kept, with no playable allowance granted.
        let badFile=root.appendingPathComponent("usage-bad.json"),bad=Data("broken".utf8)
        try bad.write(to:badFile)
        let invalid=UsageStore(fileURL:badFile,date:{date},uptime:{clock})
        invalid.updateContext(child:.qianyi,active:true);precondition(invalid.isBlocked && invalid.storageError != nil)
        let bytes=try Data(contentsOf:badFile);precondition(bytes == bad)
        var damaged=try JSONSerialization.jsonObject(with:exhausted) as! [String:Any]
        var children=damaged["children"] as! [String:[String:Any]]
        children["qianyi"]!["usedMilliseconds"] = -1;damaged["children"]=children
        let damagedData=try JSONSerialization.data(withJSONObject:damaged);precondition(FamilyUsage.restore(damagedData) == nil)
        // A write failure blocks use and leaves the original file intact.
        let backup=root.appendingPathComponent("usage-backup.json")
        try FileManager.default.moveItem(at:file,to:backup)
        try FileManager.default.createDirectory(at:file,withIntermediateDirectories:true)
        durable.updateContext(child:.qianyi,active:true)
        precondition(durable.isBlocked && durable.storageError != nil)
        try FileManager.default.removeItem(at:file);try FileManager.default.moveItem(at:backup,to:file)
        print("PASS: 30-minute per-child total use, exact pause/resume, restart persistence, free picker, two-hour cooldown and automatic reset, independent sibling cycles, delayed ticks, monotonic charging, corrupt-file preservation and failed-save blocking.")
    }
}
