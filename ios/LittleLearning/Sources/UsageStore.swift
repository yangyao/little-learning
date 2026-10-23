import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

@MainActor final class UsageStore: ObservableObject {
    @Published private(set) var book: FamilyUsage
    @Published private(set) var now: Date
    @Published private(set) var child: FamilyChild?
    @Published private(set) var storageError: String?
    private let file: URL
    private let date: ()->Date
    private let uptime: ()->Double
    private var mark: Double?
    private var foreground=false
    private var loadFailed=false
    private var task: Task<Void,Never>?
    init(fileURL: URL? = nil,date: @escaping ()->Date = Date.init,uptime: @escaping ()->Double = { ProcessInfo.processInfo.systemUptime }) {
        self.date=date;self.uptime=uptime;now=date()
        let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!
        file=fileURL ?? base.appendingPathComponent("LittleLearning/usage-v1.json")
        if FileManager.default.fileExists(atPath:file.path) {
            if let data=try? Data(contentsOf:file),let saved=FamilyUsage.restore(data) { book=saved }
            else { book = .init();loadFailed=true;storageError="使用时间记录暂时无法读取，已暂停使用。原记录已保留。" }
        } else { book = .init() }
    }
    var isBlocked: Bool { child != nil && (storageError != nil || remaining(child!) == 0) }
    func remaining(_ child: FamilyChild) -> Int { book.children[child.rawValue]!.remaining(at:now) }
    func restLabel(_ child: FamilyChild) -> String {
        let seconds=book.children[child.rawValue]!.restingSeconds(at:now)
        return String(format:"%d:%02d:%02d",seconds/3600,seconds/60%60,seconds%60)
    }
    func remainingLabel(_ child: FamilyChild) -> String {
        let seconds=(remaining(child)+999)/1000
        return String(format:"%d:%02d",seconds/60,seconds%60)
    }
    var showsWarning: Bool { child.map { remaining($0) > 0 && remaining($0) <= 60_000 } ?? false }
    /// Called for selection, foreground changes, and leaving for the child picker.
    func updateContext(child next: FamilyChild?,active: Bool) {
        if child == next,foreground == active { return }
        tick(force:true)
        mark=nil;child=next;foreground=active
        now=date();refresh()
        if active,next != nil,!isBlocked {
            // Check that the file can be written before enabling any game controls.
            if persist() { mark=uptime() }
        }
        task?.cancel();task=nil
        if active {
            task=Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds:250_000_000) } catch { return }
                    self?.tick()
                }
            }
        }
    }
    func tick(force: Bool = false) {
        now=date()
        if let child,let start=mark,foreground,!isBlocked {
            let current=uptime(),elapsed=max(0,min(Double(Int.max/2),(current-start)*1000))
            if force || elapsed >= 1000 {
                let milliseconds=Int(elapsed.rounded(.down))
                if milliseconds > 0 {
                    book.children[child.rawValue]!.consume(milliseconds,endingAt:now)
                    mark=start+Double(milliseconds)/1000
                    if !persist() { mark=nil }
                }
            }
        }
        refresh()
        if isBlocked { mark=nil }
        else if foreground,child != nil,mark == nil,storageError == nil { mark=uptime() }
    }
    private func refresh() {
        var updated=book
        for child in FamilyChild.allCases { updated.children[child.rawValue]!.refresh(at:now) }
        if updated != book { book=updated;_ = persist() }
    }
    @discardableResult private func persist() -> Bool {
        guard !loadFailed else { return false }
        do {
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(book).write(to:file,options:.atomic)
            storageError=nil;return true
        } catch {
            storageError="使用时间暂时无法保存，已暂停使用。请保留 App 和原记录。";return false
        }
    }
}
