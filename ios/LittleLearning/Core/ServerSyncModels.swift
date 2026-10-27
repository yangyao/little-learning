import Foundation

public struct ServerOperation: Codable, Sendable {
    public var id: UUID
    public var child: String
    public var kind: String
    public var title: String
    public var points: Int
    public var reference: String
    public init(id: UUID=UUID(),child: String,kind: String,title: String="",points: Int=0,reference: String="") {
        self.id=id;self.child=child;self.kind=kind;self.title=title;self.points=points;self.reference=reference
    }
}
public struct ServerSyncRequest: Codable, Sendable {
    public let device: String
    public let children: [String:[PointsEntry]]
    public let operation: ServerOperation?
    public init(device: String,children: [String:[PointsEntry]],operation: ServerOperation?) { self.device=device;self.children=children;self.operation=operation }
}
public struct ServerSyncResponse: Codable, Sendable {
    public let children: [String:[PointsEntry]]
    public let balances: [String:Int]
    public let error: String?
    public let applied: String?
}
extension RewardLedger {
    /// Adopt canonical server entries, preserving awards earned while the request was in flight.
    public static func fromServer(_ entries: [PointsEntry],local: Self) throws -> Self {
        var ledger=Self();ledger.entriesForServer(entries)
        guard ledger.isValid else { throw PointsSyncError.invalid }
        let knownSpending=Set(entries.filter {$0.kind == .redemption || $0.kind == .playTime}.map(\.id))
        guard local.entries.filter({$0.kind == .redemption || $0.kind == .playTime}).allSatisfy({knownSpending.contains($0.id)}) else {throw PointsSyncError.conflict}
        for e in local.entries where e.kind == .award && !ledger.hasAward(e.reference) { ledger.appendServerAward(e) }
        guard ledger.isValid else {throw PointsSyncError.invalid};return ledger
    }
}
